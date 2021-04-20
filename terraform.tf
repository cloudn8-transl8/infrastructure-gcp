terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
      version = "2.1.1"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.1.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    google = {
      source = "hashicorp/google"
      version = "3.64.0"
    }
  }

  required_version = ">= 0.14.8"
}

# Change these settings to your own terraform cloud account
terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "niccorp"

    workspaces {
      name = "infrastructure-gcp"
    }
  }
}

# Set the environment variables GOOGLE_PROJECT AND GOOGLE_REGION
provider "google" {}

resource "google_service_account" "default" {
  account_id   = "service-account-id"
  display_name = "Service Account for GKE cluster"
}

# Store key as a K8s secret
resource "google_service_account_key" "mykey" {
  service_account_id = google_service_account.default.name
}

resource "kubernetes_secret" "google-application-credentials" {
  metadata {
    name = "google-application-credentials"
  }
  data = {
    "credentials.json" = base64decode(google_service_account_key.mykey.private_key)
  }
}

resource "google_container_cluster" "mycluster" {
  name               = var.name
  location           = var.location
  initial_node_count = 1
  remove_default_node_pool = true

  // initial node pool is scaled to 0 after creation
  // the following block stops terraform thinking the resource
  // is out of sync and needs to be recreated
  lifecycle {
    ignore_changes = [
      initial_node_count
    ]
  }

  network    = "default"
  subnetwork = "default"

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/16"
    services_ipv4_cidr_block = "/22"
  }
}

resource "google_container_node_pool" "mycluster" {
  name       = "${var.name}-node-pool"
  location   = var.location
  cluster    = google_container_cluster.mycluster.name
  node_count = var.nodes

  autoscaling {
    min_node_count = var.nodes
    max_node_count = var.nodes + 3

  }
    
  max_pods_per_node = 110

  node_config {
    machine_type = var.machine_type

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

data "google_client_config" "provider" {}

# Configure the Kubernetes and Helm providers using the data from the cluster
provider "kubernetes" {
  host  = "https://${google_container_cluster.mycluster.endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    google_container_cluster.mycluster.master_auth[0].cluster_ca_certificate,
  )
}

provider "kubectl" {
  host  = "https://${google_container_cluster.mycluster.endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    google_container_cluster.mycluster.master_auth[0].cluster_ca_certificate,
  )

  load_config_file = false
}

provider "helm" {
  kubernetes {
    host  = "https://${google_container_cluster.mycluster.endpoint}"
    token = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(
      google_container_cluster.mycluster.master_auth[0].cluster_ca_certificate,
    )
  }
}
