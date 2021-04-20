resource "google_redis_instance" "cache" {
  name           = "memory-cache"
  memory_size_gb = 1
}

resource "kubernetes_secret" "redis-host" {
  metadata {
    name = "redis-host"
  }

  data = {
    "hostname" = google_redis_instance.cache.host
    "port" = google_redis_instance.cache.port
  }
}