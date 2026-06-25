# Kubernetes Architecture

> **Interview Focus** — Control Plane + Worker Nodes. Know every component, what it does, and what breaks if it goes down.

---

## High-Level Architecture

```
                         [ User / CI/CD ]
                                │
                           kubectl / API
                                │
                    ┌───────────▼────────────┐
                    │      CONTROL PLANE      │
                    │                         │
                    │  ┌─────────────────┐    │
                    │  │   API Server    │◄───┼─── Single entry point for all ops
                    │  └────┬──────┬─────┘    │
                    │       │      │           │
                    │  ┌────▼──┐ ┌─▼────────┐ │
                    │  │Sched- │ │Controller│ │
                    │  │uler   │ │Manager   │ │
                    │  └───────┘ └──────────┘ │
                    │                         │
                    │  ┌──────┐ ┌───────────┐ │
                    │  │ etcd │ │Cloud Ctrl │ │
                    │  │ (DB) │ │Manager    │ │
                    │  └──────┘ └───────────┘ │
                    └───────────┬─────────────┘
                                │ watches / instructs
               ┌────────────────┴────────────────┐
               │                                  │
   ┌───────────▼──────────┐          ┌────────────▼─────────┐
   │     Worker Node 1     │          │     Worker Node 2     │
   │                       │          │                       │
   │  Kubelet              │          │  Kubelet              │
   │  kube-proxy           │          │  kube-proxy           │
   │  Container Runtime    │          │  Container Runtime    │
   │                       │          │                       │
   │  ┌──────┐  ┌──────┐   │          │  ┌──────┐  ┌──────┐  │
   │  │ Pod  │  │ Pod  │   │          │  │ Pod  │  │ Pod  │  │
   │  └──────┘  └──────┘   │          │  └──────┘  └──────┘  │
   └───────────────────────┘          └──────────────────────┘
```

---

## Control Plane Components

### 1. API Server
- **The brain / single entry point** for the entire cluster.
- Every component (Scheduler, Controller Manager, Kubelet) talks *only* through the API Server — never directly to each other.
- Validates and authenticates every request (RBAC).
- Persists cluster state to etcd after validation.

```
kubectl apply -f pod.yaml
      │
      ▼
  API Server  ──► validates ──► writes to etcd ──► notifies Scheduler
```

> **Interview:** If API Server goes down, you can't create/modify anything. Existing Pods keep running (they're on nodes), but no new scheduling happens.

---

### 2. etcd
- Distributed **key-value store** — the only persistent storage in the cluster.
- Stores everything: Pods, Nodes, Deployments, Services, ConfigMaps, Secrets, RBAC rules.
- **Single source of truth.** If etcd is corrupted without a backup → entire cluster state is lost.

```
Key                          Value
─────────────────────────────────────────────
/registry/pods/default/nginx  → { spec, status, labels... }
/registry/nodes/node-1        → { capacity, conditions... }
/registry/services/default/svc → { clusterIP, ports... }
```

> **Interview:** etcd uses the **Raft consensus algorithm** for distributed consistency. Recommended to run etcd on dedicated nodes with regular backups (`etcdctl snapshot save`).

---

### 3. Scheduler
- Watches for **unscheduled Pods** (Pods with no `nodeName` set).
- Selects the best Worker Node based on:
  - Available CPU / Memory
  - Node Affinity / Anti-Affinity rules
  - Taints and Tolerations
  - Pod priority

```
New Pod (unscheduled)
        │
        ▼
   Scheduler
        │
   Filtering ──► remove nodes that don't meet requirements
        │
   Scoring  ──► rank remaining nodes
        │
        ▼
   Best Node selected ──► API Server updates Pod spec with nodeName
```

> **Interview:** Scheduler only *decides* where a Pod goes. It doesn't actually start the Pod — Kubelet does.

---

### 4. Controller Manager
- Runs multiple **controllers** in a single binary, each watching for drift between desired and actual state.
- Uses a **reconciliation loop**: observe → diff → act.

| Controller | Responsibility |
|---|---|
| ReplicaSet Controller | Ensures desired replica count is always running |
| Node Controller | Marks nodes as unhealthy, evicts Pods from dead nodes |
| Deployment Controller | Manages rolling updates and rollbacks |
| Job Controller | Ensures batch jobs run to completion |
| Endpoint Controller | Keeps Service → Pod endpoint mappings updated |

> **Interview:** Controllers never talk to nodes directly — they update desired state via the API Server, and Kubelet acts on it.

---

### 5. Cloud Controller Manager (CCM)
- Separates cloud-provider-specific logic from core Kubernetes.
- Only present in **cloud-managed clusters** (EKS, GKE, AKS).

Manages:
- **Load Balancers** — when you create a `Service: LoadBalancer`, CCM provisions an AWS ALB/NLB/GCP LB.
- **Node lifecycle** — removes cluster nodes when cloud VMs are terminated.
- **Storage volumes** — provisions EBS, GCP Persistent Disk, Azure Disk dynamically.

---

## Worker Node Components

### 1. Kubelet
- **Agent running on every node.** Communicates with the API Server.
- Receives `PodSpec` and ensures containers described in it are running and healthy.
- Reports node and Pod status back to the API Server.
- Does NOT manage containers created outside of Kubernetes.

```
API Server
    │  sends PodSpec
    ▼
 Kubelet
    │  instructs
    ▼
Container Runtime (containerd / CRI-O)
    │  runs
    ▼
 Container inside Pod
```

> **Interview:** If Kubelet dies on a node, no new Pods can be started on that node, and the node becomes `NotReady`.

---

### 2. Container Runtime
- Responsible for **pulling images and running containers** inside Pods.
- Kubernetes uses **CRI (Container Runtime Interface)** to talk to any compliant runtime.

| Runtime | Notes |
|---|---|
| containerd | Default in most managed clusters (EKS, GKE) |
| CRI-O | Lightweight, used with OpenShift |
| Docker (deprecated) | Removed as default in Kubernetes 1.24+ |

---

### 3. kube-proxy
- Runs on every node. Manages **networking rules** (iptables / ipvs) to route traffic to the right Pods.
- Implements **Service** abstraction — when you hit a ClusterIP, kube-proxy routes it to a healthy Pod.

```
Client ──► ClusterIP:Port
                │
           kube-proxy (iptables rules)
                │
    ┌───────────┼───────────┐
    ▼           ▼           ▼
  Pod 1       Pod 2       Pod 3
```

> **Interview:** kube-proxy does NOT assign Pod IP addresses. Pod IPs come from the **CNI plugin** (Calico, Flannel, AWS VPC CNI, etc.). kube-proxy just routes traffic to those IPs.

---

## Request Lifecycle — End to End

```
kubectl apply -f deployment.yaml
         │
         ▼
    1. API Server  ──► authenticates, validates, writes to etcd
         │
         ▼
    2. Controller Manager  ──► Deployment Controller sees new Deployment
         │                     creates ReplicaSet → creates Pods (unscheduled)
         ▼
    3. Scheduler  ──► watches unscheduled Pods, picks best node
         │             updates Pod spec: nodeName = worker-node-2
         ▼
    4. Kubelet (on worker-node-2)  ──► sees Pod assigned to it
         │                              tells container runtime to pull image + start container
         ▼
    5. Container Runtime  ──► pulls image, starts container
         │
         ▼
    6. kube-proxy  ──► updates iptables rules so Service routes to new Pod
         │
         ▼
    7. Controller Manager  ──► continuously reconciles — restarts Pod if it crashes
```

---

## What Happens When Things Die

| Component dies | Impact |
|---|---|
| **API Server** | No new changes. Existing Pods keep running. |
| **etcd** | Cluster state lost (if no backup). Reads/writes fail. |
| **Scheduler** | New Pods stay `Pending` forever. Existing Pods unaffected. |
| **Controller Manager** | No auto-healing, no replica enforcement. Drift goes undetected. |
| **Kubelet** | Node goes `NotReady`. No new Pods on that node. |
| **kube-proxy** | Service traffic breaks on that node. Pods still run but unreachable via Services. |
| **etcd (1 of 3 nodes in HA)** | Cluster remains healthy (quorum maintained with 2/3). |

---

## Interview Quick Reference

| Component | One-liner |
|---|---|
| API Server | Entry point for everything. All components talk through it. |
| etcd | Distributed KV store. Single source of truth. Back it up. |
| Scheduler | Decides *where* a Pod runs. Kubelet decides *how*. |
| Controller Manager | Reconciliation loops. Desired state = actual state. |
| Cloud Controller Manager | Bridges Kubernetes with cloud provider APIs. |
| Kubelet | Node agent. Runs Pods. Reports health. |
| Container Runtime | Pulls images, runs containers. (containerd, CRI-O) |
| kube-proxy | iptables rules for Service networking. Does NOT assign Pod IPs. |
| CNI Plugin | Assigns Pod IPs and handles Pod-to-Pod networking. |

---

## Common Interview Questions

**Q: What is the difference between Scheduler and Controller Manager?**
Scheduler assigns Pods to nodes (placement decision). Controller Manager enforces desired state (e.g., keeps 3 replicas running) by creating/deleting Pods via the API Server.

**Q: Why does Kubernetes use etcd instead of a regular database?**
etcd is a distributed, strongly consistent KV store built on Raft consensus. It guarantees that all control plane nodes see the same cluster state — critical for multi-master HA setups.

**Q: Can Pods communicate without kube-proxy?**
Yes, Pod-to-Pod communication uses the CNI plugin (direct IP routing). kube-proxy is only needed for *Service* abstraction (stable VIP → Pod load balancing).

**Q: What is the role of CNI vs kube-proxy?**
CNI assigns Pod IPs and enables Pod-to-Pod networking across nodes. kube-proxy routes Service traffic (ClusterIP/NodePort) to the correct Pod IPs using iptables/ipvs.

**Q: What happens to running Pods if the Control Plane goes down?**
Existing Pods keep running — they're managed by the container runtime on the worker node. But no new scheduling, scaling, or healing can happen until the Control Plane recovers.
