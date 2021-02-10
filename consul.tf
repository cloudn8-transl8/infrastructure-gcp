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

resource "kubernetes_config_map" "nginx" {
  metadata {
    name = "nginx-config"
  }

  data = {
    "nginx.conf" = <<EOF
events {
  worker_connections  1024;  ## Default: 1024
}

http {
    #...
  upstream web {
    server localhost:9090;
  }
  
  upstream api {
    server localhost:9091;
  }

  server {
    listen 80;
    server_name web.translate.demo.gs;
    location / {
      proxy_pass       http://web;
      proxy_http_version 1.1;
      proxy_set_header HOST $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    }
  }
  
  server {
    listen 80;
    server_name api.translate.demo.gs;
    location / {
      proxy_pass       http://api;
      proxy_http_version 1.1;
      proxy_set_header HOST $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    }
  }
}
EOF
  }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name = "nginx"
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
        annotations = {
          "consul.hashicorp.com/connect-inject" = "true"
          "consul.hashicorp.com/connect-service-upstreams": "web:9090,api:9091"
        }
      }

      spec {
        container {
          image = "nginx:1.7.8"
          name  = "nginx"

          liveness_probe {
            tcp_socket {
              port = 80
            }

            initial_delay_seconds = 3
            period_seconds        = 3
          }

          volume_mount {
            name = "config"
            mount_path = "/etc/nginx/"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.nginx.metadata.0.name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx" {
  metadata {
    name = "nginx"
  }
  spec {
    selector = {
      app = kubernetes_deployment.nginx.metadata.0.name
    }
    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_service" "nginx-metrics" {
  metadata {
    name = "nginx-metrics"
    labels = {
      app = "metrics"
    }
  }

  spec {
    selector = {
      app = kubernetes_deployment.nginx.metadata.0.name
    }
    port {
      name = "metrics"
      port        = 9102
      target_port = 9102
    }
  }
}
