<div align="center">

<img src="https://img.shields.io/badge/K8s%20Lab-05-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white"/>
<img src="https://img.shields.io/badge/Troubleshooting-Production%20Issues-DC143C?style=for-the-badge&logo=kubernetes&logoColor=white"/>
<img src="https://img.shields.io/badge/Scheduling-Node%20Affinity-0A66C2?style=for-the-badge&logo=kubernetes&logoColor=white"/>
<img src="https://img.shields.io/badge/Status-Complete-28a745?style=for-the-badge"/>

# ☸️ K8s Lab 05 — Troubleshooting & Scheduling

### 7 real failure scenarios. Every error you'll hit in production — triggered on purpose, diagnosed, and fixed.

</div>

---

## 🎯 Objective

Deploying an app is the easy part. Keeping it running when things break — that's the job.

This lab covers the most common Kubernetes failure states a DevOps engineer encounters in production, triggered deliberately so the root cause is visible and the fix is repeatable.

| Scenario | Error State | Root Cause |
|----------|------------|------------|
| 01 | `ErrImagePull` → `ImagePullBackOff` | Invalid image name or tag |
| 02 | `ErrImagePull` → `ImagePullBackOff` | Private registry, no pull secret |
| 03 | `CrashLoopBackOff` | Container starts and immediately exits |
| 04 | `CrashLoopBackOff` (repeated restarts) | Liveness probe failing |
| 05 | `OOMKilled` | Container exceeds memory limit |
| 06 | `Pending` | NodeSelector label doesn't exist on any node |
| 07 | `Pending` | NodeAffinity rule matches no node |

---

## 🧰 Tools Used

| Tool | Purpose |
|------|---------|
| `Kind` | Multi-node local K8s cluster |
| `kubectl` | Inspect, debug, and fix resources |
| `Docker Hub` | Image registry (public + private) |
| `Linux cgroups` | Kernel mechanism behind OOMKill |

---

## 🔑 Core Concept — The Troubleshooting Hierarchy

Before touching anything, always run these in order:

```bash
# 1 — What's the pod status?
kubectl get pods

# 2 — What exactly went wrong? (events section is gold)
kubectl describe pod <pod-name>

# 3 — What did the container print before dying?
kubectl logs <pod-name>

# 4 — Previous container logs (if pod restarted)
kubectl logs <pod-name> --previous

# 5 — Is it a scheduling issue? (check events for "FailedScheduling")
kubectl get events --sort-by='.lastTimestamp'
```

> `kubectl describe` → check the **Events** section at the bottom. It tells you exactly what Kubernetes tried, what failed, and when. This is always step one.

---

# 📋 Scenario 01 — ErrImagePull & ImagePullBackOff

## What Happened

A valid Deployment was running. The image was intentionally changed to an invalid tag:

```yaml
# deployment.yml
containers:
  - name: nginx
    image: nginx:ninja      # this tag does not exist on Docker Hub
```

```bash
kubectl apply -f deployment.yml
kubectl get pods
```

```
NAME                    READY   STATUS             RESTARTS
nginx-xxxxxxx           0/1     ErrImagePull       0
nginx-xxxxxxx           0/1     ImagePullBackOff   0
```

## Why This Happens

```
Kubernetes tries to pull nginx:ninja from Docker Hub
        │
        │  Docker Hub: 404 — tag not found
        ▼
ErrImagePull   ← pull attempt failed
        │
        │  K8s waits (exponential backoff: 10s → 20s → 40s → 80s → 5min)
        ▼
ImagePullBackOff  ← waiting between retry attempts
```

**Exponential backoff** prevents hammering the registry with continuous failed requests. The pod stays in `ImagePullBackOff` until the image becomes available or you fix the manifest.

## Diagnosis

```bash
kubectl describe pod <pod-name>
```

```
Events:
  Warning  Failed     BackOff pulling image "nginx:ninja"
  Warning  Failed     Error: ErrImagePull
  Normal   BackOff    Back-off pulling image "nginx:ninja"
```

## Fix

```yaml
image: nginx:latest    # use a valid tag
```

```bash
kubectl apply -f deployment.yml
```

> **Add Screenshot:** Pod in ImagePullBackOff → Running after fix

---

# 📋 Scenario 02 — Private Registry Authentication

## What Happened

The Deployment was updated to reference a **private Docker Hub image**. Image exists — but Kubernetes can't authenticate:

```yaml
image: <dockerhub-username>/private-app:latest
```

```
ErrImagePull → ImagePullBackOff   (same states, different root cause)
```

## Why This Happens

```
Kubernetes node tries to pull private image
        │
        │  Docker Hub: 401 Unauthorized — no credentials
        ▼
ErrImagePull
```

K8s nodes have no way to know your Docker Hub credentials unless you explicitly provide them as a Secret.

## Fix — Create an imagePullSecret

```bash
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<USERNAME> \
  --docker-password=<PASSWORD> \
  --docker-email=<EMAIL>
```

Reference the Secret in the Deployment:

```yaml
spec:
  imagePullSecrets:
    - name: dockerhub-secret    # ← add this
  containers:
    - name: app
      image: <username>/private-app:latest
```

```bash
kubectl apply -f deployment.yml
kubectl get pods
# STATUS: Running ✅
```

> **Add Screenshot:** Private image pulled successfully after secret

> **Production note:** In real environments, use a service account with an attached imagePullSecret rather than patching every Deployment individually. Or use ECR/GCR with IAM/Workload Identity — no secrets needed at all.

---

# 📋 Scenario 03 — CrashLoopBackOff

## What Happened

The Docker image was valid and pulled successfully. But the container was given an invalid startup command:

```yaml
containers:
  - name: app
    image: ubuntu
    command: ["invalid-command"]    # does not exist in the image
```

```bash
kubectl get pods -w
```

```
NAME           READY   STATUS             RESTARTS
app-xxxxxxx    0/1     Error              1
app-xxxxxxx    0/1     CrashLoopBackOff   2
app-xxxxxxx    0/1     Error              3
app-xxxxxxx    0/1     CrashLoopBackOff   4   ← keeps cycling
```

## Why This Happens

```
Container starts
      │
      │  process exits immediately (bad command / exception / missing file)
      ▼
Kubernetes restarts it   (restart policy: Always by default)
      │
      │  crashes again immediately
      ▼
Kubernetes waits (exponential backoff) then restarts again
      │
      ▼
CrashLoopBackOff  ← restarting but backing off between attempts
```

## Diagnosis

```bash
# Check what the container printed before dying
kubectl logs <pod-name>

# Check previous container instance logs
kubectl logs <pod-name> --previous

# Check events for the exact error
kubectl describe pod <pod-name>
```

## Common Root Causes

| Cause | How to Spot It |
|-------|---------------|
| Wrong CMD / ENTRYPOINT | `kubectl logs` → "command not found" |
| Missing config file | `kubectl logs` → "no such file" |
| Bad environment variable | `kubectl logs` → app-specific config error |
| Missing database connection | `kubectl logs` → "connection refused" |
| App exception on startup | `kubectl logs` → stack trace |

## Fix

```yaml
command: ["sleep", "infinity"]    # valid command — container stays alive
```

```bash
kubectl apply -f deployment.yml
```

> **Add Screenshot:** CrashLoopBackOff → Running after command fix

---

# 📋 Scenario 04 — Liveness Probe Failures

## What Happened

A Liveness Probe was configured to check the wrong port:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 9999        # app runs on 8080 — wrong port
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 3
```

## Why This Happens

```
Kubernetes checks: GET http://pod-ip:9999/health every 10s
        │
        │  Connection refused — nothing on port 9999
        ▼
Probe fails × 3 consecutive times (failureThreshold: 3)
        │
        ▼
Kubernetes kills the container and restarts it
        │
        ▼
CrashLoopBackOff  ← container is healthy, probe is wrong
```

## The Subtle Danger

The container and app are running fine — but Kubernetes kills it because the probe says it's dead. This is a configuration error masquerading as an app failure.

## Fix

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080          # match the actual app port
  initialDelaySeconds: 15   # give app time to start before first check
  periodSeconds: 10
  failureThreshold: 3
```

> **Probe types:** `httpGet` (HTTP endpoint check), `tcpSocket` (port open check), `exec` (run a command inside container). Use `initialDelaySeconds` generously — probes that fire before the app finishes starting cause false failures.

---

# 📋 Scenario 05 — OOMKilled

## What Happened

The Deployment was configured with a very small memory limit:

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"    # intentionally too low
    cpu: "200m"
```

When the application consumed more than 128Mi of memory:

```bash
kubectl get pods
```

```
NAME          READY   STATUS      RESTARTS
app-xxxxxxx   0/1     OOMKilled   3
```

## Why This Happens

```
Container memory usage > 128Mi (the configured limit)
        │
        │  Linux kernel enforces cgroup memory limit
        ▼
Kernel sends SIGKILL to the container process
        │
        ▼
Pod status: OOMKilled
        │
        ▼
Kubernetes restarts the container (restart policy: Always)
        │
        ▼
Crashes again → OOMKilled again → CrashLoopBackOff
```

**OOMKilled is a kernel action, not a Kubernetes action.** K8s sets the cgroup limit, the Linux kernel enforces it.

## Diagnosis

```bash
kubectl describe pod <pod-name>
```

```
Last State: Terminated
  Reason:   OOMKilled
  Exit Code: 137         ← 128 + 9 (SIGKILL signal number)
```

Exit code 137 = process killed by signal 9 (SIGKILL) = OOM.

## Fix — Don't Just Raise the Limit

In production, increasing limits is the last resort. Investigate first:

```
OOMKilled
    │
    ├── Is there a memory leak?       → profile the app
    ├── Unexpected traffic spike?     → check request rate metrics
    ├── Inefficient code?             → optimize memory usage
    ├── Wrong resource estimation?    → set limits based on actual usage
    │
    └── Only if none of the above → increase memory limit
```

```yaml
limits:
  memory: "512Mi"    # increase after investigation
```

> **Add Screenshot:** OOMKilled pod, Exit Code 137 in describe output

---

# 🖥️ Multi-Node Cluster Setup

Scheduling scenarios require multiple nodes. Created a multi-node Kind cluster:

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker
```

```bash
kind create cluster --name multi-node --config kind-config.yaml
kubectl get nodes
```

```
NAME                       STATUS   ROLES
multi-node-control-plane   Ready    control-plane
multi-node-worker          Ready    <none>
multi-node-worker2         Ready    <none>
multi-node-worker3         Ready    <none>
```

## Disk Space Issue During Setup

**Problem:** Kind cluster creation failed — EC2 instance ran out of disk space.

**Root Cause:** Default EBS volume (8GB) was too small for Docker images + Kind cluster images + Kubernetes components.

**Fix:**

```bash
# 1. Increase EBS volume in AWS Console: 8GB → 20GB

# 2. On the EC2 instance — resize the partition
sudo growpart /dev/xvda 1

# 3. Resize the filesystem
sudo resize2fs /dev/xvda1

# 4. Verify
df -h
```

> This is a real operational task in self-managed K8s environments. Always provision at least 20GB for a K8s lab EC2 instance.

> **Add Screenshot:** Multi-node cluster — all nodes Ready

---

# 📋 Scenario 06 — Node Selector (Pending Pod)

## What Happened

A Deployment was configured to run only on a specific node using `nodeSelector`:

```yaml
# deployment.yml
spec:
  template:
    spec:
      nodeSelector:
        node-name: arm-worker    # only schedule on nodes with this label
      containers:
        - name: nginx
          image: nginx:latest
```

```bash
kubectl apply -f deployment.yml
kubectl get pods
```

```
NAME          READY   STATUS    RESTARTS
app-xxxxxxx   0/1     Pending   0         ← stuck, never scheduled
```

## Why This Happens

```
Scheduler looks for a node where:
  labels["node-name"] == "arm-worker"
        │
        │  No node has this label
        ▼
Pod stays Pending indefinitely — scheduler has nowhere to put it
```

## Diagnosis

```bash
kubectl describe pod <pod-name>
```

```
Events:
  Warning  FailedScheduling  0/4 nodes are available:
           4 node(s) didn't match Pod's node affinity/selector.
```

## Fix

```bash
# Label the target worker node
kubectl label node multi-node-worker node-name=arm-worker

# Verify label applied
kubectl get nodes --show-labels | grep arm-worker

# Pod should now schedule automatically
kubectl get pods
# STATUS: Running ✅
```

> **Add Screenshot:** Pod Pending → Running after node label applied

---

# 📋 Scenario 07 — Node Affinity (Advanced Scheduling)

## What Happened

Node Affinity was configured with a rule that matched no existing node:

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: node-arc
                operator: In
                values:
                  - windows        # no node has this label
```

```
Pod stays: Pending
```

Updated the rule to match the labeled node:

```yaml
- key: node-name
  operator: In
  values:
    - arm-worker    # matches the label applied in Scenario 06
```

```bash
kubectl apply -f deployment.yml
kubectl get pods -o wide
```

```
NAME          READY   STATUS    NODE
app-xxxxxxx   1/1     Running   multi-node-worker   ✅
```

## Node Selector vs Node Affinity

| | Node Selector | Node Affinity |
|-|--------------|---------------|
| **Syntax** | Simple key-value match | Expression-based rules |
| **Operators** | Equality only (`=`) | `In`, `NotIn`, `Exists`, `Gt`, `Lt` |
| **Required vs preferred** | Always required | `required` or `preferred` |
| **Multiple values** | ❌ | ✅ `values: [x, y, z]` |
| **Flexibility** | Low | High |

**`requiredDuringSchedulingIgnoredDuringExecution`** — Pod will only be scheduled on matching nodes. If already running and node label is removed, pod continues running (the "IgnoredDuringExecution" part).

**`preferredDuringSchedulingIgnoredDuringExecution`** — Kubernetes tries to place the pod on matching nodes but will schedule elsewhere if none match. Soft rule.

> **Add Screenshot:** Pod scheduled onto correct node via Node Affinity

---

## 📚 Key Learnings

**Image Pull Failures:**
- `ErrImagePull` = the pull attempt failed right now
- `ImagePullBackOff` = waiting before retrying (exponential backoff)
- Same states, different root causes: wrong tag vs private registry auth
- Fix private registry: `kubectl create secret docker-registry` + `imagePullSecrets`

**CrashLoopBackOff:**
- Container starts and exits immediately — not a scheduling issue
- Always check `kubectl logs --previous` — logs from the crashed instance
- Exit code 1 = app error, Exit code 137 = OOMKill, Exit code 126/127 = bad command

**OOMKilled:**
- Exit code 137 = killed by kernel (SIGKILL) due to memory limit breach
- K8s sets cgroup limit, Linux kernel enforces it
- Investigate memory leak / traffic spike before raising limits

**Scheduling (Pending Pods):**
- `Pending` = scheduler can't find a suitable node
- Check `kubectl describe pod` → Events → `FailedScheduling`
- NodeSelector: simple, label must match exactly
- NodeAffinity: flexible, supports expressions, required vs preferred rules

**Operational note:**
- Disk space on EC2 is a real constraint — always resize EBS and filesystem before running multi-node clusters
- `growpart` + `resize2fs` is the standard Linux disk expansion procedure

---

## ✅ Lab Completion Checklist

| Scenario | Objective | Status |
|----------|-----------|--------|
| 01 | Triggered `ImagePullBackOff` with invalid image tag — fixed | ✅ |
| 02 | Triggered `ImagePullBackOff` with private image — fixed with `imagePullSecrets` | ✅ |
| 03 | Triggered `CrashLoopBackOff` with bad command — diagnosed via logs | ✅ |
| 04 | Triggered liveness probe failure — fixed probe port and delay | ✅ |
| 05 | Triggered `OOMKilled` with tight memory limit — explained cgroup mechanism | ✅ |
| — | Multi-node Kind cluster created — disk space issue resolved | ✅ |
| 06 | Triggered `Pending` via missing NodeSelector label — fixed by labeling node | ✅ |
| 07 | Triggered `Pending` via NodeAffinity mismatch — fixed rule, pod scheduled | ✅ |

---

<div align="center">


*Breaking things on purpose is the fastest way to know what to do when they break for real.*

</div>
