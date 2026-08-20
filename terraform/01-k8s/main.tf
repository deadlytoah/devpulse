# ── Providers ────────────────────────────────────────────────────────────────

provider "aws" {
  region = var.region
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# ── Remote state from 00-eks ─────────────────────────────────────────────────
# VPC, EKS cluster, and IRSA roles are defined in ../00-eks.
# We read outputs instead of redefining them.

data "terraform_remote_state" "eks" {
  backend = "local"

  config = {
    path = "../00-eks/terraform.tfstate"
  }
}

# ── EKS cluster lookup (read-only, required for the Helm provider) ───────────

data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

# ── Kubernetes add-ons (via Helm) ────────────────────────────────────────────

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "3.4.0"

  depends_on = [
    data.aws_eks_cluster.this,
  ]

  set {
    name  = "clusterName"
    value = data.terraform_remote_state.eks.outputs.cluster_name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = data.terraform_remote_state.eks.outputs.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = data.terraform_remote_state.eks.outputs.alb_controller_iam_role_arn
  }
}
