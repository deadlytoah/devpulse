output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = data.aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = data.terraform_remote_state.eks.outputs.cluster_name
}
