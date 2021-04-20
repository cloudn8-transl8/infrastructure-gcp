data "kubernetes_secret" "grafana" {
  depends_on = [helm_release.grafana]

  metadata {
    name = "grafana"
  }
}

data "kubernetes_service" "ingress" {
  metadata {
    name = kubernetes_service.ingress.metadata[0].name
  }
}

data "kubernetes_service" "grafana" {
  metadata {
    name = kubernetes_service.grafana.metadata[0].name
  }
}

output "info" {

  value = <<EOF

  To configure kubectl you can run the following command:
 
  ./helper fetch_config

  To connect to services running in the cluster run the command:

  ./helper expose

  to use kubectl to forward ports.
EOF
}

output "project" {
  value = data.google_client_config.provider.project
}

output "location" {
  value = var.location
}

output "name" {
  value = var.name
}


output "grafana_username" {

  value = data.kubernetes_secret.grafana.data["admin-user"]

}

output "grafana_password" {

  value = data.kubernetes_secret.grafana.data["admin-password"]

}

output "ingress_ip" {

  value = data.kubernetes_service.ingress.status.0.load_balancer.0.ingress.0.ip

}

output "grafana" {

  value = data.kubernetes_service.grafana.status.0.load_balancer.0.ingress.0.ip

}
