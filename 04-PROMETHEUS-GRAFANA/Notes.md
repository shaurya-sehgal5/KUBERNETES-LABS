# 🎯 K8s Lab 04 — Interview Notes
## Prometheus & Grafana Monitoring
---

### Q1. What is Prometheus and why do we use it?

Prometheus is an open-source monitoring and alerting tool that collects and stores metrics as time-series data.

In Kubernetes, it scrapes metrics from cluster components — nodes, pods, services — and stores them with timestamps and labels.

**Why it matters:** Without Prometheus, you're flying blind. You don't know if a node is overloaded, if pods are OOMKilled, or if your app's error rate is spiking — until users complain.

---

### Q2. What is Grafana and why do we need it if Prometheus already has a UI?

Grafana is a visualization platform that queries Prometheus using PromQL and renders the data as dashboards.

Prometheus has a basic built-in graph UI — but it's designed for ad-hoc queries, not monitoring. Grafana adds:
- Pre-built and custom dashboards
- Multi-data-source support (Prometheus, Loki, CloudWatch etc.)
- Alerting with notification channels (Slack, PagerDuty, email)
- Team-shareable, version-controllable dashboard JSON

**One line:** Prometheus stores the data. Grafana makes it readable.

---

### Q3. What is Helm?

Helm is the package manager for Kubernetes — like `apt` for Ubuntu or `pip` for Python, but for K8s applications.

Instead of applying 20+ individual YAML files manually, Helm packages them into a **Chart** and installs everything in one command:

```bash
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
```

Helm also handles upgrades, rollbacks, and uninstalls cleanly.

---

### Q4. What is a Helm Chart?

A Helm Chart is a collection of Kubernetes manifest templates packaged with:
- `Chart.yaml` — chart metadata (name, version, description)
- `values.yaml` — default configuration values (overridable at install time)
- `templates/` — the actual K8s YAML files, templatized with Go templating

When you run `helm install`, Helm renders the templates with your values and applies them to the cluster.

---

### Q5. What does `kube-prometheus-stack` install?

One chart, six components:

| Component | What It Does |
|-----------|-------------|
| Prometheus | Scrapes and stores all metrics |
| Grafana | Visualization and dashboarding |
| Alertmanager | Routes alerts to Slack, email, PagerDuty |
| kube-state-metrics | Converts K8s object state into metrics (pod status, replica counts) |
| Node Exporter | Exposes per-node OS metrics (CPU, RAM, disk, network) |
| Prometheus Operator | Manages Prometheus config via K8s CRDs |

---

### Q6. How does Prometheus collect metrics?

Prometheus uses a **pull model** — it scrapes `/metrics` endpoints from targets on a schedule (default: every 15 seconds).

```
Prometheus ──GET /metrics──► node-exporter:9100/metrics
                                      │
                           returns plain text:
                           node_cpu_seconds_total{cpu="0",mode="idle"} 12345.67
```

Targets are discovered via:
- Static config (hardcoded IPs/ports)
- Service discovery (Kubernetes SD — auto-discovers pods and services by labels)
- `ServiceMonitor` CRDs (Prometheus Operator pattern)

---

### Q7. Does Prometheus push or pull metrics?

**Pull.** Prometheus fetches metrics from targets — targets don't send metrics to Prometheus.

Exception: `Pushgateway` exists for short-lived jobs (cron jobs, batch scripts) that finish before Prometheus scrapes them. They push to the gateway, Prometheus pulls from the gateway.

---

### Q8. How do developers expose application metrics to Prometheus?

Three steps:

1. **Add a Prometheus client library** to the app (`prometheus_client` for Python, `prom-client` for Node.js, `micrometer` for Java)

2. **Instrument the code** — define and increment metrics:
```python
REQUEST_COUNT = Counter('http_requests_total', 'Total requests', ['method'])
REQUEST_COUNT.labels(method='GET').inc()
```

3. **Expose a `/metrics` endpoint** — the library handles the format automatically

4. **Create a `ServiceMonitor`** — tells Prometheus Operator to scrape this service

Prometheus auto-discovers and starts collecting. No Prometheus config file changes needed.

---

### Q9. Why create a separate monitoring namespace?

- **Isolation** — monitoring infra doesn't compete with app workloads for resources
- **RBAC** — easier to restrict who can access Prometheus/Grafana data
- **Resource quotas** — can set limits on the monitoring namespace independently
- **Clean separation** — `kubectl get pods -n monitoring` shows only monitoring, not mixed with app pods
- **Easier cleanup** — `kubectl delete namespace monitoring` removes everything in one command

**Standard practice:** monitoring, logging, and ingress controllers always get their own namespaces in production.

---

### Q10. What is PromQL and can you give examples?

PromQL (Prometheus Query Language) is used to query the Prometheus time-series database.

```promql
# CPU usage per node (%)
100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Total running pods in the cluster
count(kube_pod_status_phase{phase="Running"})

# HTTP error rate for an app
rate(http_requests_total{status=~"5.."}[5m])

# Memory usage per container
container_memory_usage_bytes{namespace="default"}
```

Key functions: `rate()` (per-second rate over time window), `avg()`, `sum()`, `count()`, `histogram_quantile()` (for percentiles like p99 latency).

---

### Q11. What are the SRE Golden Signals? How does this stack monitor them?

| Signal | What It Measures | Prometheus Metric |
|--------|-----------------|-------------------|
| **Latency** | How long requests take | `http_request_duration_seconds` |
| **Traffic** | How many requests/sec | `rate(http_requests_total[5m])` |
| **Errors** | Error rate | `rate(http_requests_total{status=~"5.."}[5m])` |
| **Saturation** | How full the system is | `node_cpu_seconds_total`, `container_memory_usage_bytes` |

These four signals give a complete picture of service health. If all four are normal — your service is healthy.

---

### Q12. What is port-forwarding and is it used in production?

`kubectl port-forward` tunnels a cluster service to your localhost:

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

**Not for production.** It's a debugging and development tool — single connection, no HA, drops when the terminal closes.

**Production alternatives:**
- Kubernetes `Ingress` with TLS (most common)
- `LoadBalancer` service type (cloud-managed)
- Internal access via VPN + ClusterIP

---

### Q13. What is Base64 and why does Kubernetes use it for Secrets?

Base64 is an encoding scheme that converts binary data to printable ASCII characters. It is **not encryption**.

Kubernetes stores Secret values as Base64 because:
- etcd (K8s data store) stores data as strings
- Base64 safely encodes any binary value (TLS certs, binary keys) into a string format

```bash
echo "MzMwNw==" | base64 --decode   # → 3307
```

**For real security in production:** Enable encryption at rest (`EncryptionConfig`), or use external secret managers like AWS Secrets Manager, HashiCorp Vault, or GCP Secret Manager.

---

### Q14. Where are Prometheus and Grafana used in the real world?

Standard observability stack in production Kubernetes environments across:
- **Startups to enterprise** — it's the default choice for K8s monitoring
- **Cloud-native companies** — Grafana Cloud, AWS Managed Prometheus, Google Cloud Managed Prometheus
- **DevOps/SRE teams** — for on-call dashboards, SLO tracking, incident response
- **Any team running microservices** — where you need per-service visibility

Alternatives you'll encounter: Datadog, New Relic, Dynatrace (commercial), Thanos (Prometheus at scale), VictoriaMetrics (Prometheus-compatible, more efficient).
