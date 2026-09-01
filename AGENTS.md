# AGENTS.md

## Purpose

This repository is a long-running cloud-native and platform-engineering
homelab.

It is intended to demonstrate engineering judgment across:

cloud
→ Linux
→ container runtime
→ Kubernetes
→ networking
→ storage
→ security
→ observability
→ delivery
→ reliability
→ cost
→ platform abstraction

This is not a production environment, an EKS tutorial, a collection of copied
manifests, or a tool showcase.

The objective is to build, operate, observe, secure, break, recover, automate,
and evolve a self-managed Kubernetes platform while understanding the layers
beneath its abstractions.

## Progressive Engineering Education

Use this learning sequence:

1. Understand the underlying layer.
2. Inspect what an abstraction creates or changes.
3. Adopt the abstraction when manual repetition has diminishing educational
   value.
4. Validate the result.
5. Explain important trade-offs, failure modes, and evidence.

Do not make the repository owner manually type repetitive configuration merely
for the sake of typing it.

Codex may scaffold, implement, refactor, document, validate, and automate
repetitive work, but must explain important architectural decisions.

Introduce tools only when there is a current problem that justifies them.

For each meaningful new tool or capability, explain:

1. What problem does it solve?
2. Why is it needed now?
3. What layer does it abstract?
4. What must still be understood underneath?
5. How will it be validated?
6. What does it cost in money, CPU, memory, complexity, and operational burden?
7. Is a simpler approach sufficient?

Avoid collecting technologies without a concrete use case.

## Teaching Style

Work in small, independently understandable milestones.

For each milestone:

1. State the mission.
2. Explain the relevant architecture.
3. Show the proposed change before writing it.
4. Wait for approval when required by the approval rules below.
5. Implement one coherent change.
6. Validate it proportionally to its risk.
7. Explain the evidence, limitations, and next step.
8. When useful, ask a few short why, trade-off, or failure-mode questions.

Use plain technical language. Hinglish explanations are welcome when they make
a concept easier to understand.

Do not hide important reasoning behind commands or generated files.

## Approval Boundaries

Read-only local repository inspection is allowed without additional approval.

Before creating, editing, moving, renaming, or deleting any repository file:

1. Explain the intended change.
2. Show or clearly describe the proposed content.
3. Ask the repository owner for explicit approval.
4. Do not write the change until approval is received.

Approval to edit files is not approval to commit them.

Before every commit:

1. Show `git status`.
2. Summarize the diff and validation results.
3. List the exact files proposed for the commit.
4. Propose the exact commit message.
5. Ask for explicit approval.
6. Commit only after approval.

Approval to commit is not approval to push.

Before every push:

1. State the branch and remote.
2. State which commits will be pushed.
3. Ask for explicit approval.
4. Push only after approval.

Do not amend, rebase, squash, reset, discard user changes, rewrite history,
change remotes, or modify repository metadata without explicit approval.

Never add AI, Codex, co-author, signature, or generated-by attribution to
commits, source files, or documentation unless the repository owner explicitly
requests it.

## Current Architecture

Cloud and compute:

- AWS
- Region: `eu-central-1`
- Self-managed Kubernetes on EC2
- No EKS
- Single Availability Zone for cost
- One control-plane node
- Two worker nodes
- `t3.medium` instances
- Ubuntu Server
- EBS-backed node storage
- Instances are normally stopped when the lab is idle

Container and Kubernetes stack:

- containerd
- runc
- kubeadm
- kubelet
- kubectl
- systemd cgroup driver
- Kubernetes 1.36 family
- Cilium CNI
- kube-proxy retained initially

Network ranges:

- AWS VPC: `10.20.0.0/16`
- EC2 subnet: `10.20.1.0/24`
- Kubernetes Pod CIDR: `10.244.0.0/16`
- Kubernetes Service CIDR: `10.96.0.0/12`

These ranges must remain non-overlapping.

Do not configure Cilium cluster-pool IPAM with `10.0.0.0/8`, because it overlaps
the AWS VPC.

Current intended Cilium design:

- Kubernetes-managed node PodCIDRs
- Cilium Kubernetes IPAM mode
- VXLAN tunnel routing
- veth datapath
- kube-proxy replacement disabled
- one Cilium operator replica
- IPv4 enabled
- IPv6 disabled
- Hubble disabled until its separate observability milestone

The tracked Cilium configuration is:

`kubernetes/platform/cilium/values.yml`

Inspect the tracked values and actual Helm release before proposing a Cilium
change. Do not reinstall or upgrade Cilium casually.

## Repository Structure

Current high-level structure:

- `terraform/bootstrap/`
- `terraform/infrastructure/`
- `kubernetes/platform/cilium/`

Create directories only when introducing the corresponding capability.

Do not scaffold the entire future roadmap prematurely.

Likely future areas may include:

- `kubernetes/labs/`
- `kubernetes/apps/`
- `kubernetes/platform/observability/`
- `ansible/`
- `docs/`
- `helm/`
- `gitops/`

Their appearance must be justified by an active milestone.

## Source of Truth

Git-tracked configuration is the durable source of truth.

Prefer:

repository configuration
→ reviewed change
→ explicit deployment action
→ validation evidence

Do not treat manually created files on EC2 nodes or disposable files under
`/tmp` as the primary source of truth.

Generated manifests should normally be regenerated rather than committed unless
they have a specific review, educational, or documentation purpose.

Do not claim that repository state proves live-cluster state.

## Live-State Rules

The EC2 instances may be stopped to save money.

Before diagnosing SSH or Kubernetes API failure, consider:

- instances may be stopped;
- EC2 public addresses may have changed;
- the administrator's public address may have changed;
- the `/32` security-group rule may therefore be stale.

Do not start, stop, reboot, terminate, resize, or replace cloud resources without
explicit approval.

Do not mutate AWS, Terraform-managed infrastructure, or the Kubernetes cluster
without explaining the exact action, expected effect, risk, rollback path, and
cost impact, then receiving explicit approval.

Read-only live inspection must not be presented as mutation or validation of
anything it did not actually test.

Never represent planned, rendered, statically checked, or previously observed
state as currently verified live state.

## Terraform Safety

Inspect existing Terraform source and state architecture before proposing
changes.

Preserve the separation between:

- `terraform/bootstrap/`
- `terraform/infrastructure/`

Remote state uses S3 and S3-native lockfiles.

Do not casually:

- change backend configuration;
- move or rename Terraform resources;
- change CIDRs;
- recreate EC2 nodes;
- replace key pairs;
- modify state directly;
- import or remove resources from state;
- run `terraform apply`;
- run `terraform destroy`.

Before an approved Terraform change:

1. Format and statically validate where tooling is available.
2. Review the plan.
3. Identify additions, changes, replacements, and deletions.
4. Explain billable resources and cost effects.
5. Ask separately before applying.

Never apply a stale saved plan after assumptions, credentials, variables, public
addresses, provider versions, or repository content have changed.

The Terraform variable for administrator access is currently named
`admin_cidr`. Verify source before copying older documentation that may use a
different name.

## Kubernetes Safety

Be especially careful with:

- `kubectl delete`
- namespace deletion
- CRD deletion
- PVC or storage deletion
- Helm uninstall
- Cilium changes
- Pod CIDR changes
- Service CIDR changes
- CNI mode changes
- kube-proxy removal
- kubeadm reset
- etcd operations
- node drain
- control-plane changes

Before a high-impact Kubernetes action:

1. Explain what will change.
2. Identify affected resources and traffic.
3. Explain failure and rollback paths.
4. Show the exact proposed command.
5. Ask for explicit approval.
6. Validate cluster health afterward if the action is approved.

Do not manually patch Helm-generated Cilium workloads as a permanent solution.
Change tracked Helm values and use a deliberate Helm lifecycle operation.

A backup is not considered proven until a restore has been tested.

## Security and Secrets

Never commit, print into documentation, or expose through command output:

- AWS access keys
- temporary AWS credentials
- kubeconfig contents
- kubeadm tokens
- join commands containing secrets
- private SSH keys
- passwords
- TLS private keys
- unredacted sensitive Terraform state
- secret values
- private registry credentials

Do not open or print likely sensitive local files unless it is necessary and
explicitly authorized.

Use GitHub OIDC and an IAM role for future CI-to-AWS authentication. Do not use
long-lived AWS keys in GitHub Actions when workload identity is available.

Do not weaken SSH or Kubernetes API ingress to `0.0.0.0/0` as a convenience
fix. Preserve the administrator `/32` model unless an intentional architecture
change is approved.

Every security tool must have a defined threat or use case, implementation,
validation method, and resource cost.

## Cost Rules

Cost is a first-class engineering constraint.

The architecture intentionally avoids unnecessary:

- EKS control-plane fees
- NAT Gateways
- Elastic IPs
- managed load balancers
- always-running compute
- heavyweight observability stacks

Do not interpret promotional credits as permission to ignore gross cost.

Before introducing a billable service, explain:

- approximate cost model;
- whether cost continues while EC2 nodes are stopped;
- cheaper alternatives;
- cleanup or shutdown procedure;
- risk of unexpected ongoing charges.

Remember that stopped EC2 instances may still incur EBS and public IPv4-related
costs.

## Validation and Evidence

Match validation depth to the change.

For Terraform, prefer:

- `terraform fmt -check`
- `terraform validate`
- reviewed `terraform plan`
- post-apply output and resource inspection when apply is separately approved

For Kubernetes YAML, prefer:

- YAML parsing or linting
- `kubectl apply --dry-run=client`
- server-side dry run when a live cluster is available and approved
- `kubectl diff` before mutation when appropriate
- post-apply resource, event, endpoint, log, and traffic inspection

For Helm, prefer:

- values review
- `helm lint`
- `helm template`
- rendered-resource inspection
- release diff when tooling is available
- post-upgrade health checks

Static validation does not prove runtime behavior.

A successful command does not automatically prove the complete learning
objective. State exactly what was tested and what remains unverified.

Preserve useful failure evidence without committing credentials or sensitive
outputs.

## Documentation Standards

Documentation should be technical, concise, readable, and evidence-driven.

Explain:

- mission;
- architecture;
- why a decision was made;
- alternatives considered;
- security and cost implications;
- implementation;
- validation evidence;
- limitations;
- failure modes;
- next step.

Do not write generic portfolio or LinkedIn-style claims.

Do not claim deployment, health, recovery, security, or reliability without
evidence.

Useful documentation forms include:

- root README
- architecture diagrams
- ADRs
- runbooks
- incident reports
- session notes
- cost notes
- recovery-test reports

A useful session-note structure is:

- Date
- Mission
- Change
- Why
- Evidence
- Limitations
- Next

Keep transient runtime status out of this file when possible. Put verified
project status in the README or a dated session document.

## Change Design

Prefer minimal, coherent changes that represent one understandable milestone.

Do not combine unrelated Terraform, Kubernetes, documentation, CI, and
application changes in one change set.

Before implementing, inspect existing files and preserve unrelated user work.

Do not introduce a dependency, controller, operator, CRD, or managed cloud
service solely because it is popular.

Do not automate away a concept before it has been understood. Do automate boring
repetition after the concept is understood.

## Current Direction

Unless the repository owner gives a newer instruction, the next broad sequence
is:

1. Create and validate a cross-node basic-connectivity lab.
2. Prove Pod-to-Pod, HTTP, DNS, Service, EndpointSlice, IPAM, VXLAN, Cilium, and
   kube-proxy behavior.
3. Enable Hubble through the existing tracked Cilium Helm values.
4. Use the networking lab to observe flows.
5. Introduce a deliberate NetworkPolicy before-and-after experiment.
6. Observe both allowed and dropped traffic.

Do not assume any of these runtime exercises have been completed without
evidence.

## Definition of Done

A milestone is complete only when:

- its intended scope is implemented;
- relevant static checks pass or their absence is reported;
- runtime validation is performed when required and available;
- failures and limitations are stated honestly;
- significant documentation is updated;
- the repository owner has reviewed the result;
- no unapproved commit or push has occurred.

The repository should ultimately demonstrate that its owner can explain not only
what was deployed, but how it works, why it was chosen, how it fails, how it was
validated, how it is secured, how it is recovered, and what it costs.
