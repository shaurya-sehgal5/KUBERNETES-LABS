<div align="center">

<img src="https://img.shields.io/badge/K8s%20Lab-04-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white"/>
<img src="https://img.shields.io/badge/Prometheus-Monitoring-E6522C?style=for-the-badge&logo=prometheus&logoColor=white"/>
<img src="https://img.shields.io/badge/Grafana-Dashboards-F46800?style=for-the-badge&logo=grafana&logoColor=white"/>
<img src="https://img.shields.io/badge/Helm-Deployed-0F1689?style=for-the-badge&logo=helm&logoColor=white"/>
<img src="https://img.shields.io/badge/Status-Complete-28a745?style=for-the-badge"/>

# ☸️ K8s Lab 04 — Prometheus & Grafana Monitoring

### Deploy the full Kubernetes observability stack with one Helm command. Metrics, dashboards, and alerts — all wired automatically.

</div>

---

## 🎯 Objective

Deploy **Prometheus** and **Grafana** on a Kubernetes cluster using Helm, expose them locally via port forwarding, and visualize real cluster metrics through a pre-built Grafana dashboard.

The goal isn't just getting dashboards running — it's understanding **how the monitoring stack is wired together** and what each component actually does.

---

## 🔑 Core Concept — The Observability Stack

```
Kubernetes Cluster
        │
        │  exposes metrics endpoints (/metrics)
        ▼
┌───────────────────────────────────────────────────────────┐
│                       Prometheus                          │
│                                                           │
│  scrapes /metrics from:                                   │
│    → kube-state-metrics  (deployment, pod, node state)   │
│    → node-exporter        (CPU, memory, disk, network)   │
│    → kubelet              (container resource usage)      │
│    → alertmanager         (alert state)                  │
│                                                           │
│  stores data in: time-series database (TSDB)             │
│  query language: PromQL                                  │
└───────────────────────────────┬───────────────────────────┘
                                │  PromQL queries
                                ▼
                    ┌───────────────────────┐
                    │        Grafana         │
                    │                        │
                    │  data source: Prometheus│
                    │  visualizes: dashboards │
                    │  alerts: alert rules    │
                    └───────────────────────┘
                                │
                                ▼
                    📊 You see charts, graphs,
                       cluster health in browser
```

> **The relationship:** Prometheus is the database. Grafana is the UI. Grafana doesn't collect anything — it queries Prometheus and draws it. They're separate tools that work together.

---

## 🧰 Tools Used

| Tool | Purpose |
|------|---------|
| `Helm` | Package manager — installs the full monitoring stack in one command |
| `Prometheus` | Metrics collector and time-series database |
| `Grafana` | Visualization and dashboarding layer |
| `Alertmanager` | Handles alert routing (email, Slack, PagerDuty) |
| `kube-state-metrics` | Exposes K8s object state as metrics (pod status, replica count etc.) |
| `Node Exporter` | Exposes host-level metrics (CPU, RAM, disk, network) |
| `kubectl port-forward` | Tunnels cluster services to localhost |
| `Kind` | Local K8s cluster |

---

## 🚀 Implementation

### Step 1 — Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

**First `helm repo update` attempt failed:**

```
Error: no repositories found. You must add one before updating.
```

> Helm ships with zero repositories by default. You must explicitly add a repo before installing any chart. This is the first thing to configure — and a common trip-up.

---

### Step 2 — Create Monitoring Namespace

```bash
kubectl create namespace monitoring
```

> **Why a dedicated namespace?** Keeps monitoring components isolated from application workloads. Easier to manage RBAC, resource quotas, and cleanup. Standard practice — monitoring infra should never share a namespace with the apps it monitors.

---

### Step 3 — Add Prometheus Helm Repository

```bash
# Add the official Prometheus community repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Pull latest chart index
helm repo update

# Optional: see what's available
helm search repo prometheus-community
```

---

### Step 4 — Install the Full Monitoring Stack

One Helm command installs everything:

```bash
helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set grafana.adminPassword=admin
```

This single command deploys:

| Component | What it Does |
|-----------|-------------|
| **Prometheus** | Scrapes and stores all cluster metrics |
| **Grafana** | Dashboard and visualization UI |
| **Alertmanager** | Routes alerts to notification channels |
| **kube-state-metrics** | Converts K8s object state into Prometheus metrics |
| **Node Exporter** | Exposes per-node OS-level metrics |
| **Prometheus Operator** | Manages Prometheus config via K8s CRDs |

```bash
# Verify everything is running
kubectl get pods -n monitoring
```

```
NAME                                                   READY   STATUS
alertmanager-monitoring-kube-prometheus-alertmanager   2/2     Running
monitoring-grafana-xxxxxxxxxx                          3/3     Running
monitoring-kube-prometheus-operator-xxxxxxxxxx         1/1     Running
monitoring-kube-state-metrics-xxxxxxxxxx               1/1     Running
monitoring-prometheus-node-exporter-xxxxx              1/1     Running
prometheus-monitoring-kube-prometheus-prometheus        2/2     Running
```

```bash
# See the services created
kubectl get svc -n monitoring
```

> **Add Screenshot:** All monitoring pods in Running state

---

### Step 5 — Access Prometheus

The cluster is running inside a Kind container on EC2 — services aren't directly accessible. Port forwarding tunnels them to localhost:

```bash
kubectl port-forward -n monitoring \
  svc/monitoring-kube-prometheus-prometheus \
  9090:9090 --address 0.0.0.0
```

On your **local machine**, set up SSH local port forwarding:

```bash
ssh -L 9090:localhost:9090 ubuntu@<EC2_PUBLIC_IP> -i your-key.pem
```

Prometheus now accessible at:
```
http://localhost:9090
```

**Try a PromQL query in the Prometheus UI:**

```promql
# CPU usage across all nodes
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Total running pods
count(kube_pod_status_phase{phase="Running"})

# Memory usage per pod
container_memory_usage_bytes{namespace="default"}
```

> **Add Screenshot:** Prometheus UI with a live PromQL query

---

### Step 6 — Access Grafana

```bash
kubectl port-forward -n monitoring \
  svc/monitoring-grafana \
  3000:80 --address 0.0.0.0
```

SSH tunnel on local machine:
```bash
ssh -L 3000:localhost:3000 ubuntu@<EC2_PUBLIC_IP> -i your-key.pem
```

Grafana accessible at:
```
http://localhost:3000
Username: admin
Password: admin   (set during helm install)
```

> **Add Screenshot:** Grafana login and home dashboard

---

### Step 7 — Import Kubernetes Dashboard

Instead of building dashboards from scratch, import a production-ready community dashboard:

```
Grafana → Dashboards → Import → Enter ID: 15757 → Load
Data source: Prometheus → Import
```

Dashboard ID `15757` — **Kubernetes Cluster Monitoring** — automatically visualizes:

| Panel | Metric Source |
|-------|--------------|
| Node CPU Usage | `node_cpu_seconds_total` via Node Exporter |
| Node Memory Usage | `node_memory_MemAvailable_bytes` |
| Pod Status | `kube_pod_status_phase` via kube-state-metrics |
| Cluster CPU Requests vs Limits | `kube_pod_container_resource_requests` |
| Network I/O | `node_network_receive_bytes_total` |
| Disk Usage | `node_filesystem_avail_bytes` |

> **Add Screenshot:** Dashboard 15757 showing live cluster metrics

---

## 🔍 How Prometheus Scraping Works

```
Every 15s (default scrape interval):

Prometheus ──GET──► node-exporter:9100/metrics
                              │
                    returns:  │
                    # HELP node_cpu_seconds_total
                    # TYPE node_cpu_seconds_total counter
                    node_cpu_seconds_total{cpu="0",mode="idle"} 12345.67
                    node_cpu_seconds_total{cpu="0",mode="user"} 234.56
                    ...

Prometheus stores each metric with:
  → metric name
  → labels (key=value pairs)
  → value
  → timestamp

Grafana queries this TSDB using PromQL:
  rate(node_cpu_seconds_total[5m])  →  per-second rate over 5min window
```

> **Why labels matter:** `node_cpu_seconds_total{cpu="0", mode="idle"}` and `node_cpu_seconds_total{cpu="1", mode="user"}` are different time series. Labels are how Prometheus differentiates instances, pods, nodes, namespaces — everything.

---

## 📊 Monitoring Custom Applications (Production Pattern)

The kube-prometheus-stack monitors Kubernetes infrastructure. For your own apps:

**Step 1 — Expose `/metrics` from your app:**

```python
# Python example using prometheus_client
from prometheus_client import Counter, Histogram, start_http_server
import time

REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'Request latency')

@app.route('/')
def index():
    REQUEST_COUNT.labels(method='GET', endpoint='/').inc()
    # your app logic
    return "ok"

start_http_server(8000)  # /metrics endpoint on port 8000
```

**Step 2 — Create a ServiceMonitor (tells Prometheus to scrape your app):**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: my-app          # matches your app's Service label
  endpoints:
    - port: metrics        # the port name exposing /metrics
      interval: 30s
```

**Step 3 — Prometheus auto-discovers and starts scraping. Build a Grafana dashboard.**

> **The SRE golden signals to monitor:** Latency (how long requests take), Traffic (requests/sec), Errors (error rate), Saturation (how full the system is). Start with these four.

---

## 📁 Repository Structure

```
04-PROMETHEUS-GRAFANA/
│
├── README.md           ← this file
├── commands.sh         ← all commands used
└── screenshots/
    ├── monitoring-pods-running.png
    ├── prometheus-ui.png
    ├── prometheus-query.png
    ├── grafana-login.png
    └── grafana-dashboard-15757.png
```

---

## 📚 Key Learnings

**Helm:**
- Helm requires repos to be explicitly added — no built-in registry like `apt` or `pip`
- `kube-prometheus-stack` is the standard chart — it deploys 6 components in one install
- Helm manages the entire lifecycle: install, upgrade, rollback, uninstall

**Prometheus:**
- Prometheus pulls metrics (scrapes) — apps don't push to Prometheus, Prometheus fetches from them
- Data is stored as time-series: `metric_name{labels} value timestamp`
- PromQL is the query language — `rate()`, `avg()`, `sum()` are the most-used functions
- Default scrape interval is 15s — configurable per target

**Grafana:**
- Grafana has zero data of its own — it's purely a visualization layer over data sources
- Dashboard ID `15757` is a community dashboard — thousands available at grafana.com/dashboards
- In production, dashboards are stored as JSON and version-controlled in Git

**Port forwarding:**
- `kubectl port-forward` is for development/debugging only — not a production access method
- Production access: Ingress + TLS, or a LoadBalancer service, or a VPN
- `--address 0.0.0.0` is needed when the cluster is on a remote machine (EC2) — binds to all interfaces so SSH tunnel can reach it

---

## ✅ Lab Completion Checklist

| Objective | Status |
|-----------|--------|
| Helm installed and verified | ✅ |
| Monitoring namespace created | ✅ |
| Prometheus community Helm repo added | ✅ |
| `kube-prometheus-stack` installed — all pods Running | ✅ |
| Prometheus UI accessible via port-forward | ✅ |
| PromQL queries executed in Prometheus UI | ✅ |
| Grafana UI accessible via port-forward | ✅ |
| Dashboard 15757 imported and showing live metrics | ✅ |
| Node CPU, memory, pod status panels verified | ✅ |
| Custom app monitoring pattern documented | ✅ |

---

<div align="center">

*You can't fix what you can't see. Observability isn't optional.*

</div>
