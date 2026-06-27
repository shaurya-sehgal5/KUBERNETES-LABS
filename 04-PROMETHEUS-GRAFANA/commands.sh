#!/bin/bash

# ==========================================
# Kubernetes Lab 04
# Prometheus & Grafana Monitoring
# ==========================================

# Verify Cluster

kubectl cluster-info

kubectl get nodes

# ------------------------------------------
# Install Helm
# ------------------------------------------

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify Helm

helm version

# ------------------------------------------
# Create Monitoring Namespace
# ------------------------------------------

kubectl create namespace monitoring

# ------------------------------------------
# Add Prometheus Community Repository
# ------------------------------------------

helm repo add prometheus-community \
https://prometheus-community.github.io/helm-charts

helm repo update

# ------------------------------------------
# Install kube-prometheus-stack
# ------------------------------------------

helm install prometheus prometheus-community/kube-prometheus-stack \
-n monitoring

# ------------------------------------------
# Verify Installation
# ------------------------------------------

kubectl get pods -n monitoring

kubectl get svc -n monitoring

# ------------------------------------------
# Port Forward Prometheus
# ------------------------------------------

kubectl port-forward \
-n monitoring \
svc/prometheus-kube-prometheus-prometheus \
9090:9090

# Open Browser

http://localhost:9090

# ------------------------------------------
# Port Forward Grafana
# ------------------------------------------

kubectl port-forward \
-n monitoring \
svc/prometheus-grafana \
3000:80

# Open Browser

http://localhost:3000

# ------------------------------------------
# SSH Local Port Forwarding
# (Run from your Windows Machine)
# ------------------------------------------

ssh -i "C:\Users\shaur\Downloads\neww.pem" ^
-L 9090:localhost:9090 ^
-L 3000:localhost:3000 ^
ubuntu@<EC2-PUBLIC-IP>

# ------------------------------------------
# Grafana
# ------------------------------------------

# Login

Username: admin

Password:

kubectl get secret \
-n monitoring \
prometheus-grafana \
-o jsonpath="{.data.admin-password}" | base64 --decode

# ------------------------------------------
# Import Dashboard
# ------------------------------------------

Dashboard ID

15757

# ------------------------------------------
# Useful Commands
# ------------------------------------------

kubectl get all -n monitoring

kubectl describe pod <pod-name> -n monitoring

kubectl logs <pod-name> -n monitoring

kubectl get configmap -n monitoring

kubectl get secret -n monitoring

# ------------------------------------------
# Uninstall Stack
# ------------------------------------------

helm uninstall prometheus -n monitoring

kubectl delete namespace monitoring
