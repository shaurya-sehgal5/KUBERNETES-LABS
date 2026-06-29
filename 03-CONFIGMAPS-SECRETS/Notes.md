# 🎯 K8s Lab 03 — Interview Notes
## ConfigMaps & Secrets
---

### Q1. What is a ConfigMap?

A ConfigMap stores non-sensitive configuration data as key-value pairs, decoupled from the application container image.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  db-port: "3306"
  db-host: "postgres-service"
  log-level: "info"
```

**Why it exists:** Without ConfigMaps, config is baked into the Docker image. Change the DB port → rebuild the image → redeploy. With ConfigMaps, you update the ConfigMap — no image rebuild needed.

---

### Q2. Why use ConfigMaps instead of hardcoding values?

**12-Factor App principle #3:** Config that varies between environments (dev/staging/prod) must be external to the code.

```
❌ Hardcoded in image:
   ENV DB_PORT=3306
   → Different value for prod? Rebuild the image.
   → Credentials in image? Security risk.

✅ ConfigMap:
   → Same image, different ConfigMap per environment
   → Change config without touching the container
   → Config is version-controlled separately
```

One image + multiple ConfigMaps = portability across environments.

---

### Q3. How can ConfigMaps be consumed by Pods?

Two methods — each with different behavior:

**Method 1 — Environment Variable:**
```yaml
env:
  - name: DB_PORT
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: db-port
```

**Method 2 — Volume Mount:**
```yaml
volumeMounts:
  - name: config-vol
    mountPath: /opt
volumes:
  - name: config-vol
    configMap:
      name: app-config
```

ConfigMap keys become files in `/opt`. `db-port` key → `/opt/db-port` file containing the value.

---

### Q4. What is the limitation of injecting ConfigMaps as Environment Variables?

Environment variables are set **at container startup** and never updated while the container runs.

```
ConfigMap updated (db-port: 3306 → 5432)
        │
        ▼
Running pod still reads: DB_PORT=3306  ← old value
        │
        │  Why? Linux process memory owns its env vars.
        │  Changes to the source don't propagate to running processes.
        ▼
Pod must be restarted to pick up new value
```

```bash
# Force restart to pick up new ConfigMap value
kubectl rollout restart deployment <name>
```

> **Production risk:** This is a silent failure — ConfigMap updated, pod not restarted, app behaves on stale config. Teams have caused incidents this way.

---

### Q5. Why are Volume Mounts better for dynamic config?

Volume-mounted ConfigMaps update **automatically without pod restarts**.

```
ConfigMap updated
        │
        ▼
kubelet on each node syncs ConfigMap to mounted files (~30s)
        │
        ▼
/opt/db-port file now contains new value
        │
        ▼
Application reads file at runtime → gets new value ✅
```

No restart required. The kubelet's sync interval is configurable (default ~30 seconds).

**Rule:** If config can change while the app is running → volume mount. If it only changes at deploy time → env var is fine.

---

### Q6. What is a Kubernetes Secret?

A Secret stores sensitive data (passwords, API keys, tokens, TLS certificates) separately from the application, similar to ConfigMaps — but with additional access controls.

```bash
# Create imperatively
kubectl create secret generic db-secret \
  --from-literal=password="mysecretpassword"

# Create from file
kubectl create secret generic tls-secret \
  --from-file=tls.crt=./cert.pem \
  --from-file=tls.key=./key.pem
```

Secrets are consumed the same way as ConfigMaps — env vars or volume mounts.

---

### Q7. What is the difference between a ConfigMap and a Secret?

| | ConfigMap | Secret |
|-|-----------|--------|
| **Use for** | DB ports, URLs, feature flags | Passwords, API keys, tokens, TLS certs |
| **Storage** | Plain text in etcd | Base64 encoded in etcd |
| **`kubectl describe`** | Shows values | Hides values (shows byte count only) |
| **RBAC** | Read access fine for most pods | Restrict — least privilege |
| **Production storage** | Fine in etcd | Use Vault / Secrets Manager |

**Key rule:** If you'd be uncomfortable committing it to a public GitHub repo → it belongs in a Secret, not a ConfigMap.

---

### Q8. Are Kubernetes Secrets encrypted?

**By default: No.**

Secrets are stored as Base64-encoded strings in etcd — Base64 is encoding, not encryption. Anyone with `kubectl get secret -o yaml` access can decode every value in seconds:

```bash
echo "bXlzZWNyZXRwYXNzd29yZA==" | base64 --decode
# mysecretpassword
```

**To actually encrypt Secrets:**
- Enable **Encryption at Rest** (`EncryptionConfig` on the API server) — encrypts Secret data before writing to etcd
- Use an external secret manager (Vault, AWS Secrets Manager) — Kubernetes Secret becomes just a synced cache

---

### Q9. Is Base64 encryption?

No. Base64 is an **encoding** scheme, not encryption.

```
Encryption: requires a key to encode AND decode — without the key, data is unreadable
Encoding:   anyone can decode — it's just a format transformation for safe data transport
```

Base64 converts binary/arbitrary data to printable ASCII characters. Its purpose is safe storage/transport of binary data (like TLS certificates), not security.

Exit code for "I decoded your Kubernetes secret": `echo "dGVzdA==" | base64 --decode` → `test`. No key, no cipher, trivially reversible.

---

### Q10. How do companies manage Secrets securely in production?

Raw Kubernetes Secrets aren't sufficient. Real production patterns:

| Tool | Integration Pattern |
|------|-------------------|
| **AWS Secrets Manager** | External Secrets Operator syncs → K8s Secret |
| **HashiCorp Vault** | Vault Agent sidecar injects secrets at pod startup |
| **Azure Key Vault** | CSI Secrets Store driver mounts secrets as files |
| **GCP Secret Manager** | Workload Identity + External Secrets Operator |

**The pattern in all cases:**
```
Real secret store (Vault/AWS SM)   ← encrypted, audited, access-controlled
            │
            │  operator syncs periodically
            ▼
    Kubernetes Secret               ← temporary cache, app reads normally
            │
            ▼
          Pod
```

The app code doesn't change — it still reads a K8s Secret. The operator handles keeping it in sync with the real source of truth.

---

### Q11. Why shouldn't passwords be stored in ConfigMaps?

ConfigMaps are plain text in etcd with no access distinction — they're designed for non-sensitive config.

```
kubectl get configmap app-config -o yaml
# Every value visible immediately, no encoding, no RBAC distinction
```

If credentials end up in a ConfigMap:
- Any pod with access to the namespace can read them
- They appear in logs and `kubectl describe` output
- No audit trail for who accessed what value
- Violates security compliance requirements (SOC2, ISO27001, PCI-DSS)

---

### Q12. How do you create, inspect, and decode a Secret?

```bash
# Create
kubectl create secret generic test-secret \
  --from-literal=db-port="3307"

# List
kubectl get secret

# Inspect — note: values hidden, only byte count shown
kubectl describe secret test-secret

# View encoded value
kubectl get secret test-secret -o yaml
# db-port: MzMwNw==

# Decode
echo "MzMwNw==" | base64 --decode
# 3307
```

---

### Q13. When would you choose Volume Mount over Environment Variables?

| Scenario | Method |
|----------|--------|
| Config rarely changes (DB host, port) | Env var — simpler |
| Config changes at runtime without restart | Volume mount |
| TLS certificates (binary data) | Volume mount |
| Feature flags updated frequently | Volume mount |
| Rotating credentials (auto-synced from Vault) | Volume mount |

**The deciding question:** "If this value changes, can I restart the pod?" → No → Volume mount.

---

### Q14. What is the YAML structure difference between env var and volume ConfigMap injection?

```yaml
# Env var injection
spec:
  containers:
    - name: app
      env:
        - name: DB_PORT          # env var name in container
          valueFrom:
            configMapKeyRef:
              name: app-config   # ConfigMap name
              key: db-port       # key inside ConfigMap

# Volume mount injection
spec:
  containers:
    - name: app
      volumeMounts:
        - name: config-vol
          mountPath: /opt        # directory in container
  volumes:
    - name: config-vol
      configMap:
        name: app-config         # ConfigMap name
                                 # each key becomes a file in /opt/
```

---

### Q15. What are the four top-level fields every Kubernetes YAML must have?

```yaml
apiVersion: v1           # which K8s API handles this resource
kind: ConfigMap          # what type of resource
metadata:                # name, namespace, labels
  name: app-config
spec:                    # desired state (or data: for ConfigMap/Secret)
  ...
```

Every K8s object — Pod, Deployment, Service, ConfigMap, Secret, Ingress — follows this same structure. `apiVersion` and `kind` together tell the API server which controller handles the object.
