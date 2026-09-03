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

provider "kubectl" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}

# ── 1. Gateway API CRDs (upstream release manifest, multi-doc) ──
data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml"
}

data "kubectl_file_documents" "gateway_api_crds" {
  content = data.http.gateway_api_crds.response_body
}

resource "kubectl_manifest" "gateway_api_crds" {
  for_each          = data.kubectl_file_documents.gateway_api_crds.manifests
  yaml_body         = each.value
  server_side_apply = true
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
    kubectl_manifest.gateway_api_crds,
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

  set {
    name  = "controllerConfig.featureGates.ALBGatewayAPI"
    value = "true"
  }
}

# GatewayClass for ALB
resource "kubectl_manifest" "alb_gateway_class" {
  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1
    kind: GatewayClass
    metadata:
      name: aws-alb
    spec:
      controllerName: gateway.k8s.aws/alb
  YAML

  depends_on = [
    kubectl_manifest.gateway_api_crds, # kind must exist
    helm_release.aws_load_balancer_controller, # controller must be up to accept it
  ]
}
