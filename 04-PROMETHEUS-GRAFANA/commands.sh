#!/bin/bash
# ==========================================
# K8s Lab 04 — Prometheus & Grafana
# ==========================================

# ------------------------------------------
# 1. Verify Cluster
# ------------------------------------------
kubectl cluster-info
kubectl get nodes

# ------------------------------------------
# 2. Install Helm
# ------------------------------------------
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# ------------------------------------------
# 3. Create Monitoring Namespace
# ------------------------------------------
kubectl create namespace monitoring

# Note: always isolate monitoring from app workloads

# ------------------------------------------
# 4. Add Prometheus Helm Repo
# ------------------------------------------
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts

helm repo update

# ------------------------------------------
# 5. Install kube-prometheus-stack
# ------------------------------------------
# Installs: Prometheus + Grafana + Alertmanager
#           + kube-state-metrics + Node Exporter

helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring

# ------------------------------------------
# 6. Verify Installation
# ------------------------------------------
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# All pods should show READY and STATUS=Running
# Expected pods:
#   alertmanager-prometheus-kube-prometheus-alertmanager
#   prometheus-grafana
#   prometheus-kube-prometheus-operator
#   prometheus-kube-state-metrics
#   prometheus-prometheus-node-exporter
#   prometheus-prometheus-kube-prometheus-prometheus

# ------------------------------------------
# 7. Get Grafana Admin Password
# ------------------------------------------
kubectl get secret \
  -n monitoring \
  prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode

# Username: admin
# Password: <output from above command>

# ------------------------------------------
# 8. Port Forward — Prometheus
# ------------------------------------------
kubectl port-forward \
  -n monitoring \
  svc/prometheus-kube-prometheus-prometheus \
  9090:9090

# Access: http://localhost:9090

# ------------------------------------------
# 9. Port Forward — Grafana
# ------------------------------------------
kubectl port-forward \
  -n monitoring \
  svc/prometheus-grafana \
  3000:80

# Access: http://localhost:3000

# ------------------------------------------
# 10. SSH Tunnel (run from Windows machine)
# ------------------------------------------
# Required when cluster is on a remote EC2 instance
# Tunnels EC2 localhost ports to your local machine

ssh -i "C:\Users\shaur\Downloads\neww.pem" ^
  -L 9090:localhost:9090 ^
  -L 3000:localhost:3000 ^
  ubuntu@<EC2-PUBLIC-IP>

# After this — Prometheus and Grafana accessible on your local browser

# ------------------------------------------
# 11. Import Grafana Dashboard
# ------------------------------------------
# Grafana → Dashboards → Import → ID: 15757 → Load
# Data source: Prometheus → Import

# Dashboard 15757 shows:
#   → Node CPU & Memory usage
#   → Pod status across namespaces
#   → Cluster resource utilization
#   → Network I/O

# ------------------------------------------
# 12. Useful PromQL Queries (in Prometheus UI)
# ------------------------------------------
# CPU usage per node:
# 100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Total running pods:
# count(kube_pod_status_phase{phase="Running"})

# Memory usage per pod:
# container_memory_usage_bytes{namespace="default"}

# ------------------------------------------
# 13. Debug Commands
# ------------------------------------------
kubectl get all -n monitoring
kubectl describe pod <pod-name> -n monitoring
kubectl logs <pod-name> -n monitoring
kubectl get configmap -n monitoring
kubectl get secret -n monitoring

# ------------------------------------------
# 14. Cleanup
# ------------------------------------------
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring
