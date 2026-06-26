<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0a0a2e,50:1a1a4e,100:326CE5&height=160&section=header&text=KUBERNETES%20LABS&fontSize=48&fontColor=ffffff&animation=fadeIn&fontAlignY=40&desc=Production-style%20K8s%20from%20scratch%20%E2%80%94%20pods%20to%20EKS&descSize=16&descAlignY=62&descAlign=50" width="100%"/>

<img src="https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white"/>
<img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white"/>
<img src="https://img.shields.io/badge/Amazon%20EKS-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white"/>
<img src="https://img.shields.io/badge/Helm-0F1689?style=for-the-badge&logo=helm&logoColor=white"/>
<img src="https://img.shields.io/badge/Labs-15%20Total-28a745?style=for-the-badge"/>
<img src="https://img.shields.io/badge/Status-Active-brightgreen?style=for-the-badge"/>

</div>

---

## 📖 About

This repository documents my hands-on Kubernetes learning — from bare Pods on a local Kind cluster all the way to production EKS deployments on AWS.

Every lab is built, broken, debugged, and documented. No skipping steps, no hiding errors — the troubleshooting is the point.

Each lab contains architecture diagrams, full YAML manifests, every kubectl command used, real terminal output, and documented failures with root cause and fix.

---

## 🗂️ Lab Index

| # | Lab | Concepts | Status |
|:-:|-----|----------|:------:|
| 01 | **Pods & Deployments** | Pods, Deployments, ReplicaSets, Self-Healing | ✅ |
| 02 | **Services & Service Discovery** | ClusterIP, NodePort, LoadBalancer, DNS, Labels, Selectors | ✅ |
| 03 | **Ingress** | Ingress Controller, Path & Host Routing, TLS | 🚧 |
| 04 | **ConfigMaps & Secrets** | Env vars, Volume mounts, Secret encryption | 🚧 |
| 05 | **RBAC** | Roles, ClusterRoles, RoleBindings, ServiceAccounts | 🚧 |
| 06 | **Monitoring** | Prometheus, Grafana, Alerting, Dashboards | 🚧 |
| 07 | **StatefulSets** | Ordered pods, Stable network identity, Persistent storage | 🚧 |
| 08 | **Persistent Volumes** | PV, PVC, StorageClass, Dynamic provisioning | 🚧 |
| 09 | **Deployment Strategies** | Rolling updates, Blue-Green, Canary | 🚧 |
| 10 | **Troubleshooting** | CrashLoopBackOff, ImagePullBackOff, OOMKilled, Pending | 🚧 |
| 11 | **Scheduling** | NodeSelector, Affinity, Taints & Tolerations | 🚧 |
| 12 | **Network Policies** | Pod-to-pod security, Ingress/Egress rules | 🚧 |
| 13 | **Helm** | Charts, Values, Templates, Releases | 🚧 |
| 14 | **Amazon EKS** | Managed K8s on AWS, ALB Ingress, IAM OIDC | ✅ |
| 15 | **Production K8s Project** | Full end-to-end production deployment | 🚧 |

---

## 📂 Repository Structure

```
KUBERNETES-LABS/
│
├── 01-PODS-DEPLOYMENTS/
│   ├── README.md          ← architecture + implementation + troubleshooting
│   ├── pod.yml            ← standalone Pod manifest
│   ├── deployment.yml     ← Deployment with 3 replicas
│   ├── commands.sh        ← every kubectl command used
│   └── screenshots/
│
├── 02-SERVICES-DISCOVERY/
├── 03-INGRESS/
├── 04-CONFIGMAPS-SECRETS/
├── 05-RBAC/
├── 06-MONITORING/
├── 07-STATEFULSETS/
├── 08-PERSISTENT-VOLUMES/
├── 09-DEPLOYMENT-STRATEGIES/
├── 10-TROUBLESHOOTING/
├── 11-SCHEDULING/
├── 12-NETWORK-POLICIES/
├── 13-HELM/
├── 14-AMAZON-EKS/
└── 15-PRODUCTION-PROJECT/
```

---

## ☸️ Topics Covered

<table>
<tr>
<td valign="top" width="20%">

**Core**
- Pods
- ReplicaSets
- Deployments
- Labels & Selectors
- Namespaces

</td>
<td valign="top" width="20%">

**Networking**
- ClusterIP
- NodePort
- LoadBalancer
- Ingress
- Network Policies
- DNS / Service Discovery

</td>
<td valign="top" width="20%">

**Config & Storage**
- ConfigMaps
- Secrets
- Persistent Volumes
- PVCs
- StorageClass
- StatefulSets

</td>
<td valign="top" width="20%">

**Security & Access**
- RBAC
- ServiceAccounts
- Roles & Bindings
- Network Policies
- IAM OIDC (EKS)

</td>
<td valign="top" width="20%">

**Production**
- Helm
- EKS
- Prometheus
- Grafana
- Deployment Strategies
- Scheduling

</td>
</tr>
</table>

---

## 💻 Environment

| Component | Tool |
|-----------|------|
| Local Cluster | Kind (Kubernetes in Docker) |
| Cloud Cluster | Amazon EKS |
| K8s CLI | kubectl |
| Package Manager | Helm |
| Traffic Analyzer | Kubeshark |
| Container Runtime | Docker |
| OS | Ubuntu Linux |

---

## 📄 Documentation Standard

Every lab README follows the same structure — no half-finished notes:

| Section | What's Inside |
|---------|--------------|
| **Objective** | What this lab covers and the problem it solves |
| **Architecture** | Diagram showing how components connect |
| **Core Concept** | The mental model before any commands |
| **Implementation** | Step-by-step with full YAML and commands |
| **Troubleshooting** | Every error hit — root cause and fix |
| **Key Learnings** | What this lab reinforced or revealed |
| **Checklist** | Completion verification |

---

## 🎯 Lab Highlights

### Lab 01 — Pods & Deployments
The foundation. Proves why bare Pods aren't enough — manually deletes one, watches it stay dead — then introduces Deployments and ReplicaSet self-healing. New pod back up in < 5 seconds.

📁 [View Lab 01 →](./01-PODS-DEPLOYMENTS/)

---

### Lab 02 — Services & Service Discovery
How pods talk to each other and how external traffic reaches them. Three service types, one lab: ClusterIP (internal), NodePort (external via port), LoadBalancer (cloud-native). Plus Kubernetes DNS in action.

📁 [View Lab 02 →](./02-SERVICES-DISCOVERY/)

---

### Lab 14 — Amazon EKS + ALB Ingress Controller
The full production stack on AWS. IAM OIDC federation, Helm-installed LBC controller, Kubernetes Ingress auto-provisioning an AWS ALB. Everything wired through IaC — no console clicks.

📁 [View Lab 14 →](./14-AMAZON-EKS/)

---

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:326CE5,50:1a1a4e,100:0a0a2e&height=100&section=footer" width="100%"/>

*Deploy it. Break it. Debug it. Document it. Repeat.*

</div>
