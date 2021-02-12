variable "discord_url" {}

resource "helm_release" "flagger" {
  depends_on = [google_container_node_pool.mycluster]
  name       = "flagger"

  repository = "https://flagger.app"
  chart      = "flagger"
  
  values = [
    file("./helm/flagger-values.yaml")
  ]
}

resource "kubectl_manifest" "flagger-crd-alert-provider" {
  depends_on = [google_container_node_pool.mycluster]
  provider = kubectl
  yaml_body = file("./flagger/flagger-crd-alert-provider.yaml")
}

resource "kubectl_manifest" "flagger-crd-canaries" {
  depends_on = [google_container_node_pool.mycluster]
  provider = kubectl
  yaml_body = file("./flagger/flagger-crd-canaries.yaml")
}

resource "kubectl_manifest" "flagger-crd-metric-template" {
  depends_on = [google_container_node_pool.mycluster]
  provider = kubectl
  yaml_body = file("./flagger/flagger-crd-metric-template.yaml")
}

resource "kubectl_manifest" "flagger-metrics" {
  depends_on = [google_container_node_pool.mycluster]
  provider = kubectl
  yaml_body = file("./flagger/flagger-metrics.yaml")
}

resource "kubectl_manifest" "flagger-alerts" {
  depends_on = [google_container_node_pool.mycluster]
  provider = kubectl
  yaml_body = file("./flagger/flagger-alerts.yaml")
}

resource "kubernetes_secret" "flagger-discord-webhook" {
  metadata {
    name = "flagger-on-call-url"
  }
  data = {
    "address" = var.discord_url
  }
}
