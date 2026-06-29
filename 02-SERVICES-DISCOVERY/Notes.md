# 🎯 K8s Lab 02 — Interview Notes
## Services & Service Discovery
---

### Q1. Why do we need Kubernetes Services?

Pods have dynamic IP addresses — every time a Pod is recreated (crash, update, scaling), it gets a new IP. If your app hardcodes Pod IPs, it breaks every time a pod restarts.

A Service gives you a **stable, permanent endpoint** that never changes, regardless of how many times the pods behind it are recreated.

```
Without Service:          With Service:
App → 10.0.0.5 (dead)     App → my-service (always works)
                                    │
                          Service selects pods by label → routes traffic
```

---

### Q2. What is Service Discovery in Kubernetes?

Service Discovery lets applications find each other using **DNS names** instead of IPs.

Kubernetes runs an internal DNS server (CoreDNS). Every Service gets a DNS entry automatically:

```
<service-name>.<namespace>.svc.cluster.local
```

Example — backend pod connecting to a database service:
```python
# Instead of:  db_host = "10.0.0.42"  ← breaks when pod restarts
# Use:         db_host = "postgres-service"  ← always resolves correctly
```

CoreDNS resolves `postgres-service` to the Service's ClusterIP, which routes to healthy pods.

---

### Q3. How does a Service identify which Pods to route traffic to?

Through **Labels and Selectors**:

```yaml
# Pod has this label:
metadata:
  labels:
    app: nginx

# Service selects pods with matching label:
spec:
  selector:
    app: nginx     ← routes traffic to all pods with app=nginx
```

The Service continuously watches for pods matching its selector. When pods are added or removed, the Service's endpoint list updates automatically — no manual configuration needed.

---

### Q4. What are Labels and Selectors?

**Labels** are key-value pairs attached to any Kubernetes resource:
```yaml
labels:
  app: nginx
  env: production
  version: v2
```

**Selectors** query resources by their labels:
```yaml
selector:
  app: nginx    # match all resources where app=nginx
```

Labels are the core identity mechanism in Kubernetes — Services find pods, ReplicaSets own pods, and NetworkPolicies target pods all through labels.

---

### Q5. What are the types of Kubernetes Services?

| Type | Access Scope | Use Case |
|------|-------------|----------|
| **ClusterIP** | Internal only (default) | Pod-to-pod communication within the cluster |
| **NodePort** | External via node IP + port | Dev/testing, non-cloud environments |
| **LoadBalancer** | External via cloud LB | Production on AWS/GCP/Azure |
| **ExternalName** | DNS alias to external service | Connecting to external databases or APIs |

---

### Q6. What is ClusterIP and when do you use it?

ClusterIP is the default Service type. It creates a stable internal IP reachable only within the cluster.

```yaml
spec:
  type: ClusterIP       # default — can omit this line
  selector:
    app: nginx
  ports:
    - port: 80          # port the Service listens on
      targetPort: 8080  # port the container listens on
```

**Use when:** Services that should only be reachable internally — databases, internal APIs, cache layers. If it shouldn't be on the internet, ClusterIP is the right choice.

---

### Q7. What is NodePort and when do you use it?

NodePort exposes the Service on a static port on every node in the cluster. External traffic can reach it via `<any-node-IP>:<nodePort>`.

```yaml
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - port: 80           # ClusterIP port (internal)
      targetPort: 8080   # container port
      nodePort: 30080    # external port (30000-32767 range)
```

Access: `http://<node-ip>:30080`

**Use when:** Local clusters (Kind, bare metal), development/testing, situations where a cloud load balancer isn't available.

**Why not in production:** NodePort ties you to a specific node IP — if that node goes down, the access point changes. No health checking at the LB level.

---

### Q8. What is LoadBalancer and when do you use it?

LoadBalancer extends NodePort by automatically provisioning a cloud load balancer (AWS ALB, GCP LB, Azure LB) in front of the NodePorts.

```yaml
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 8080
```

The cloud provider assigns an external IP/DNS automatically. Traffic flows:
```
Internet → Cloud LB → NodePort → Service → Pod
```

**Use when:** Production workloads on managed cloud Kubernetes (EKS, GKE, AKS).

---

### Q9. Why didn't LoadBalancer work on Kind?

Kind runs locally with no cloud provider integration. When Kubernetes requests a cloud LB, there's no AWS/GCP/Azure to respond — so the Service stays in `<pending>` state for the external IP forever.

**Fix for local environments:**
- Use `NodePort` for direct access
- Use `kubectl port-forward` for quick testing
- Install MetalLB (bare-metal load balancer for local clusters)

---

### Q10. What is kubectl port-forward and when should you use it?

Port-forward creates a temporary tunnel from your local machine to a pod or service:

```bash
kubectl port-forward service/my-service 8000:80
# Local port 8000 → Service port 80 → Pod port
```

**Only for:** Development, debugging, quick testing.

**Not for production:**
- Single connection — not load balanced
- Drops when terminal closes
- No TLS, no auth
- Doesn't survive pod restarts

**Production alternatives:** Ingress + TLS, LoadBalancer Service, or internal VPN access.

---

### Q11. What is Kubeshark?

Kubeshark is a real-time Kubernetes traffic analyzer — like Wireshark but for pod-to-pod network traffic.

It captures and decodes traffic at the container network interface level, letting you inspect:
- HTTP requests and responses between services
- DNS queries (how pods resolve service names)
- TCP connections
- gRPC calls

**In this lab:** Used Kubeshark to visually confirm service discovery working — watched DNS resolution of service names in real-time, saw load balancing distributing requests across pods.

---

### Q12. How does Kubernetes load balance traffic across pods?

```
Request arrives at Service ClusterIP
        │
        ▼
kube-proxy (running on each node)
        │
        │  uses iptables rules (or IPVS)
        │  round-robin across healthy pod IPs
        ▼
Pod 1 / Pod 2 / Pod 3
```

**kube-proxy** maintains iptables rules that DNAT (destination NAT) incoming traffic to one of the healthy pod IPs. No external load balancer needed for internal traffic.

The Service's **Endpoints object** maintains the list of healthy pod IPs — updated automatically when pods are added, removed, or fail health checks.

---

### Q13. Why should applications never use Pod IPs directly?

Pod IPs are **ephemeral** — they change whenever a pod is:
- Restarted after a crash
- Rescheduled to a different node
- Replaced during a rolling update
- Scaled down and back up

Hardcoding a Pod IP = your app breaks on the next pod restart.

**Always use:** Service names (`postgres-service`) → resolved by CoreDNS → stable through any pod lifecycle change.

---

### Q14. What is the difference between port, targetPort, and nodePort?

```yaml
ports:
  - port: 80          # port the SERVICE listens on (other pods connect here)
    targetPort: 8080  # port the CONTAINER listens on (traffic forwarded here)
    nodePort: 30080   # port on the NODE (for NodePort type, external access)
```

Traffic flow:
```
External: <node-ip>:30080  →  Service:80  →  Container:8080
Internal: <service-name>:80  →  Container:8080
```

---

### Q15. What is the difference between ClusterIP, NodePort, and LoadBalancer?

```
ClusterIP:
  Internet ✗    →    cluster internal only
  Use: databases, internal APIs

NodePort:
  Internet → Node IP:30080 → Service → Pod
  Use: dev/testing, local clusters

LoadBalancer:
  Internet → Cloud LB (AWS/GCP) → NodePort → Service → Pod
  Use: production on cloud K8s
```

**Rule of thumb:**
- Internal services → ClusterIP
- Dev/local access → NodePort or port-forward
- Production external access → LoadBalancer or Ingress
