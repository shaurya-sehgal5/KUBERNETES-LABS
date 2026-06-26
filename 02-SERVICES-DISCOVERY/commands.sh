#!/bin/bash

# ==========================================
# Kubernetes Lab 02
# Services & Service Discovery
# ==========================================

# Verify Cluster

kubectl cluster-info

kubectl get nodes

# Build Docker Image

docker build -t sample-python-app:v1 .

# Verify Docker Image

docker images

# Load Image into Kind Cluster

kind load docker-image sample-python-app:v1 --name demo

# Deploy Application

kubectl apply -f deployment.yml

# Verify Deployment

kubectl get deployment

kubectl get pods

kubectl get pods -o wide

# Create Service

kubectl apply -f service.yml

# Verify Service

kubectl get svc

kubectl describe svc sample-python-service

# Port Forward

kubectl port-forward service/sample-python-service 8000:80

# Access Application

# http://localhost:8000/demo/

# Edit Service

kubectl edit svc sample-python-service

# Watch Pods

kubectl get pods -w

# Test Load Balancing

curl http://localhost:8000/demo/

curl http://localhost:8000/demo/

curl http://localhost:8000/demo/

curl http://localhost:8000/demo/

curl http://localhost:8000/demo/

curl http://localhost:8000/demo/

# Install Kubeshark

curl -Lo kubeshark \
https://github.com/kubeshark/kubeshark/releases/latest/download/kubeshark_linux_amd64

chmod +x kubeshark

sudo mv kubeshark /usr/local/bin/

# Verify

kubeshark version

# Start Kubeshark

kubeshark tap

# Cleanup

kubectl delete deployment sample-python-app

kubectl delete service sample-python-service
