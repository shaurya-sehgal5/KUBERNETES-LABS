#!/bin/bash

# ==========================================
# Kubernetes Lab 01
# Pods & Deployments
# ==========================================

# Install kubectl

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

chmod +x kubectl

sudo mv kubectl /usr/local/bin/

# Verify

kubectl version --client

# Install Kind

curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64

chmod +x kind

sudo mv kind /usr/local/bin/

# Verify

kind version

# Create Cluster

kind create cluster --name demo

# Verify Cluster

kubectl cluster-info

kubectl get nodes

# Create Pod

kubectl apply -f pod.yml

# Verify Pod

kubectl get pods

kubectl describe pod nginx-pod

# Delete Pod

kubectl delete pod nginx-pod

# Create Deployment

kubectl apply -f deployment.yml

# Verify Deployment

kubectl get deployment

kubectl get replicaset

kubectl get pods

# Watch Pods

kubectl get pods -w

# Delete One Pod

kubectl delete pod <POD_NAME>

# Observe Auto Healing

kubectl get pods

# Cleanup

kubectl delete deployment nginx-deployment
