# HELM SETUP ---------------------------------------------------------
# Setting up our helm resource with everything it needs to be able to talk to and be aware of our EKS cluster
# Basically like giving it hte Kube Config file locally


resource "helm_release" "monitoring_stack" {
  name             = "monitoring-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

}