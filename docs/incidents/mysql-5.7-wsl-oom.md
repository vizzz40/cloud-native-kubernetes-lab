# MySQL 5.7 OOM on kind/WSL2

Incident date: 28 August 2026

This happened in a separate local environment (Windows, WSL2, Docker, a 3-node
`kind` cluster, 16 GB laptop RAM), not on the EC2 cluster in this repository. It
is included as a debugging case study.

## Summary

| | |
| --- | --- |
| Symptom | A `mysql:5.7` Pod ended in `OOMKilled` (exit code 137) shortly after starting. |
| Root cause | `mysqld` grew to about 6.6 GiB resident memory inside a WSL2 VM with about 7.6 GiB total. The kernel's global OOM killer terminated it. No Kubernetes or Docker memory limit was involved. |
| Resolution | Moved to `mysql:8.0`. The WSL memory allocation was deliberately not increased. |

## The workload

A single Pod with no resource requests or limits, an `emptyDir` volume and
environment variables for the MySQL user, database and passwords (placeholders
shown here; a real deployment would read them from a Secret):

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
      - name: MYSQL_PASSWORD
        value: <example-password>
      - name: MYSQL_ROOT_PASSWORD
        value: <example-root-password>
    ports:
      - containerPort: 3306
    volumeMounts:
      - name: mysql-storage
        mountPath: /var/lib/mysql
  volumes:
  - name: mysql-storage
    emptyDir: {}
```

## Investigation

### 1. Start with Kubernetes

```bash
kubectl get pod -o wide
kubectl describe pod mysql-pod
```

```text
mysql-pod   0/1   OOMKilled   2          10.244.2.55   kind-worker

State:          Terminated
Reason:         OOMKilled
Exit Code:      137
QoS Class:      BestEffort
```

The Pod had no memory limit, so "limit exceeded" did not fit. Exit code 137
means the process received `SIGKILL`, but it does not say which layer sent it.
The candidate layers were:

```text
Pod memory limit -> kind node limit -> Docker limit -> WSL memory exhaustion
                 -> something unusual inside MySQL
```

### 2. Check the real host memory

The workload runs inside WSL, so memory was checked there:

```bash
free -h
```

```text
               total        used        free      available
Mem:           7.6Gi       1.6Gi       5.2Gi       6.0Gi
Swap:          2.0Gi       912Mi       1.1Gi
```

About 6 GiB was available, yet a small MySQL instance still ran out of memory.
Raising the WSL allocation was the obvious workaround, but it would have hidden
the interesting question: why does MySQL need this much memory to start?

### 3. Remember that kind nodes share the host

Each kind node reported about `7936188Ki` of memory. That is not three separate
pools of 7.6 GB. kind nodes are Docker containers that share one WSL environment:

```text
Windows -> WSL2 (~7.6 GiB) -> Docker -> kind-control-plane
                                      -> kind-worker
                                      -> kind-worker2
```

### 4. Rule out a Docker limit

```bash
docker inspect kind-worker \
  --format 'Memory={{.HostConfig.Memory}} MemorySwap={{.HostConfig.MemorySwap}}'
docker stats --no-stream kind-worker
```

```text
Memory=0 MemorySwap=0
kind-worker   146.7MiB / 7.569GiB
```

No explicit Docker memory limit, and the worker container was not near any
ceiling.

### 5. Ask the kernel

```bash
sudo dmesg -T | grep -i -E 'oom|killed process|out of memory' | tail -20
```

The decisive lines:

```text
global_oom
task=mysqld
Out of memory: Killed process ... (mysqld)
total-vm:16859336kB
anon-rss:6925824kB
oom_score_adj:1000
```

`global_oom` means the host Linux environment ran out of memory, not a cgroup
limit. `mysqld` held about 6.6 GiB of resident memory:

```text
mysqld starts -> memory grows to ~6.6 GiB -> WSL reaches global memory pressure
              -> Linux OOM killer runs -> mysqld gets SIGKILL
              -> Kubernetes reports OOMKilled
```

### 6. Why this Pod was the victim

`kubectl describe` showed `QoS Class: BestEffort`, and the kernel showed
`oom_score_adj:1000`. A BestEffort Pod has no requests or limits, so under memory
pressure it is among the first workloads to be killed:

```text
Kubernetes QoS class -> cgroup / process settings -> Linux OOM behaviour
                     -> the process is killed
```

### 7. Container logs

`kubectl logs mysql-pod --previous` was unreliable because the container died
repeatedly. One attempt returned only the entrypoint banner for MySQL
`5.7.44-1.el7`, so the process was failing almost immediately during startup. This
matched the abnormal startup memory behaviour of the old `mysql:5.7` image, and
changing the whole machine configuration for it was not worthwhile. The lab simply
moved to `mysql:8.0`.

## Debugging path

```text
mysql-pod OOMKilled
   |
   |-- Kubernetes memory limit?  No (BestEffort, no limit set)
   |-- WSL already out of RAM?   No, about 6 GiB available beforehand
   |-- Docker limiting the node? No (Memory=0)
   `-- Kernel OOM?               Yes: global_oom, mysqld ~6.6 GiB RSS
```

The method: observe, form a hypothesis, collect evidence, reject or refine it,
then move down a layer.

## Lessons

- `OOMKilled` is a symptom, not a diagnosis.
- Exit code 137 means `SIGKILL`; it does not identify who sent it.
- A host-level (global) OOM differs from exceeding a container memory limit.
- kind nodes share the host's resources; a node is an abstraction, not a VM.
- Kubernetes QoS classes connect directly to Linux OOM behaviour.
- `dmesg` answers questions the Kubernetes view cannot.
- A plausible workaround (more memory) can hide the question worth answering.
- AI suggestions are hypotheses. Here several suggested raising WSL memory; the
  numbers did not fit, and the kernel log settled it. The machine is the source
  of truth.

## Commands used

```bash
kubectl get pod -o wide
kubectl describe pod mysql-pod
kubectl logs mysql-pod --previous
free -h
docker inspect kind-worker
docker stats --no-stream kind-worker
sudo dmesg -T | grep -i -E 'oom|killed process|out of memory'
```
