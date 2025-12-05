terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.15.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.5.3"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36.0"
    }
  }
}

provider "google" {
  # Configuration options
  credentials = file("${path.module}/../../key.json")
  project     = data.terraform_remote_state.infra.outputs.gcp_project
  region      = data.terraform_remote_state.infra.outputs.gcp_region
}

provider "google-beta" {
  credentials = file("${path.module}/../../key.json")
  project     = data.terraform_remote_state.infra.outputs.gcp_project
  region      = data.terraform_remote_state.infra.outputs.gcp_region
}


provider "acme" {
  # server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}


data "terraform_remote_state" "infra" {
  backend = "local"

  config = {
    path = "${path.module}/../infra/terraform.tfstate"
  }
}


data "google_client_config" "provider" {}

data "google_container_cluster" "my_cluster" {
  name     = data.terraform_remote_state.infra.outputs.cluster-name
  location = data.terraform_remote_state.infra.outputs.gcp_region
}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.my_cluster.endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.my_cluster.master_auth[0].cluster_ca_certificate,
  )
}

provider "helm" {
  kubernetes {
    host  = "https://${data.google_container_cluster.my_cluster.endpoint}"
    token = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.my_cluster.master_auth[0].cluster_ca_certificate,
    )
  }
}
