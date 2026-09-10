# MySQL 5.7 OOM on kind/WSL2

Incident date: 28 August 2026

## A small debugging incident that turned into a useful systems lesson

I was working on ConfigMaps and Secrets in my local Kubernetes lab and created a simple MySQL pod.

The setup was:

- Windows
- WSL2
- Docker
- 3-node `kind` cluster
- 16 GB physical RAM
- `mysql:5.7`

The pod was basic:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mysql-pod

spec:
  containers:
  - name: mysql
    image: mysql:5.7

    env:
      - name: MYSQL_USER
        valueFrom:
          configMapKeyRef:
            name: bootcamp-configmap
            key: username

      - name: MYSQL_DATABASE
        valueFrom:
          configMapKeyRef:
            name: bootcamp-configmap
            key: database_name

      - name: MYSQL_PASSWORD
        value: demo123

      - name: MYSQL_ROOT_PASSWORD
        value: demo345

    ports:
      - containerPort: 3306

    volumeMounts:
      - name: mysql-storage
        mountPath: /var/lib/mysql

  volumes:
    - name: mysql-storage
      emptyDir: {}
```

I expected it to start normally.

Instead:

```text
mysql-pod   0/1   OOMKilled
```

That was where the interesting part started.

---

## 1. Start with Kubernetes

First:

```bash
kubectl get pod -o wide
```

showed:

```text
NAME        READY   STATUS      RESTARTS   IP            NODE
mysql-pod   0/1     OOMKilled   2          10.244.2.55   kind-worker
```

Then:

```bash
kubectl describe pod mysql-pod
```

showed:

```text
State:          Terminated
Reason:         OOMKilled
Exit Code:      137
```

and:

```text
QoS Class: BestEffort
```

There were no resource requests or limits on the container.

So the obvious case:

```text
memory limit exceeded
```

didn't fit.

`137` means the process received `SIGKILL`, but that still doesn't tell you **which layer caused the kill**.

At this point the possible causes were roughly:

```text
Pod memory limit
     ↓
kind node limit
     ↓
Docker limit
     ↓
WSL memory exhaustion
     ↓
something strange inside MySQL
```

---

## 2. Check the actual host memory

My laptop has 16 GB RAM, but the workload runs inside WSL, so I checked from there:

```bash
free -h
```

Output:

```text
               total        used        free      available
Mem:           7.6Gi       1.6Gi       5.2Gi       6.0Gi
Swap:          2.0Gi       912Mi       1.1Gi
```

So WSL had around:

```text
7.6 GiB total
6.0 GiB available
```

That was the first thing that felt wrong.

A small MySQL instance should not need six gigabytes just to start.

One possible fix was to increase the WSL memory allocation.

I deliberately didn't do that yet.

The reasoning was simple:

> If ~6 GiB is available and this tiny MySQL pod still OOMs, the interesting question is not "how do I give it more memory?" but "why is it using this much memory at all?"

That turned out to matter.

---

## 3. kind memory can be misleading

Each kind node reported roughly:

```text
memory: 7936188Ki
```

That does **not** mean:

```text
control-plane   7.6 GB
worker          7.6 GB
worker2         7.6 GB
                -------
                22.8 GB
```

kind nodes are Docker containers sharing the same underlying WSL/Linux environment.

Conceptually:

```text
Windows
  │
  ▼
WSL2 (~7.6 GiB)
  │
  ▼
Docker
  │
  ├── kind-control-plane
  ├── kind-worker
  └── kind-worker2
```

They all see the same host memory pool.

This was a useful reminder that a Kubernetes "node" is an abstraction; in kind, it isn't an independent VM.

---

## 4. Check whether Docker is limiting the worker

The pod was scheduled on `kind-worker`, so I checked the Docker container itself:

```bash
docker inspect kind-worker \
  --format 'Memory={{.HostConfig.Memory}} MemorySwap={{.HostConfig.MemorySwap}}'
```

Result:

```text
Memory=0 MemorySwap=0
```

No explicit Docker memory limit.

Then:

```bash
docker stats --no-stream kind-worker
```

showed roughly:

```text
kind-worker   146.7MiB / 7.569GiB
```

So this wasn't a worker container sitting at a tiny memory ceiling either.

Another hypothesis eliminated.

---

## 5. Ask the kernel

The useful command ended up being:

```bash
sudo dmesg -T | grep -i -E 'oom|killed process|out of memory' | tail -20
```

The important lines were:

```text
global_oom
```

and:

```text
task=mysqld
```

and:

```text
Out of memory: Killed process ... (mysqld)
total-vm:16859336kB
anon-rss:6925824kB
oom_score_adj:1000
```

That explained the entire failure.

`mysqld` had reached roughly:

```text
6.6 GiB resident memory
```

inside a WSL environment with roughly:

```text
7.6 GiB total
```

So the actual sequence was:

```text
mysqld starts
     ↓
memory usage grows to ~6.6 GiB
     ↓
WSL reaches global memory pressure
     ↓
Linux OOM killer runs
     ↓
mysqld gets SIGKILL
     ↓
Kubernetes reports OOMKilled
```

The important word was:

```text
global_oom
```

This wasn't a Kubernetes container memory limit.

The host Linux environment itself was running out of memory.

---

## 6. Why this pod got killed

`kubectl describe` had shown:

```text
QoS Class: BestEffort
```

and the kernel showed:

```text
oom_score_adj:1000
```

That connection was useful.

A BestEffort pod has no CPU or memory requests/limits, and under memory pressure it is one of the easiest workloads for the system to sacrifice.

So something that looked abstract while studying Kubernetes:

```text
Guaranteed
Burstable
BestEffort
```

suddenly connected directly to Linux process behaviour.

The stack stopped feeling magical:

```text
Kubernetes QoS
      ↓
cgroups / process settings
      ↓
Linux OOM behaviour
      ↓
actual process gets killed
```

---

## 7. Container logs

I also tried:

```bash
kubectl logs mysql-pod --previous
```

Because the container was dying repeatedly, previous logs were sometimes already unavailable.

One successful attempt returned:

```text
[Entrypoint]: Entrypoint script for MySQL Server 5.7.44-1.el7 started.
```

It was dying almost immediately during startup.

At that point the interesting question had changed from:

> Why is Kubernetes killing MySQL?

to:

> Why is this MySQL 5.7 process consuming almost the entire WSL VM during startup?

The behaviour matched known abnormal memory behaviour around the old `mysql:5.7` container/startup path.

For this lab, the practical solution was simply to move away from the old image:

```yaml
image: mysql:8.0
```

There was no value in changing the whole machine configuration just to accommodate obviously abnormal behaviour from an old image.

---

## Debugging path

The incident ended up looking like this:

```text
mysql-pod
   │
   ▼
OOMKilled
   │
   ├── Kubernetes memory limit?
   │       └── No
   │
   ├── WSL already out of RAM?
   │       └── No, ~6 GiB available
   │
   ├── Increase WSL memory?
   │       └── Didn't fit the workload, so held off
   │
   ├── Docker limiting kind-worker?
   │       └── No
   │
   └── Kernel OOM?
           │
           ▼
       global_oom
           │
           ▼
     mysqld ~6.6 GiB RSS
```

The main lesson wasn't any single command.

It was:

```text
observe
  ↓
form hypothesis
  ↓
collect evidence
  ↓
reject or refine hypothesis
  ↓
move down a layer
```

---

## A small lesson in AI-assisted debugging

I used AI throughout this investigation.

It made the process much faster.

Instead of manually searching every unfamiliar clue, I could feed it:

```text
OOMKilled
exit 137
BestEffort
```

then come back with:

```text
free -h
docker inspect
docker stats
dmesg
```

and keep narrowing the problem.

But one of the useful parts was that I **didn't blindly apply every suggestion**.

Increasing WSL memory was suggested several times.

It was a plausible fix.

I didn't do it because the numbers didn't fit:

```text
~6 GiB available
vs.
one tiny MySQL instance
```

That mismatch seemed more interesting than the OOM itself.

Eventually the kernel logs confirmed that instinct.

The workflow I want to keep is:

```text
AI suggests a hypothesis
        ↓
check the actual system
        ↓
evidence wins
```

I'm still labbing at home rather than working on production systems, but this felt closer to how I imagine useful AI-assisted engineering should work.

AI can accelerate:

- hypothesis generation
- command discovery
- documentation lookup
- interpretation of unfamiliar output

But the machine is still the source of truth.

If the AI says one thing and `dmesg` says another, trust the kernel.

---

## What I kept from this incident

Useful commands:

```bash
kubectl get pod -o wide
kubectl describe pod mysql-pod
kubectl logs mysql-pod --previous

free -h

docker inspect kind-worker
docker stats --no-stream kind-worker

sudo dmesg -T | grep -i -E 'oom|killed process|out of memory'
```

Useful concepts:

- `OOMKilled` is a symptom, not a full diagnosis.
- Exit code `137` means the process received `SIGKILL`.
- A host/global OOM is different from exceeding a container memory limit.
- kind nodes share the underlying host resources.
- Kubernetes QoS eventually connects to Linux-level behaviour.
- `dmesg` is extremely useful when the Kubernetes view isn't enough.
- Avoid changing the system too early when debugging something strange.
- A plausible workaround can hide the question you actually want answered.

---

## Final note

This happened around 4 AM, with a cold room, everyone asleep, a cyberpunk terminal theme and Blade Runner-ish ambient music running in the background.

That probably helped the atmosphere.

But this was also the first problem in a while where I stopped feeling like I was "studying Kubernetes" and just wanted to know why the machine was behaving strangely.

I started by trying to wire a ConfigMap into MySQL.

I ended up looking at the Linux OOM killer.

Not a bad detour.

Sometimes Kubernetes tells you **what happened**.

Sometimes you have to ask Linux **why**.
