# 🧩 Platform Engineering Journey

> **Building a portable, secure and observable Kubernetes platform — on AWS and on a European cloud.**
> Phase 2 of my cloud engineering journey, after [`aws-cloud-engineering-journey`](https://github.com/AdoMarna/aws-cloud-engineering-journey) (IAM, VPC, EC2, ECS, Terraform, Serverless).

This repository documents, week by week, the construction of an **Internal Developer Platform**:
one reference application, deployed through GitOps onto multiple Kubernetes clusters, hardened,
observed, and cost-controlled — everything declarative, everything destroyable with one command.

---

## 🎯 Engineering Principles

* **Terminal-first & declarative:** every resource lives in YAML, HCL or Helm — no console clicks, no manual steps.
* **Portable by design:** Kubernetes is the abstraction layer. The same chart runs on **Amazon EKS** and on a **European managed Kubernetes** offer; every cloud-specific dependency is listed and isolated.
* **Security & sovereignty by default:** least-privilege RBAC, Pod Security Standards `restricted`, default-deny network policies, signed images, customer-managed encryption keys, policy-as-code.
* **Observable or it doesn't exist:** metrics, logs, traces and SLO-based alerting for every service.
* **FinOps:** local-first (kind/k3d); cloud clusters live for a work session, then `make clean`. Cost per hour is documented for every stack.
* **Proof over claims:** every module ships code, a green CI, a runbook or postmortem, and a write-up.

---

## 🏗️ Target Architecture

```text
   Developer push
        │
        ▼
 ┌──────────────────────────────┐        ┌──────────────────────────────┐
 │ GitHub Actions (CI)          │        │ GitOps repo                  │
 │ lint · test · build · SBOM   │──tag──►│ Helm values per env/cluster  │
 │ Trivy scan · Cosign sign     │  bump  └──────────────┬───────────────┘
 └──────────────┬───────────────┘                       │ sync
                │ push                                  ▼
                ▼                               ┌───────────────┐
        ┌───────────────┐                       │    ArgoCD     │
        │ Registry      │                       │ ApplicationSet│
        │ (GHCR / ECR)  │                       └───┬───────┬───┘
        └───────────────┘                           │       │
                              ┌─────────────────────┘       └─────────────────────┐
                              ▼                                                   ▼
               ┌──────────────────────────────┐                ┌──────────────────────────────┐
               │ Amazon EKS (Terraform)       │                │ EU managed Kubernetes        │
               │ Pod Identity · ALB · EBS CSI │                │ (OVHcloud / Scaleway)        │
               └──────────────┬───────────────┘                └──────────────┬───────────────┘
                              └───────────────┬───────────────────────────────┘
                                              ▼
              Common platform layer on every cluster:
              Kyverno · Cilium · External Secrets · Velero · Prometheus / Loki / Tempo / Grafana · OpenCost
```

### Reference application — `orders-platform`

```text
   Web front ──► Orders API (Node.js) ──► PostgreSQL
                       │
                       └──► Redis queue ──► Worker (Python) ──► LLM inference (Ollama)
```

A small but realistic microservice app, written once and enriched by every module
(manifests → Helm → GitOps → hardening → instrumentation → AI workload).

---

## 🛣️ Roadmap & Status

| Module | Focus | Key topics | Status |
| :--- | :--- | :--- | :---: |
| **A** | Kubernetes core & Linux | Control plane, workloads, Gateway API, storage, kubeadm upgrade, etcd backup/restore, namespaces/cgroups, pod networking, troubleshooting | 🟡 In progress |
| **B** | Helm, GitOps, EKS & portability | Helm charts, ArgoCD (multi-cluster ApplicationSet), EKS via Terraform/OpenTofu, OIDC CI, Pod Identity, same app on EKS **and** an EU cloud | ⏳ Planned |
| **C** | Security, sovereignty & resilience | External Secrets, RBAC, PSS, Cilium network policies, Kyverno, Cosign + SBOM, KMS customer-managed keys, data-residency policies, Velero cross-cluster DR | ⏳ Planned |
| **D** | Observability, FinOps, AI & IDP | Prometheus, Loki, Tempo, OpenTelemetry, SLOs & burn-rate alerts, OpenCost, Python cost-leak tool, LLM workload, Chaos Mesh, golden-path service template | ⏳ Planned |

### Definition of done (every module)

- [ ] Rebuilt and debugged from the CLI, without notes
- [ ] 100 % declarative, zero manual steps
- [ ] CI green
- [ ] README with diagram, deployment guide and estimated cost per hour
- [ ] `make clean` destroys everything (verified)
- [ ] At least one failure scenario documented (runbook or postmortem)
- [ ] Cloud-specific dependencies listed (what wouldn't be portable?)
- [ ] Public write-up

---

## 🛠️ Tech Stack

| Area | Tools |
| :--- | :--- |
| **Kubernetes** | kind, k3d, kubeadm, Amazon EKS, EU managed Kubernetes, Gateway API, Kustomize, Helm |
| **IaC & GitOps** | Terraform, OpenTofu, ArgoCD, GitHub Actions (OIDC to AWS) |
| **Security** | Kyverno, Cilium + Hubble, External Secrets Operator, Trivy, Syft, Cosign, gitleaks, KMS |
| **Resilience** | Velero, Chaos Mesh |
| **Observability** | Prometheus, Alertmanager, Grafana, Loki, Grafana Alloy, Tempo, OpenTelemetry |
| **FinOps** | OpenCost, AWS Cost Explorer, custom Python tooling (boto3) |
| **Languages** | Bash, Python, Node.js, HCL, YAML |

---

## 📂 Repository Layout (planned)

```text
.
├── apps/orders-platform/    # Reference application (front, API, worker) + Dockerfiles
├── charts/                  # Helm charts
├── gitops/                  # ArgoCD Applications / ApplicationSets, per-cluster values
├── infra/                   # Terraform / OpenTofu: EKS, EU cluster, OIDC, KMS
├── platform/                # Cluster add-ons: Kyverno, Cilium, ESO, Velero, observability
├── tools/                   # Python tooling (cost-leak hunter, reports)
├── labs/                    # Module A labs: kubeadm, Linux internals, troubleshooting scenarios
├── docs/                    # Runbooks, postmortems, write-ups, architecture decisions
└── .github/workflows/       # CI
```

---

## 🚀 Getting Started

Prerequisites (Linux / WSL2): `docker`, `kind`, `kubectl`, `helm`, `k9s`, `kustomize`, `terraform` or `tofu`, `make`.

Each module directory will ship its own `README.md` and `Makefile` with
`make up` / `make test` / `make clean` targets. Local clusters first, cloud only when a module needs it.

---

## 🔗 Related

* **Phase 1 —** [`aws-cloud-engineering-journey`](https://github.com/AdoMarna/aws-cloud-engineering-journey): AWS foundations built with AWS CLI + Bash and Terraform — IAM, multi-AZ VPC, hardened EC2 via SSM, ALB + ASG, ECS Fargate, modular Terraform, event-driven serverless, CI with ShellCheck / TFLint / Checkov / Trivy.
