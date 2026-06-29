#!/bin/bash

# ==========================================
# Kubernetes Lab 05
# Troubleshooting & Scheduling
# ==========================================

# Verify Cluster

kubectl cluster-info

kubectl get nodes

#########################################################
# Scenario 1 - Invalid Image (ErrImagePull)
#########################################################

kubectl apply -f deployment.yml

kubectl get pods -w

kubectl describe pod <pod-name>

#########################################################
# Scenario 2 - Private Docker Image
#########################################################

kubectl create secret docker-registry dockerhub-secret \
--docker-server=https://index.docker.io/v1/ \
--docker-username=<USERNAME> \
--docker-password=<PASSWORD> \
--docker-email=<EMAIL>

kubectl apply -f deployment.yml

kubectl get pods

kubectl describe pod <pod-name>

#########################################################
# Scenario 3 - CrashLoopBackOff
#########################################################

kubectl get pods

kubectl logs <pod-name>

kubectl describe pod <pod-name>

#########################################################
# Scenario 4 - OOMKilled
#########################################################

kubectl apply -f deployment.yml

kubectl get pods

kubectl describe pod <pod-name>

#########################################################
# Increase EC2 Root Volume
#########################################################

sudo apt update

sudo apt install cloud-guest-utils -y

sudo growpart /dev/nvme0n1 4

sudo resize2fs /dev/nvme0n1p4

df -h

#########################################################
# Create Multi Node Cluster
#########################################################

kind create cluster \
--name demo \
--config kind-config.yaml

kubectl get nodes

#########################################################
# Node Labels
#########################################################

kubectl get nodes --show-labels

kubectl label node demo-worker node-name=arm-worker

kubectl get nodes --show-labels

#########################################################
# Node Selector
#########################################################

kubectl apply -f deployment.yml

kubectl get pods

kubectl describe pod <pod-name>

#########################################################
# Node Affinity
#########################################################

kubectl apply -f deployment.yml

kubectl get pods

kubectl get pods -o wide

kubectl describe pod <pod-name>

#########################################################
# Cleanup
#########################################################

kubectl delete deployment nginx-deployment

kind delete cluster --name demo
