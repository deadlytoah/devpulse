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
