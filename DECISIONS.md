# Architecture Decisions

## ADR-001: Terraform over eksctl for EKS Cluster Provisioning

**Status:** Accepted

**Date:** 2026-05-13

### Context

Standing up an EKS cluster requires tooling choices. The two most common options are:

- **eksctl** — a purpose-built CLI from Weaveworks/AWS that abstracts EKS cluster creation behind opinionated defaults.
- **Terraform** — a general-purpose IaC tool that manages AWS resources declaratively via provider APIs.

### Decision

Terraform is used to provision and manage the entire infrastructure stack.

### Rationale

eksctl is a convenience tool. It handles the cluster creation, but stops there. Terraform on the other hand covers the supporting infrastructure as well: VPCs, subnets, route tables, NAT gateways, IAM roles and policies, security groups, and KMS keys. They are all expressed as first-class resources with explicit dependencies. This means:

- **Reproducibility** — `terraform apply` from a clean account produces the exact same environment every time, with no implicit defaults hiding resource configuration.
- **Full-stack visibility** — every AWS resource created for this project is declared in source and tracked in state. Nothing exists outside the plan.
- **Realistic scope** — production EKS platforms are not clusters in isolation. Treating the VPC, IAM, and cluster as a single IaC unit reflects how infrastructure is actually managed at scale.
- **Reproducible teardown** — `terraform destroy` removes all resources in dependency order, leaving the AWS account in a clean state.

### Consequences

- Higher initial setup cost: VPC, subnet, IAM, and EKS resources must all be written explicitly rather than generated.
- Full auditability: every resource is visible in `terraform plan` output and tracked in state — no hidden defaults.

## ADR-002: Hybrid Ingress + Gateway API on a Single AWS Load Balancer Controller

**Status:** Accepted

**Date:** 2026-08-27

### Context

Kubernetes offers two APIs for routing external HTTP(S) traffic into a cluster:

- **Ingress** — the original API. A single resource combines listener, hostname, and routing configuration, with advanced behaviour expressed through controller-specific annotations.
- **Gateway API** — the successor to Ingress (v1.0 GA in October 2023). It splits responsibilities across role-oriented resources: `GatewayClass` (infrastructure provider), `Gateway` (cluster operator), and `HTTPRoute` (application developer).

The AWS Load Balancer Controller, already installed for ALB provisioning, added GA support for Gateway API in March 2026 (v2.14.0+). It can serve both APIs side by side in the same cluster, so adopting Gateway API does not require a second controller.

However, third-party Helm charts in the stack lag behind. `kube-prometheus-stack` templates an Ingress for Grafana out of the box, but has no equivalent built-in support for `HTTPRoute`.

### Decision

Run both APIs on the one AWS Load Balancer Controller:

- **DevPulse and the golden-path Helm chart** use `Gateway` + `HTTPRoute`.
- **Grafana** stays on the chart's built-in Ingress.
- **Gateway API CRDs and the `aws-alb` GatewayClass** are installed by Terraform, alongside the controller's `helm_release`. `Gateway` and `HTTPRoute` instances ship with each app's Helm chart.

### Rationale

- **The API matches the platform model** — Gateway API's role split mirrors the platform story this project demonstrates: the platform team owns the `GatewayClass` and `Gateway`, and application teams own their `HTTPRoute`s. Ingress merges both concerns into one annotated object.
- **Low cost to adopt** — the controller was already installed. The change is limited to the resource types emitted by a chart this project owns, plus an extra external-dns source.
- **Pragmatic about ecosystem gaps** — keeping Grafana on Ingress avoids hand-maintaining a standalone `HTTPRoute` manifest outside the upstream chart. Third-party components follow whatever their charts support well today.
- **Tooling follows ownership and cadence** — CRDs and the GatewayClass are cluster-scoped, change rarely, and belong to the infrastructure team in Gateway API's role model, so they sit with the cluster lifecycle in Terraform. Gateways and HTTPRoutes change with every app deploy, so they ride with the app's Helm chart.

### Consequences

- Two routing APIs to understand and operate. Engineers need to know which one a given service uses, and why.
- external-dns must watch both sources (`--source=ingress --source=gateway-httproute`), and DNS behaviour should be verified for each.
- Terraform takes on extra ordering: Gateway API CRDs → Load Balancer Controller → GatewayClass.
- On both paths, TLS terminates at the ALB using ACM certificates. Kubernetes TLS Secrets issued by cert-manager are not used by the ALB.
- Follow-up: migrate Grafana to Gateway API once `kube-prometheus-stack` supports `HTTPRoute` cleanly.
