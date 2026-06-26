# ☸️ Kubernetes Lab 02 — Services & Service Discovery

> **Goal:** Understand why Pod IPs are unreliable, how Kubernetes Services solve this, and how traffic is load balanced across Pods.

---

## Architecture

```
                        [ User / curl ]
                               │
                         port-forward
                               │
                    ┌──────────▼──────────┐
                    │  Kubernetes Service  │
                    │  (ClusterIP / NP /   │
                    │   LoadBalancer)      │
                    │                     │
                    │  Selector:          │
                    │  app: python-app    │
                    └──────┬──────┬───────┘
                           │      │
               ┌───────────▼──┐ ┌─▼────────────┐
               │    Pod 1     │ │    Pod 2      │
               │  10.244.0.5  │ │  10.244.0.6  │
               │  :8000       │ │  :8000       │
               └──────────────┘ └──────────────┘
                        │              │
                   ┌────┴──────────────┘
                   ▼
             Deployment (replicas: 2)
             sample-python-app:v1
```

---

## The Problem — Why Pod IPs Are Unreliable

Every Pod gets its own IP. That IP dies with the Pod.

```bash
kubectl get pods -o wide

# NAME                     READY   STATUS    IP
# python-app-xxx-aaa       1/1     Running   10.244.0.5
# python-app-xxx-bbb       1/1     Running   10.244.0.6
```

Delete a Pod and watch what happens:

```bash
kubectl delete pod python-app-xxx-aaa

kubectl get pods -o wide
# New Pod spawns with a NEW IP — 10.244.0.7
# Your hardcoded connection to 10.244.0.5 is now dead
```

**The fix:** Never talk to Pod IPs directly. Talk to a **Service**.

---

## Technologies Used

| Tool | Role |
|---|---|
| Kubernetes (Kind) | Local cluster |
| Docker | Build & load container images |
| kubectl | Cluster management |
| Python | Sample web application |
| Kubeshark | Network traffic visualization |

---

## Lab Walkthrough

### Step 1 — Build & Load the Docker Image

```bash
# Build the app image
docker build -t sample-python-app:v1 .

# Kind runs K8s inside Docker — local images must be explicitly loaded
kind load docker-image sample-python-app:v1 --name demo
```

> **Why `kind load`?** Kind nodes are Docker containers. They don't have access to your host's Docker daemon. Without loading, `ImagePullBackOff` errors occur.

---

### Step 2 — Deploy the Application

`deployment.yml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-app-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sample-python-app
  template:
    metadata:
      labels:
        app: sample-python-app     # ← Service will use this label to find Pods
    spec:
      containers:
      - name: python-app
        image: sample-python-app:v1
        ports:
        - containerPort: 8000
```

```bash
kubectl apply -f deployment.yml

# Verify
kubectl get deployments
kubectl get pods
```

> *Screenshot: Both Pods in Running state*

---

### Step 3 — Create a Service

`service.yml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: sample-python-service
spec:
  type: NodePort
  selector:
    app: sample-python-app       # ← matches Pod labels — this is Service Discovery
  ports:
  - port: 80            # Service listens on 80
    targetPort: 8000    # forwards to container port 8000
    nodePort: 30080     # exposed on the Node (30000–32767 range)
```

```bash
kubectl apply -f service.yml

kubectl get svc
# NAME                    TYPE       CLUSTER-IP     PORT(S)
# sample-python-service   NodePort   10.96.45.100   80:30080/TCP
```

How the Service finds Pods:

```
Service selector: app=sample-python-app
                         │
          ┌──────────────┴──────────────┐
          ▼                             ▼
   Pod (app=sample-python-app)   Pod (app=sample-python-app)
   → Included in Endpoints        → Included in Endpoints
```

> *Screenshot: NodePort Service created and Endpoints populated*

---

### Step 4 — Access the Application

Kind doesn't expose NodePorts to your host by default, so use port-forward:

```bash
kubectl port-forward service/sample-python-service 8000:80
```

```
http://localhost:8000/demo/
```

> *Screenshot: Application responding in browser*

---

### Step 5 — Service Types Compared

```bash
# Switch service type live
kubectl edit svc sample-python-service
# change type: NodePort → type: LoadBalancer
```

```
Service Type    │ Use Case                         │ How it works
────────────────┼──────────────────────────────────┼──────────────────────────────────
ClusterIP       │ Internal Pod-to-Pod only          │ Virtual IP, only reachable inside cluster
NodePort        │ External access via Node IP       │ Opens port 30000-32767 on every node
LoadBalancer    │ Production external access        │ Provisions cloud LB (AWS ALB/NLB, GCP LB)
ExternalName    │ Route to external DNS             │ CNAME alias inside cluster
```

**Why LoadBalancer didn't work on Kind:**

```
kubectl get svc
# TYPE           EXTERNAL-IP
# LoadBalancer   <pending>    ← stuck here forever on Kind
```

Kind has no cloud integration. `LoadBalancer` type requires a **Cloud Controller Manager** (CCM) to provision a real LB. On AWS EKS, the CCM would call the AWS API and provision an ALB/NLB automatically.

---

### Step 6 — Verify Load Balancing with Kubeshark

```bash
# Install Kubeshark
sh <(curl -Ls https://kubeshark.co/install)

# Start capturing
kubeshark tap

# Generate traffic
for i in {1..20}; do curl http://localhost:8000/demo/; done
```

Kubeshark traffic output:

```
Request 1  ──► Pod 1 (10.244.0.5)
Request 2  ──► Pod 2 (10.244.0.6)
Request 3  ──► Pod 1 (10.244.0.5)
Request 4  ──► Pod 2 (10.244.0.6)
...
```

Traffic distributed roughly 50/50 — confirming kube-proxy is doing round-robin load balancing via iptables rules.

> *Screenshot: Kubeshark showing requests alternating between Pod 1 and Pod 2*

---

## How Service Discovery Actually Works (Under the Hood)

```
1. You create a Service with selector: app=python-app
           │
           ▼
2. Endpoint Controller (inside Controller Manager) watches for matching Pods
           │
           ▼
3. Endpoints object is created/updated with Pod IPs
   kubectl get endpoints sample-python-service
   # ENDPOINTS: 10.244.0.5:8000, 10.244.0.6:8000
           │
           ▼
4. kube-proxy on every node reads the Endpoints
   and programs iptables rules:
   ClusterIP:80 → DNAT → random Pod IP:8000
           │
           ▼
5. Pod dies → Endpoint Controller removes its IP from Endpoints
   → kube-proxy updates iptables → dead Pod gets no traffic
```

No manual intervention. Fully automatic.

---

## Common Debugging Commands

```bash
# Check if Service has Pods (Endpoints not empty = healthy)
kubectl get endpoints sample-python-service

# Describe Service — check selector matches
kubectl describe svc sample-python-service

# Check if label on Pod matches Service selector
kubectl get pods --show-labels

# Test Service from inside cluster
kubectl run test --image=busybox --rm -it -- wget -qO- http://sample-python-service/demo/

# Watch Pod IPs change on recreation
kubectl get pods -o wide -w
```

---

## Key Takeaways

| Concept | What to Remember |
|---|---|
| Pod IPs are ephemeral | Never hardcode Pod IPs — they change on every restart |
| Service = stable VIP | ClusterIP never changes for the lifetime of the Service |
| Label Selectors | How Services find Pods — no static IP mapping needed |
| Endpoints object | Auto-updated list of healthy Pod IPs behind a Service |
| kube-proxy | Programs iptables rules to route Service traffic to Pods |
| NodePort | Dev/testing access. Bad for production (exposes random port on every node) |
| LoadBalancer | Production. Needs cloud integration (CCM) to work |
| Kind limitation | No CCM → LoadBalancer stays `<pending>` |

---

## Repository Structure

```
02-SERVICES-DISCOVERY/
├── README.md
├── commands.sh           # All lab commands in order
├── Dockerfile            # Python app containerization
├── deployment.yml        # 2-replica Deployment
├── service.yml           # NodePort Service
└── screenshots/
    ├── 01-docker-build.png
    ├── 02-pods-running.png
    ├── 03-service-created.png
    ├── 04-app-browser.png
    └── 05-kubeshark-traffic.png
```
