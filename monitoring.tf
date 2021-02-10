resource "helm_release" "prometheus" {
  depends_on = [google_container_node_pool.mycluster]
  name       = "prometheus"

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  
  values = [
    file("./helm/prometheus-values.yaml")
  ]
}

resource "helm_release" "promtail" {
  depends_on = [google_container_node_pool.mycluster]
  name       = "promtail"

  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  
  values = [
    file("./helm/promtail-values.yaml")
  ]
}

resource "helm_release" "loki" {
  depends_on = [google_container_node_pool.mycluster]
  name       = "loki"

  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
}

resource "helm_release" "grafana" {
  depends_on = [google_container_node_pool.mycluster]
  name       = "grafana"

  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  
  values = [
    file("./helm/grafana-values.yaml")
  ]
}

resource "kubernetes_service" "grafana" {
  metadata {
    name = "grafana-ingress"
  }
  spec {
    selector = {
      "app.kubernetes.io/instance" = "grafana"
      "app.kubernetes.io/name" = "grafana"
    }
    
    port {
      port        = 80
      target_port = 3000
    }

    type = "LoadBalancer"
  }
}

resource "kubectl_manifest" "prometheus-config" {
  depends_on = [helm_release.prometheus]
  provider = kubectl
  yaml_body = file("./config/prometheus.yaml")
}
