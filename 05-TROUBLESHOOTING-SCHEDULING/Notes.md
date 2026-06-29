# 🎯 K8s Lab 05 — Interview Notes
## Troubleshooting & Scheduling
---

### Q1. What is ErrImagePull and what causes it?

`ErrImagePull` means Kubernetes attempted to pull a container image and the pull failed.

Common causes:
- **Wrong image name or tag** — `nginx:ninja` doesn't exist on Docker Hub
- **Private registry, no credentials** — image exists but K8s can't authenticate
- **Registry down or unreachable** — network issue between node and registry
- **Rate limiting** — Docker Hub limits unauthenticated pulls (100/6hr per IP)

```bash
# Spot it with:
kubectl describe pod <pod-name>
# Look at Events → "Failed to pull image"
```

---

### Q2. What is ImagePullBackOff?

`ImagePullBackOff` is the state Kubernetes enters after `ErrImagePull` — it backs off and retries with increasing delay instead of hammering the registry continuously.

**Backoff intervals:** 10s → 20s → 40s → 80s → 160s → capped at ~5min

The pod stays in this state until:
- The image becomes available / the tag is corrected
- You apply a fixed Deployment (`kubectl apply -f`)
- The pod is deleted and recreated

---

### Q3. Difference between ErrImagePull and ImagePullBackOff?

```
ErrImagePull      = the pull attempt just failed (active failure)
ImagePullBackOff  = waiting before retrying (backoff state)
```

They indicate the same underlying problem — you'll often see a pod cycle between both states. Fix the root cause (image name or credentials) and both disappear.

---

### Q4. How do you authenticate Kubernetes with a private Docker registry?

Create an `imagePullSecret` and reference it in the Deployment:

```bash
# Step 1 — Create the secret
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<USERNAME> \
  --docker-password=<PASSWORD> \
  --docker-email=<EMAIL>
```

```yaml
# Step 2 — Reference it in the Deployment
spec:
  imagePullSecrets:
    - name: dockerhub-secret
  containers:
    - name: app
      image: <username>/private-app:latest
```

> **Production alternative:** Use ECR (AWS) or GCR (GCP) with IAM/Workload Identity — no secrets needed since the node's IAM role handles auth automatically.

---

### Q5. What is CrashLoopBackOff?

`CrashLoopBackOff` means the container starts, crashes immediately, Kubernetes restarts it, it crashes again — and this cycle repeats with exponential backoff between restarts.

**Key point:** The image pulled successfully. The container starts — but exits almost immediately.

```
Container starts → exits (crash) → K8s restarts → exits again →
CrashLoopBackOff → waits → restarts → exits → CrashLoopBackOff...
```

---

### Q6. What are the common causes of CrashLoopBackOff?

| Cause | Signal |
|-------|--------|
| Wrong CMD / ENTRYPOINT | `kubectl logs` → "command not found" |
| Missing config file | `kubectl logs` → "no such file or directory" |
| Missing environment variable | `kubectl logs` → app config error on startup |
| Database connection failure | `kubectl logs` → "connection refused" on startup |
| Application exception | `kubectl logs` → stack trace |
| Liveness probe misconfigured | `kubectl describe` → "Liveness probe failed" |

---

### Q7. How do you troubleshoot CrashLoopBackOff?

```bash
# 1 — Check current logs (if container is briefly running)
kubectl logs <pod-name>

# 2 — Check logs from the previous crashed instance
kubectl logs <pod-name> --previous

# 3 — Check events for probe failures, OOM, bad commands
kubectl describe pod <pod-name>

# 4 — Check exit code in describe output
# Exit code 1   → application error
# Exit code 137 → OOMKilled (128 + SIGKILL signal 9)
# Exit code 126 → permission denied (can't execute)
# Exit code 127 → command not found
```

> **Start with `kubectl logs --previous`** — the current instance might restart before you can read its logs. `--previous` shows the last terminated instance's output.

---

### Q8. What is a Liveness Probe and what happens when it fails?

A Liveness Probe is a health check Kubernetes runs on a container at regular intervals. If it fails consecutively (`failureThreshold` times), Kubernetes kills and restarts the container.

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 15   # wait before first check (app startup time)
  periodSeconds: 10          # check every 10s
  failureThreshold: 3        # kill after 3 consecutive failures
```

**When probes cause false failures:**
- `initialDelaySeconds` too low → probe fires before app finishes starting → unnecessary restarts
- Wrong port → connection refused → app is fine but probe thinks it's dead

**Three probe types:**
- `httpGet` — makes HTTP request, expects 2xx/3xx
- `tcpSocket` — checks if port is open
- `exec` — runs a command inside container, expects exit code 0

---

### Q9. What is OOMKilled and why does it happen?

`OOMKilled` means the Linux kernel terminated the container because it exceeded its configured memory limit.

```
Container memory > limits.memory
        │
        │  Linux cgroup enforces the limit
        ▼
Kernel sends SIGKILL → container dies
        │
        ▼
Pod status: OOMKilled | Exit code: 137
```

**OOMKilled is a kernel action, not a Kubernetes action.** Kubernetes sets the cgroup memory limit; the kernel enforces it.

```bash
kubectl describe pod <pod-name>
# Look for:
# Last State: Terminated
# Reason: OOMKilled
# Exit Code: 137
```

---

### Q10. What is the difference between Resource Requests and Limits?

```yaml
resources:
  requests:
    memory: "64Mi"    # minimum guaranteed — used for scheduling
    cpu: "250m"
  limits:
    memory: "128Mi"   # maximum allowed — enforced at runtime
    cpu: "500m"
```

| | Requests | Limits |
|-|----------|--------|
| **Purpose** | Scheduling decisions | Runtime enforcement |
| **Who uses it** | Kubernetes Scheduler | Linux kernel (cgroups) |
| **Effect if exceeded** | Not applicable | Memory → OOMKill, CPU → throttled |
| **Node requirement** | Node must have this much free | Container can't use more than this |

**CPU limit vs Memory limit behavior:**
- CPU over limit → container gets **throttled** (slowed down), not killed
- Memory over limit → container gets **killed** (OOMKilled) immediately

---

### Q11. Why not just increase memory limits when OOMKilled?

Because increasing limits treats the symptom, not the cause.

**Investigate first:**
```
OOMKilled
    ├── Memory leak?          → profile heap usage, check for unreleased objects
    ├── Unexpected traffic?   → check request rate metrics (Prometheus)
    ├── Inefficient code?     → optimize data structures, add pagination
    ├── Wrong estimation?     → measure actual usage under load, set limits accordingly
    │
    └── Only then → increase limits with data to back the number
```

Blindly increasing limits wastes cluster resources and can destabilize other pods on the same node.

---

### Q12. What does the Kubernetes Scheduler do?

The Scheduler watches for newly created Pods that have no node assigned. For each Pod, it:

1. **Filters** nodes — eliminates nodes that don't satisfy hard requirements (resource requests, nodeSelector, taints, affinity rules)
2. **Scores** remaining nodes — ranks them by available resources, affinity preferences, spread constraints
3. **Binds** the Pod to the highest-scoring node

```
New Pod (no node assigned)
        │
        ▼
Scheduler: filter → score → bind
        │
        ▼
Pod assigned to node → Kubelet on that node starts the container
```

---

### Q13. Why does a Pod stay in Pending?

`Pending` means the scheduler cannot find a suitable node. Most common reasons:

| Reason | How to Confirm |
|--------|---------------|
| Insufficient CPU on all nodes | `kubectl describe pod` → "Insufficient cpu" |
| Insufficient Memory on all nodes | `kubectl describe pod` → "Insufficient memory" |
| NodeSelector label missing | `kubectl describe pod` → "didn't match node selector" |
| NodeAffinity rule unsatisfied | `kubectl describe pod` → "didn't match affinity" |
| Taint not tolerated | `kubectl describe pod` → "had untolerated taint" |
| PVC not bound | `kubectl describe pod` → "unbound PersistentVolumeClaims" |

```bash
# Always check this first for Pending pods
kubectl describe pod <pod-name>
# Events section → FailedScheduling → exact reason
```

---

### Q14. What is a NodeSelector?

NodeSelector is the simplest way to constrain a Pod to specific nodes — it matches pods to nodes using exact label key-value pairs.

```yaml
spec:
  nodeSelector:
    node-name: arm-worker    # only schedule on nodes with this exact label
```

If no node has this label → Pod stays `Pending`.

```bash
# Add the label to a node
kubectl label node <node-name> node-name=arm-worker

# Verify
kubectl get nodes --show-labels
```

---

### Q15. What is Node Affinity and how is it different from NodeSelector?

Node Affinity is an advanced scheduling mechanism with expression-based rules and soft/hard requirements.

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:   # hard rule
        nodeSelectorTerms:
          - matchExpressions:
              - key: node-name
                operator: In
                values: [arm-worker, x86-worker]   # multiple values supported
```

| | NodeSelector | Node Affinity |
|-|-------------|--------------|
| Operators | `=` only | `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt` |
| Multiple values | ❌ | ✅ |
| Soft preference | ❌ | ✅ (`preferredDuring...`) |
| Flexibility | Low | High |

**Two affinity types:**
- `requiredDuringSchedulingIgnoredDuringExecution` — hard rule, pod won't schedule if unmet
- `preferredDuringSchedulingIgnoredDuringExecution` — soft rule, K8s tries but schedules elsewhere if needed

`IgnoredDuringExecution` means: if the node's labels change after the pod is already running, the pod keeps running. Only affects scheduling, not eviction.

---

### Q16. What troubleshooting commands should every DevOps engineer know?

```bash
# ── Pod Status ──────────────────────────────────────────
kubectl get pods                          # overview
kubectl get pods -o wide                  # + node and IP
kubectl get pods -w                       # watch in real time
kubectl get pods --all-namespaces         # across all namespaces

# ── Deep Inspection ─────────────────────────────────────
kubectl describe pod <pod-name>           # full status + events (start here)
kubectl logs <pod-name>                   # container stdout/stderr
kubectl logs <pod-name> --previous        # logs from last crashed instance
kubectl logs <pod-name> -f               # follow live logs

# ── Exec Into Container ──────────────────────────────────
kubectl exec -it <pod-name> -- /bin/bash  # shell inside container

# ── Events ───────────────────────────────────────────────
kubectl get events --sort-by='.lastTimestamp'

# ── Resource Usage ───────────────────────────────────────
kubectl top pods                          # CPU + memory per pod
kubectl top nodes                         # CPU + memory per node

# ── Nodes ────────────────────────────────────────────────
kubectl get nodes
kubectl get nodes --show-labels
kubectl describe node <node-name>

# ── Scheduling Debug ─────────────────────────────────────
kubectl label node <node-name> key=value  # add label
kubectl taint node <node-name> key=value:NoSchedule   # add taint
```

> **Order to follow:** `get pods` → `describe pod` (check Events) → `logs` → `logs --previous` → `get events`. Don't skip describe — the Events section tells you exactly what Kubernetes tried and why it failed.

---

### Q17. What is the difference between kubectl describe and kubectl logs?

| | `kubectl describe` | `kubectl logs` |
|-|--------------------|----------------|
| **Shows** | K8s object state + event history | Container stdout/stderr output |
| **Use for** | Scheduling failures, probe failures, image pull errors, resource issues | App-level errors, startup failures, runtime exceptions |
| **Works when** | Always — even if pod never started | Only if container ran (even briefly) |
| **Start here?** | ✅ Always start here | After describe points to app issue |

**Rule:** `describe` tells you what Kubernetes did. `logs` tells you what the app did. Both are needed for complete diagnosis.
