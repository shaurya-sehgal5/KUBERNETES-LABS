<div align="center">

<img src="https://img.shields.io/badge/K8s%20Lab-03-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white"/>
<img src="https://img.shields.io/badge/ConfigMaps-Configuration-0A66C2?style=for-the-badge&logo=kubernetes&logoColor=white"/>
<img src="https://img.shields.io/badge/Secrets-Secure%20Config-DC143C?style=for-the-badge&logo=kubernetes&logoColor=white"/>
<img src="https://img.shields.io/badge/Status-Complete-28a745?style=for-the-badge"/>

# ☸️ K8s Lab 03 — ConfigMaps & Secrets

### Stop hardcoding config. Two injection methods. One critical limitation. The right way to separate config from code in Kubernetes.

</div>

---

## 🎯 Objective

Understand how Kubernetes separates configuration from application code using **ConfigMaps** and **Secrets** — then discover *why* one injection method is better than the other by observing what happens when config changes at runtime.

This lab covers:
- Two ways to consume ConfigMaps (env vars vs volume mounts)
- Why env vars have a critical limitation that volume mounts don't
- How Secrets differ from ConfigMaps — and why Base64 ≠ encryption
- What real production secret management looks like

---

## 🔑 Core Concept — Why Config Must Be External

```
❌ The wrong way (hardcoded):

    Dockerfile:
    ENV DB_PORT=3306
    ENV DB_HOST=prod-db.internal

    Problems:
    → Different value for dev vs staging vs prod? Rebuild the image.
    → Credentials in the image? Security incident waiting to happen.
    → Config change requires a new deployment? Slow and risky.

✅ The Kubernetes way:

    Image contains: application code only
    ConfigMap contains: non-sensitive config (ports, URLs, flags)
    Secret contains: sensitive config (passwords, tokens, API keys)

    Change config → update ConfigMap/Secret → no image rebuild needed
```

> **Twelve-Factor App principle #3:** Store config in the environment, not in the code. ConfigMaps and Secrets are Kubernetes' implementation of this principle.

---

## 🏗️ Architecture

```
                     ┌─────────────────┐
                     │    ConfigMap     │
                     │  db-port: 3306  │
                     └────────┬────────┘
                              │
              ┌───────────────┴──────────────┐
              │                              │
              ▼                              ▼
   ┌──────────────────┐          ┌───────────────────────┐
   │ Method 1:        │          │ Method 2:             │
   │ Environment Var  │          │ Volume Mount          │
   │                  │          │                       │
   │ DB_PORT=3306     │          │ /opt/db-port → "3306" │
   │                  │          │                       │
   │ ⚠️ Static        │          │ ✅ Dynamic             │
   │ Set at pod start │          │ Updates without       │
   │ Needs restart    │          │ pod restart           │
   └────────┬─────────┘          └───────────┬───────────┘
            └──────────────┬─────────────────┘
                           ▼
                  ┌─────────────────┐
                  │  Python App Pod │
                  │  (reads config) │
                  └─────────────────┘

                     ┌─────────────────┐
                     │     Secret      │
                     │ db-port: MzMwNw  │  ← Base64 encoded
                     └─────────────────┘
                     (consumed same way — env var or volume)
```

---

## 🚀 Implementation

### Step 1 — Create a ConfigMap

```yaml
# cm.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-cm
data:
  db-port: "3306"        # non-sensitive config — safe in ConfigMap
```

```bash
kubectl apply -f cm.yml

# Verify the stored values
kubectl describe configmap test-cm
```

```
Name:         test-cm
Namespace:    default
Data
====
db-port:  4 bytes   → "3306"
```

> **Add Screenshot:** ConfigMap created and described

---

### Step 2 — Method 1: ConfigMap as Environment Variable

```yaml
# deployment.yml — env var injection
apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: python-app
  template:
    metadata:
      labels:
        app: python-app
    spec:
      containers:
        - name: python-app
          image: python:3.9
          command: ["sleep", "infinity"]
          env:
            - name: DB_PORT              # env var name inside container
              valueFrom:
                configMapKeyRef:
                  name: test-cm          # ConfigMap name
                  key: db-port           # key inside the ConfigMap
```

```bash
kubectl apply -f deployment.yml

# Exec into the running pod
kubectl exec -it <pod-name> -- /bin/bash

# Verify the env var was injected
env | grep DB
```

```
DB_PORT=3306   ✅
```

> **Add Screenshot:** env var confirmed inside pod

---

### Step 3 — The Critical Limitation of Env Vars

Now update the ConfigMap with a new value:

```bash
kubectl edit configmap test-cm
# change db-port from "3306" to "5432"

# Verify ConfigMap updated
kubectl describe configmap test-cm
# db-port: 5432  ✅ updated
```

Now check the running pod:

```bash
kubectl exec -it <pod-name> -- /bin/bash
env | grep DB
```

```
DB_PORT=3306   ❌ still the old value
```

**The pod is reading stale config.** The ConfigMap updated — but the pod didn't notice. This is not a bug, it's by design:

```
How env vars work in Linux:
  → Process starts
  → OS copies env vars into process memory at start time
  → The process owns its own copy — changes to the source don't propagate
  → The running container is just a Linux process

Result: ConfigMap env vars are a snapshot taken at pod creation.
        Updating the ConfigMap does nothing until the pod restarts.
```

**Fix for env var method:**
```bash
# Force pod restart by rolling the deployment
kubectl rollout restart deployment python-app
```

> **This is the exact kind of production gotcha** that causes incidents — config updated, pod not restarted, app behaves unexpectedly. Volume mounts solve this.

---

### Step 4 — Method 2: ConfigMap as Volume Mount

Modified the Deployment to mount the ConfigMap as a file instead:

```yaml
# deployment.yml — volume mount injection
apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: python-app
  template:
    metadata:
      labels:
        app: python-app
    spec:
      containers:
        - name: python-app
          image: python:3.9
          command: ["sleep", "infinity"]
          volumeMounts:
            - name: config-volume
              mountPath: /opt           # ConfigMap keys become files here
      volumes:
        - name: config-volume
          configMap:
            name: test-cm
```

```bash
kubectl apply -f deployment.yml

# Verify the mounted file
kubectl exec -it <pod-name> -- cat /opt/db-port
```

```
3306
```

Now update the ConfigMap again:

```bash
kubectl edit configmap test-cm
# change db-port to "5432"

# Wait ~30 seconds (kubelet sync interval), then check
kubectl exec -it <pod-name> -- cat /opt/db-port
```

```
5432   ✅ updated automatically — no pod restart needed
```

> **Add Screenshot:** ConfigMap volume mount — value updated without pod restart

**How volume mounts work:**
```
kubelet runs on every node
    │
    │ every ~30s (configurable)
    ▼
syncs ConfigMap data to mounted files on disk
    │
    ▼
application reads the file at runtime
    │
    ▼
config change propagates automatically
```

---

### Step 5 — Create a Kubernetes Secret

Sensitive values (passwords, tokens, API keys) go in Secrets — never ConfigMaps:

```bash
# Imperative creation — fastest for single values
kubectl create secret generic test-secret \
  --from-literal=db-port="3307"

# Verify — notice Kubernetes hides the actual value
kubectl describe secret test-secret
```

```
Name:         test-secret
Namespace:    default

Type:  Opaque

Data
====
db-port:  4 bytes       ← value hidden, only size shown
```

> Kubernetes hides Secret values from `describe` output — prevents accidental exposure in terminal logs and CI/CD output.

---

### Step 6 — Understanding Secret Storage (Base64 ≠ Encryption)

```bash
# View the raw Secret object
kubectl edit secret test-secret
```

```yaml
data:
  db-port: MzMwNw==    ← looks encoded, not readable
```

```bash
# Decode it — trivially easy
echo "MzMwNw==" | base64 --decode
# 3307
```

**Base64 is encoding, not encryption. Anyone with `kubectl get secret` access can read every secret.**

```
What Base64 actually does:
  → Converts binary data to printable ASCII characters
  → Purely a format transformation — no key, no cipher
  → Reversible by anyone with the encoded string
  → Purpose: safe transport/storage of binary data — NOT security

Misconception: "Secrets are encrypted in Kubernetes"
Reality: By default, Secrets are stored in etcd as Base64
         Encryption at rest requires explicit configuration (EncryptionConfig)
```

---

## 🔐 Production Secret Management

Kubernetes Secrets alone are not sufficient for production. Real environments use:

| Solution | How It Integrates |
|----------|------------------|
| **AWS Secrets Manager** | External Secrets Operator syncs to K8s Secrets |
| **HashiCorp Vault** | Vault Agent Injector sidecars or CSI driver |
| **Azure Key Vault** | Azure Key Vault Provider for Secrets Store CSI |
| **GCP Secret Manager** | External Secrets Operator or Workload Identity |

**The pattern:**
```
Vault / AWS Secrets Manager   ← actual encrypted secret storage
              │
              │  sync via operator
              ▼
    Kubernetes Secret          ← app reads from here (standard K8s API)
              │
              ▼
           Pod
```

> Your app code doesn't change — it still reads a K8s Secret. The operator handles syncing from the real secret store. **The Kubernetes Secret becomes a cache, not the source of truth.**

---

## 📊 ConfigMap vs Secret — Decision Table

| | ConfigMap | Secret |
|-|-----------|--------|
| **Use for** | DB ports, URLs, feature flags, app config | Passwords, API keys, tokens, TLS certs |
| **Storage** | Plain text in etcd | Base64 encoded in etcd |
| **Encryption at rest** | ❌ | ❌ (by default — needs EncryptionConfig) |
| **`kubectl describe` output** | Shows values | Hides values, shows byte count |
| **RBAC recommendation** | Read access fine for most pods | Restrict with RBAC — least privilege |
| **Production storage** | Fine in etcd | Use Vault / Secrets Manager |

---

## ⚡ Env Var vs Volume Mount — When to Use Which

| | Environment Variable | Volume Mount |
|-|---------------------|--------------|
| **Update without restart** | ❌ | ✅ (~30s propagation) |
| **Use for** | Static config that rarely changes | Config that may change at runtime |
| **App reads config via** | `os.environ['DB_PORT']` | `open('/opt/db-port').read()` |
| **Visible in** | `kubectl exec -- env` | `kubectl exec -- cat /opt/db-port` |
| **Good for** | Feature flags at boot, DB host | Dynamic config, rotating credentials |

> **Rule of thumb:** If the config could change while the app is running and you don't want to restart pods — use a volume mount. For everything else, env vars are simpler.

---

## 📁 Repository Structure

```
03-CONFIGMAPS-SECRETS/
│
├── README.md           ← this file
├── cm.yml              ← ConfigMap manifest
├── secret.yml          ← Secret manifest
├── deployment.yml      ← Deployment with both injection methods
├── commands.sh         ← all kubectl commands used
└── screenshots/
    ├── configmap-created.png
    ├── envvar-injected.png
    ├── envvar-stale-after-update.png
    ├── volume-mount-updated.png
    └── secret-created.png
```

---

## 📚 Key Learnings

**ConfigMaps:**
- ConfigMaps decouple config from images — one image, multiple environments (dev/staging/prod) with different ConfigMaps
- `configMapKeyRef` for env vars, `configMap` volume for file mounts — two different YAML structures
- Env vars are a snapshot at pod creation — volume mounts are a live sync

**Secrets:**
- Base64 is not encryption — anyone with `kubectl get secret -o yaml` can decode every value
- `kubectl describe secret` deliberately hides values — use `-o yaml` to see the encoded data
- Production secret management requires Vault, AWS Secrets Manager, or equivalent — not raw K8s Secrets alone

**The 12-Factor principle applied:**
- Config = anything that varies between deploys (dev/prod/staging)
- Code = everything that doesn't
- ConfigMaps + Secrets enforce this separation at the infrastructure level

---

## ✅ Lab Completion Checklist

| Objective | Status |
|-----------|--------|
| ConfigMap created with `db-port` value | ✅ |
| ConfigMap injected as environment variable | ✅ |
| Env var verified inside pod with `env \| grep DB` | ✅ |
| ConfigMap updated — env var confirmed stale (no restart = old value) | ✅ |
| Deployment updated to use volume mount instead | ✅ |
| ConfigMap updated — volume file confirmed auto-updated without restart | ✅ |
| Secret created with `kubectl create secret generic` | ✅ |
| Secret value confirmed hidden in `kubectl describe` output | ✅ |
| Base64 encoding demonstrated and decoded | ✅ |
| Production secret management patterns documented | ✅ |

---

<div align="center">

[← K8s Lab 02: Pods & Deployments](../02-PODS-DEPLOYMENTS/) | [Back to Lab Index](../README.md) | [K8s Lab 04: Services →](../04-SERVICES-DISCOVERY/)

*Config in code is a deployment problem. Config in a ConfigMap is a rollout.*

</div>
