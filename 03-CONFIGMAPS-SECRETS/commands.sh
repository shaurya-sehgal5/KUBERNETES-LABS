#!/bin/bash

# ==========================================
# Kubernetes Lab 03
# ConfigMaps & Secrets
# ==========================================

# Verify Cluster

kubectl cluster-info

kubectl get nodes

# ------------------------------------------
# Create ConfigMap
# ------------------------------------------

kubectl apply -f cm.yml

# Verify ConfigMap

kubectl get configmap

kubectl describe configmap test-cm

# ------------------------------------------
# Deploy Application
# ------------------------------------------

kubectl apply -f deployment.yml

# Verify Deployment

kubectl get deployment

kubectl get pods

kubectl get pods -w

# ------------------------------------------
# Login to Pod
# ------------------------------------------

kubectl exec -it <pod-name> -- /bin/bash

# Verify Environment Variable

env | grep DB

# Expected Output:
# DB_PORT=3306

# ------------------------------------------
# Update ConfigMap
# ------------------------------------------

vim cm.yml

kubectl apply -f cm.yml

# Verify ConfigMap

kubectl describe configmap test-cm

# ------------------------------------------
# Verify Mounted Files
# ------------------------------------------

kubectl exec -it <pod-name> -- /bin/bash

cd /opt

ls

cat db-port

# ------------------------------------------
# Create Secret
# ------------------------------------------

kubectl create secret generic test-secret \
--from-literal=db-port="3307"

# Verify Secret

kubectl get secret

kubectl describe secret test-secret

kubectl edit secret test-secret

# Decode Secret

echo "<base64-value>" | base64 --decode

# ------------------------------------------
# Cleanup
# ------------------------------------------

kubectl delete deployment python-web-app

kubectl delete configmap test-cm

kubectl delete secret test-secret
