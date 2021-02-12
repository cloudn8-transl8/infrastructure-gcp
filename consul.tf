resource "helm_release" "certmanager" {
  depends_on = [google_container_node_pool.mycluster]
  name       = "certmanager"

  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  
  values = [
    file("./helm/cert-manager-values.yaml")
  ]
}

resource "helm_release" "consul" {
  depends_on = [google_container_node_pool.mycluster]
  name       = "consul"

  repository = "https://helm.releases.hashicorp.com"
  chart      = "consul"
  
  values = [
    file("./helm/consul-values.yaml")
  ]
}

resource "helm_release" "consul-smi" {
  depends_on = [helm_release.consul, helm_release.certmanager]
  name       = "consul-smi"

  repository = "https://nicholasjackson.io/smi-controller-sdk/"
  chart      = "smi-controller"
  
  values = [
    file("./helm/consul-smi-controller.yaml")
  ]
}

resource "kubectl_manifest" "consul-ingress" {
  depends_on = [helm_release.consul]
  provider = kubectl
  yaml_body = file("./config/ingress.yaml")
}

resource "kubernetes_config_map" "envoy" {
  metadata {
    name = "envoy-config"
  }

  data = {
    "envoy.yaml" = <<EOF
static_resources:
  listeners:
  - address:
      socket_address:
        address: 0.0.0.0
        port_value: 8080
    filter_chains:
    - filters:
      - name: envoy.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          codec_type: http1
          stat_prefix: ingress_http
          route_config:
            name: local_route
            virtual_hosts:
            - name: frontend
              domains:
              - "web.translate.demo.gs"
              retry_policy:
                retry_on: "connect-failure,5xx"
                num_retries: 5
              virtual_clusters:
                - name: web
                  headers:
                    - name: ":path"
                      prefix_match: "/"
              routes:
              - match:
                  prefix: "/"
                route:
                  cluster: frontend
            - name: backend
              domains:
              - "api.translate.demo.gs"
              retry_policy:
                retry_on: "connect-failure,5xx"
                num_retries: 5
              virtual_clusters:
                - name: api
                  headers:
                    - name: ":path"
                      prefix_match: "/"
              routes:
              - match:
                  prefix: "/"
                route:
                  cluster: api
          http_filters:
          - name: envoy.router
            typed_config: {}
  clusters:
  - name: frontend
    connect_timeout: 1.00s
    type: strict_dns
    lb_policy: round_robin
    load_assignment:
      cluster_name: frontend
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: 127.0.0.1
                port_value: 9090
                ipv4_compat: true
  - name: api
    connect_timeout: 0.25s
    type: strict_dns
    lb_policy: round_robin
    load_assignment:
      cluster_name: api
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: 127.0.0.1
                port_value: 9091
                ipv4_compat: true
admin:
  access_log_path: "/dev/null"
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 8006
EOF
  }
}

resource "kubernetes_deployment" "ingress" {
  metadata {
    name = "ingress"
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "ingress"
      }
    }

    template {
      metadata {
        labels = {
          app = "ingress"
        }
        annotations = {
          "consul.hashicorp.com/connect-inject" = "true"
          "consul.hashicorp.com/connect-service-upstreams": "web:9090,api:9091"
        }
      }

      spec {
        container {
          image = "envoyproxy/envoy-alpine:v1.17.0"
          name  = "envoy"
          command = [
            "/usr/local/bin/envoy",
            "--config-path", "/etc/envoy/envoy.yaml",
            "--base-id", "1",
          ]

          liveness_probe {
            tcp_socket {
              port = 8080
            }

            initial_delay_seconds = 3
            period_seconds        = 3
          }

          volume_mount {
            name = "config"
            mount_path = "/etc/envoy/"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.envoy.metadata.0.name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "ingress" {
  metadata {
    name = "ingress"
  }
  spec {
    selector = {
      app = kubernetes_deployment.ingress.metadata.0.name
    }
    port {
      port        = 80
      target_port = 8080
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_service" "ingress-consul-metrics" {
  metadata {
    name = "ingress-consul-metrics"
    labels = {
      app = "metrics"
    }
  }

  spec {
    selector = {
      app = kubernetes_deployment.ingress.metadata.0.name
    }
    port {
      name = "metrics"
      port        = 9102
      target_port = 9102
    }
  }
}

resource "kubernetes_service" "ingress-envoy-metrics" {
  metadata {
    name = "ingress-envoy-metrics"
    labels = {
      app = "envoy"
    }
  }

  spec {
    selector = {
      app = kubernetes_deployment.ingress.metadata.0.name
    }
    port {
      name = "metrics"
      port        = 9102
      target_port = 8006
    }
  }
}
