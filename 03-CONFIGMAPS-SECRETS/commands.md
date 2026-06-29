#!/bin/bash
# ==========================================
# K8s Lab 03 — ConfigMaps & Secrets
# ==========================================

# ------------------------------------------
# 1. Verify Cluster
# ------------------------------------------
kubectl cluster-info
kubectl get nodes

# ------------------------------------------
# 2. ConfigMap
# ------------------------------------------
kubectl apply -f cm.yml
kubectl get configmap
kubectl describe configmap test-cm

# ------------------------------------------
# 3. Deploy Application
# ------------------------------------------
kubectl apply -f deployment.yml
kubectl get deployments
kubectl get pods

# ------------------------------------------
# 4. Verify Env Var Inside Pod
# ------------------------------------------
kubectl exec -it <pod-name> -- /bin/bash
# Inside pod:
env | grep DB
# Expected: DB_PORT=3306

# ------------------------------------------
# 5. Update ConfigMap & Check Stale Env Var
# ------------------------------------------
vim cm.yml
kubectl apply -f cm.yml
kubectl describe configmap test-cm
# Exec back in — env var still shows old value (needs pod restart)
kubectl exec -it <pod-name> -- /bin/bash
env | grep DB

# ------------------------------------------
# 6. Verify Volume Mount (auto-updates)
# ------------------------------------------
kubectl exec -it <pod-name> -- /bin/bash
# Inside pod:
cat /opt/db-port
# After ConfigMap update, value refreshes here without restart

# ------------------------------------------
# 7. Secret
# ------------------------------------------
kubectl create secret generic test-secret \
  --from-literal=db-port="3307"

kubectl get secret
kubectl describe secret test-secret  # shows byte count, not value
kubectl edit secret test-secret      # shows Base64 encoded value

# Decode the Base64 value
echo "<base64-value>" | base64 --decode

# ------------------------------------------
# 8. Cleanup
# ------------------------------------------
kubectl delete deployment python-web-app
kubectl delete configmap test-cm
kubectl delete secret test-secret
