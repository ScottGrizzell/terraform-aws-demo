output "cluster_ca" {
    value = aws_eks_cluster.training_cluster.certificate_authority

}

output "cluster_endpoint" {
    value = aws_eks_cluster.training_cluster.endpoint
}

output "cluster_name" {
    value = aws_eks_cluster.training_cluster.name
}