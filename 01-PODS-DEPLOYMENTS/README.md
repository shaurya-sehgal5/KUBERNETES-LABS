<div align="center">

<img src="https://img.shields.io/badge/K8s%20Lab-01-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white"/>
<img src="https://img.shields.io/badge/Pods-Deployments-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white"/>
<img src="https://img.shields.io/badge/ReplicaSet-Self--Healing-28a745?style=for-the-badge&logo=kubernetes&logoColor=white"/>
<img src="https://img.shields.io/badge/Status-Complete-28a745?style=for-the-badge"/>

# ☸️ K8s Lab 01 — Pods, Deployments & ReplicaSets

### From a single container to a self-healing, replicated workload. The core Kubernetes mental model — built and broken on purpose.

| [Back to Lab Index](../README.md)

</div>

---

## 🎯 Objective

Understand the three core Kubernetes abstractions — **Pod**, **Deployment**, **ReplicaSet** — by deploying them, observing how they relate to each other, and proving self-healing works by deleting a pod and watching Kubernetes replace it automatically.

This lab runs on a local **Kind** cluster — no cloud costs, same Kubernetes API.

---

## 🔑 Core Concept — The Kubernetes Object Hierarchy

Before writing any YAML, this is the mental model that makes everything else click:

```
You write → Deployment
               │
               │ creates and owns
               ▼
           ReplicaSet
               │
               │ creates and owns
               ▼
            Pod  Pod  Pod   (N replicas)
               │
               │ runs
               ▼
          Container (nginx, your app, etc.)
```

**Why this layering?**

- You manage **Deployments** — you define desired state (3 replicas of nginx)
- Kubernetes manages **ReplicaSets** — it creates/deletes pods to match desired count
- You never manage **Pods** directly in production — the ReplicaSet does it

> **The shift from Docker:** `docker run` is imperative — "run this container now." Kubernetes is declarative — "I want 3 of these running. Figure it out and keep it that way."

---

## 🧰 Tools Used

| Tool | Purpose |
|------|---------|
| `kubectl` | Kubernetes CLI — apply manifests, inspect resources |
| `Kind` | Local K8s cluster in Docker containers |
| `Docker` | Required by Kind as the container runtime |
| YAML | Manifest format for all K8s resource definitions |

---

## 🚀 Implementation

### Step 1 — Install kubectl & Kind

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client

# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
kind version
```

> **Add Screenshot:** kubectl and Kind installed, versions confirmed

---

### Step 2 — Create Local Kubernetes Cluster

```bash
# Create a single-node Kind cluster
kind create cluster --name k8s-lab

# Verify cluster is up
kubectl get nodes
```

Expected output:
```
NAME                    STATUS   ROLES           AGE   VERSION
k8s-lab-control-plane   Ready    control-plane   60s   v1.xx.x
```

> **What Kind actually does:** Runs a full Kubernetes control plane (API server, etcd, scheduler, controller manager) inside a Docker container on your machine. Same API, same `kubectl` commands — just local and free.

> **Add Screenshot:** Kind cluster created, node in Ready state

---

### Step 3 — Deploy a Standalone Pod

Created `pod.yml` — the simplest possible Kubernetes workload:

```yaml
# pod.yml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
    - name: nginx
      image: nginx:latest
      ports:
        - containerPort: 80
```

```bash
# Apply the manifest
kubectl apply -f pod.yml

# Verify pod is running
kubectl get pods
kubectl describe pod nginx-pod
```

```
NAME        READY   STATUS    RESTARTS   AGE
nginx-pod   1/1     Running   0          15s
```

> **Add Screenshot:** nginx-pod in Running state

---

### Step 4 — Prove the Pod Has No Self-Healing

```bash
# Delete the standalone pod
kubectl delete pod nginx-pod

# Check what's left
kubectl get pods
```

```
No resources found in default namespace.
```

**Gone. Permanently.** A standalone Pod has no controller watching over it. When it dies — hardware failure, OOM kill, manual deletion — it stays dead. This is why you never run production workloads as bare Pods.

This is the exact problem Deployments solve.

---

### Step 5 — Create a Deployment

Deleted the standalone Pod and created `deployment.yml`:

```yaml
# deployment.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3                      # desired state — keep 3 pods running
  selector:
    matchLabels:
      app: nginx                   # ReplicaSet uses this to find its pods
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "64Mi"
              cpu: "250m"
            limits:
              memory: "128Mi"
              cpu: "500m"
```

```bash
kubectl apply -f deployment.yml
```

```bash
# Verify all three layers were created
kubectl get deployments
kubectl get replicasets
kubectl get pods
```

```
NAME               READY   UP-TO-DATE   AVAILABLE
nginx-deployment   3/3     3            3          ✅

NAME                          DESIRED   CURRENT   READY
nginx-deployment-6b7f987c9d   3         3         3     ✅

NAME                                READY   STATUS
nginx-deployment-6b7f987c9d-2xkp9   1/1     Running
nginx-deployment-6b7f987c9d-7bnqr   1/1     Running
nginx-deployment-6b7f987c9d-m4t6w   1/1     Running
```

One `kubectl apply` → Deployment created → ReplicaSet created → 3 Pods created. Three layers, one command.

> **Add Screenshot:** Deployment, ReplicaSet, and 3 Pods all Running

---

### Step 6 — Prove Self-Healing (ReplicaSet in Action)

```bash
# Watch pods in real time in one terminal
kubectl get pods -w

# In another terminal — delete one pod by name
kubectl delete pod nginx-deployment-6b7f987c9d-2xkp9
```

Watch output:
```
NAME                                READY   STATUS        RESTARTS
nginx-deployment-6b7f987c9d-2xkp9   1/1     Running       0
nginx-deployment-6b7f987c9d-7bnqr   1/1     Running       0
nginx-deployment-6b7f987c9d-m4t6w   1/1     Running       0

# After delete command:
nginx-deployment-6b7f987c9d-2xkp9   1/1     Terminating   0        ← deleted
nginx-deployment-6b7f987c9d-9vp2k   0/1     Pending       0        ← new pod starts
nginx-deployment-6b7f987c9d-9vp2k   1/1     Running       0        ← back to 3 ✅
```

**What just happened:**
1. Pod deleted → current count drops to 2
2. ReplicaSet detects: `current (2) ≠ desired (3)`
3. ReplicaSet immediately schedules a new Pod
4. New Pod starts, count returns to 3
5. Total recovery time: **< 5 seconds**

> **Add Screenshot:** Pod terminating → new pod created automatically

---

## 🔍 Inspecting the Object Relationships

```bash
# See the full Deployment spec and status
kubectl describe deployment nginx-deployment

# See which Deployment owns which ReplicaSet
kubectl get rs -o wide

# See pod labels — this is how the ReplicaSet identifies its pods
kubectl get pods --show-labels

# See events — real-time record of what Kubernetes did and why
kubectl get events --sort-by='.lastTimestamp'
```

> `kubectl describe` and `kubectl get events` are your primary debugging tools in Kubernetes. When something isn't working, these two commands tell you exactly what the control plane is doing and why.

---

## 🧠 Docker vs Kubernetes — The Mental Model Shift

```
Docker (imperative)                   Kubernetes (declarative)
─────────────────────                 ──────────────────────────
docker run nginx                      kubectl apply -f deploy.yml
"start this container"                "I want 3 of these running"

docker stop nginx                     kubectl scale --replicas=0
"stop this container"                 "I want 0 of these running"

Container dies → it's gone            Pod dies → ReplicaSet replaces it

You manage containers                 You manage desired state
K8s manages reality
```

| | Docker | Kubernetes |
|-|--------|-----------|
| Unit of work | Container | Pod |
| Self-healing | ❌ | ✅ (via ReplicaSet) |
| Scaling | Manual | Declarative (`replicas: N`) |
| Rolling updates | Manual | Built-in (Deployment strategy) |
| State management | Imperative | Declarative YAML |

---

## 📁 Repository Structure

```
02-PODS-DEPLOYMENTS/
│
├── README.md          ← this file
├── pod.yml            ← standalone Pod manifest
├── deployment.yml     ← Deployment with 3 replicas
├── commands.sh        ← all kubectl commands used
└── screenshots/
    ├── kind-cluster.png
    ├── nginx-pod-running.png
    ├── deployment-created.png
    ├── pod-deleted.png
    └── self-healing.png
```

---

## 📚 Key Learnings

**Object hierarchy:**
- `Deployment` owns `ReplicaSet` owns `Pods` — you only ever interact with the Deployment
- Labels and `matchLabels` are how K8s objects find and own each other — getting these wrong breaks the entire hierarchy
- The pod name format `deployment-name-[rs-hash]-[pod-hash]` tells you exactly which Deployment and ReplicaSet a pod belongs to

**Self-healing mechanics:**
- The ReplicaSet controller runs a continuous reconciliation loop: `current state == desired state?` If no → act
- Deleting a Pod manually is the same as a crash from the ReplicaSet's perspective — it just sees one fewer pod and creates a replacement
- The ReplicaSet doesn't care *why* a pod is gone — it only cares that the count is wrong

**YAML manifest structure — every K8s resource has 4 top-level fields:**
```yaml
apiVersion:   # which K8s API handles this resource
kind:         # what type of resource
metadata:     # name, namespace, labels
spec:         # desired state — what you want
```

**Production habits to build now:**
- Always set `resources.requests` and `resources.limits` on containers — without limits, one pod can OOM the entire node
- Never run bare Pods in production — always use a Deployment (or StatefulSet/DaemonSet for specific cases)
- Use `kubectl get events` before `kubectl logs` when debugging — events show scheduling and runtime failures that logs can't

---

## ✅ Lab Completion Checklist

| Objective | Status |
|-----------|--------|
| kubectl and Kind installed and verified | ✅ |
| Local Kind cluster created, node in Ready state | ✅ |
| Standalone Pod deployed from `pod.yml` | ✅ |
| Pod deleted — confirmed no self-healing on bare Pod | ✅ |
| Deployment created with 3 replicas from `deployment.yml` | ✅ |
| Deployment → ReplicaSet → 3 Pods hierarchy confirmed | ✅ |
| Pod manually deleted — ReplicaSet self-healing observed live | ✅ |
| Recovery time measured — new pod Running in < 5 seconds | ✅ |

---

<div align="center">

[← K8s Lab 01: EKS + ALB](../01-EKS-ALB-Ingress/) | [Back to Lab Index](../README.md)

*You deleted a pod. Kubernetes didn't care. That's the point.*

</div>
