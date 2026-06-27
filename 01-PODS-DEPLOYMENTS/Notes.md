# 🎯 K8s Lab 01 — Interview Notes
## Pods, Deployments & ReplicaSets
---

### Q1. What is Kubernetes?

Kubernetes is an open-source container orchestration platform that automates deploying, scaling, and managing containerized applications across a cluster of machines.

**The problem it solves:** Docker runs containers on one machine. When you have 10 services, 50 replicas, and 3 servers — who decides which container runs where? Who restarts it when it crashes? Who balances the load? Kubernetes does all of that.

**One line:** Docker runs containers. Kubernetes runs containers *at scale, reliably, automatically.*

---

### Q2. What is a Pod?

A Pod is the smallest deployable unit in Kubernetes. It wraps one or more containers that share:
- The same **network namespace** (same IP, same localhost)
- The same **storage volumes**
- The same **lifecycle** (start together, die together)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
    - name: nginx
      image: nginx:latest
      ports:
        - containerPort: 80
```

**Why not just use containers directly?** Kubernetes needs a unit it can schedule, network, and manage. The Pod is that unit — it gives containers a shared identity on the cluster.

---

### Q3. What is the difference between a Pod and a Container?

| | Container | Pod |
|-|-----------|-----|
| **What it is** | A running process (Docker) | A K8s wrapper around containers |
| **Networking** | Docker-managed | Shared IP across all containers in pod |
| **Managed by** | Docker daemon | Kubernetes control plane |
| **Self-healing** | ❌ | ✅ (via ReplicaSet) |
| **Scheduling** | Manual | Kubernetes scheduler |

A Pod can have multiple containers — the main app container + sidecar containers (logging agent, proxy, config loader). They all share one IP and talk to each other via `localhost`.

---

### Q4. What is a Deployment?

A Deployment is a Kubernetes object that declaratively manages a set of identical Pods.

You tell the Deployment: *"I want 3 replicas of nginx running."*  
The Deployment makes it happen and keeps it that way — forever.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:latest
```

Deployments also handle:
- **Rolling updates** — update pods one at a time, zero downtime
- **Rollbacks** — `kubectl rollout undo` if the new version breaks
- **Scaling** — `kubectl scale --replicas=10` instantly

---

### Q5. What is a ReplicaSet?

A ReplicaSet is the controller that ensures a specified number of Pod replicas are running at all times.

It runs a continuous reconciliation loop:
```
current pods == desired pods?
  NO → create or delete pods until they match
  YES → do nothing, check again in a moment
```

**You don't create ReplicaSets directly.** You create a Deployment — the Deployment creates and owns the ReplicaSet automatically.

---

### Q6. What is the difference between a Deployment and a ReplicaSet?

| | ReplicaSet | Deployment |
|-|-----------|-----------|
| **Purpose** | Maintain replica count | Manage ReplicaSets + updates |
| **Rolling updates** | ❌ | ✅ |
| **Rollback** | ❌ | ✅ |
| **Use directly?** | Almost never | Always |
| **Owns** | Pods | ReplicaSets |

When you do a rolling update, the Deployment creates a **new ReplicaSet** (new version) and scales down the **old ReplicaSet** gradually. At any point during the update, both ReplicaSets exist — that's how zero-downtime updates work.

---

### Q7. What happens when a Pod is deleted?

If the pod belongs to a Deployment/ReplicaSet:

```
Pod deleted
    │
    ▼
ReplicaSet detects: current (2) ≠ desired (3)
    │
    ▼
ReplicaSet schedules a new Pod immediately
    │
    ▼
New Pod running — count back to 3
Total time: < 5 seconds
```

If it's a **standalone Pod** (no Deployment):
```
Pod deleted → gone permanently. No controller watching it.
```

This is why you never run production workloads as bare Pods.

---

### Q8. What is the difference between Imperative and Declarative?

| | Imperative | Declarative |
|-|-----------|------------|
| **How** | "Do this now" | "I want this state" |
| **Docker example** | `docker run nginx` | — |
| **K8s example** | `kubectl run nginx --image=nginx` | `kubectl apply -f deployment.yml` |
| **Idempotent?** | ❌ Run twice = two containers | ✅ Run twice = same result |
| **Version control** | ❌ | ✅ YAML in Git |
| **Self-healing** | ❌ | ✅ K8s reconciles continuously |

**Why declarative wins:** You commit your YAML to Git. Anyone can reproduce the exact environment. Kubernetes continuously reconciles reality to match the spec — if something drifts, K8s corrects it.

---

### Q9. What are Labels and Selectors? Why do they matter?

**Labels** are key-value pairs attached to K8s objects:
```yaml
metadata:
  labels:
    app: nginx
    env: production
    version: v2
```

**Selectors** are how objects find each other using labels:
```yaml
selector:
  matchLabels:
    app: nginx   # ReplicaSet manages pods with this label
```

**Why they matter:** Labels are the glue of Kubernetes.
- ReplicaSet finds its pods via `matchLabels`
- Services route traffic to pods via `selector`
- Get wrong labels → ReplicaSet can't find its pods → no self-healing
- Get wrong selector on a Service → traffic goes nowhere

> Getting labels/selectors wrong is one of the most common beginner mistakes. Always verify they match across Deployment → ReplicaSet → Pod → Service.

---

### Q10. What is Self-Healing in Kubernetes?

Self-healing is Kubernetes automatically detecting and recovering from failures without human intervention.

**How it works:**
- The Deployment controller continuously compares **desired state** (3 replicas) with **actual state** (2 running)
- If they differ → controller acts to reconcile
- Covers: pod crashes, node failures, OOMKills, manual deletions

**Proven in this lab:**
```bash
kubectl delete pod nginx-deployment-xxxxx   # manually deleted one pod
kubectl get pods -w                          # watched new pod spin up in < 5s
```

**This is the core value of Kubernetes** — your app stays up even when individual containers or nodes fail.

---

### Q11. How does the Kubernetes control plane work?

```
You run: kubectl apply -f deployment.yml
              │
              ▼
        API Server         ← single entry point for all K8s operations
              │
        etcd               ← stores desired state (your YAML)
              │
        Scheduler          ← decides which node each pod runs on
              │
        Controller Manager ← runs controllers (Deployment, ReplicaSet, etc.)
              │              continuously reconciles actual → desired state
        Kubelet            ← agent on each node, runs the actual containers
```

> **Interview tip:** If asked "what happens when you run kubectl apply" — walk through this chain. It shows you understand K8s internals, not just the CLI.

---

### Q12. What is Kind and why use it?

Kind (Kubernetes in Docker) runs a full Kubernetes cluster inside Docker containers on your local machine.

**Why Kind for labs:**
- Free — no cloud costs
- Fast setup (~60 seconds)
- Same Kubernetes API as EKS, GKE, AKS — everything you learn transfers directly
- Perfect for learning, testing, and CI/CD pipelines

**Limitation:** Not for production. It's single-node, runs inside Docker, and has no persistent storage across restarts.

---

### Q13. Difference between Docker and Kubernetes?

| | Docker | Kubernetes |
|-|--------|-----------|
| **Purpose** | Build and run containers | Orchestrate containers at scale |
| **Scope** | Single machine | Cluster of machines |
| **Self-healing** | ❌ | ✅ |
| **Load balancing** | Manual | Built-in |
| **Scaling** | Manual (`docker run` again) | Declarative (`replicas: 10`) |
| **Networking** | Docker networks | K8s Services, CNI plugins |
| **Config management** | Env vars, bind mounts | ConfigMaps, Secrets |

**They work together** — Docker (or containerd) is the container runtime that runs on each K8s node. K8s uses it under the hood. You write K8s YAML, K8s tells the runtime to start containers.

---

### Q14. What kubectl commands do you use most?

```bash
# Apply/create resources
kubectl apply -f <file.yml>

# View resources
kubectl get pods
kubectl get deployments
kubectl get replicasets
kubectl get all

# Inspect and debug
kubectl describe pod <pod-name>     # full event log + status
kubectl logs <pod-name>             # container stdout/stderr
kubectl exec -it <pod-name> -- bash # shell inside container

# Watch in real-time
kubectl get pods -w

# Scale
kubectl scale deployment nginx-deployment --replicas=5

# Rollout
kubectl rollout status deployment nginx-deployment
kubectl rollout undo deployment nginx-deployment

# Cleanup
kubectl delete -f <file.yml>
kubectl delete pod <pod-name>
```

---

### Q15. Why use Deployments instead of standalone Pods?

| Feature | Bare Pod | Deployment |
|---------|----------|-----------|
| Self-healing | ❌ Dies permanently | ✅ Replaced automatically |
| Scaling | ❌ Manual | ✅ `--replicas=N` |
| Rolling updates | ❌ | ✅ Zero downtime |
| Rollback | ❌ | ✅ `kubectl rollout undo` |
| Version history | ❌ | ✅ Revision tracking |

**Proved in this lab:** Deleted a standalone pod → gone forever. Deleted a Deployment pod → back in < 5 seconds. That's the entire argument in one demonstration.

**Rule:** Never run production workloads as bare Pods. Always use a Deployment (or StatefulSet for stateful apps, DaemonSet for node-level agents).
