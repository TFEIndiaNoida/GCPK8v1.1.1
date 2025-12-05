
locals {
  namespace       = "terraform-enterprise"
  full_chain      = "${acme_certificate.certificate_gcp.certificate_pem}${acme_certificate.certificate_gcp.issuer_pem}"
  # Always use standard GKE overrides
}


resource "kubernetes_namespace" "terraform-enterprise" {
  metadata {
    name = local.namespace
  }
}

resource "kubernetes_secret" "example" {
  metadata {
    name      = local.namespace
    namespace = kubernetes_namespace.terraform-enterprise.metadata.0.name
  }

  data = {
    ".dockerconfigjson" = <<DOCKER
{
  "auths": {
    "images.releases.hashicorp.com": {
      "auth": "${base64encode("terraform:${var.tfe_license}")}"
    }
  }
}
DOCKER
  }

  type = "kubernetes.io/dockerconfigjson"
}

# resource "helm_release" "tfe" {
#   name      = "terraform-enterprise"
#   chart     = "${path.module}/terraform-enterprise-helm"
#   namespace = "terraform-enterprise"
#   values = [
#     "${file("${path.module}/overrides.yaml")}" 
#   ]
#   depends_on = [
#     kubernetes_secret.example, kubernetes_namespace.terraform-enterprise
#   ]
# }


# resource "kubernetes_service_account" "bucket_access" {
#   metadata {
#     name      = "bucket-access"
#     namespace = "terraform-enterprise"
#     annotations = {
#       "iam.gke.io/gcp-service-account" = "tfe23-bucket-test2@hc-a0f1bfc7007d44728b4b096ce4e.iam.gserviceaccount.com"
#     }
#   }
# }



# The default for using the helm chart from internet
resource "helm_release" "tfe" {
  name       = local.namespace
  repository = "https://helm.releases.hashicorp.com"
  chart      = "terraform-enterprise"
  namespace  = local.namespace

  force_update    = true
  cleanup_on_fail = true
  replace         = true
  values = [
    templatefile("${path.module}/overrides-gke.yaml", {
      replica_count = var.replica_count
      region        = data.terraform_remote_state.infra.outputs.gcp_region
      enc_password  = var.tfe_encryption_password
      pg_dbname     = data.terraform_remote_state.infra.outputs.pg_dbname
      pg_user       = data.terraform_remote_state.infra.outputs.pg_user
      pg_password   = data.terraform_remote_state.infra.outputs.pg_password
      pg_address    = data.terraform_remote_state.infra.outputs.pg_address
      fqdn          = "${var.dns_hostname}.${var.dns_zonename}"
      google_bucket = data.terraform_remote_state.infra.outputs.google_bucket
      gcp_project   = data.terraform_remote_state.infra.outputs.gcp_project
      // Base64-encoded service account credentials as required by chart
      google_creds_b64 = base64encode(file("../../key.json"))
      cert_data     = "${base64encode(local.full_chain)}"
      key_data      = "${base64encode(nonsensitive(acme_certificate.certificate_gcp.private_key_pem))}"
      ca_cert_data  = "${base64encode(local.full_chain)}"
      redis_host    = data.terraform_remote_state.infra.outputs.redis_host
      redis_port    = data.terraform_remote_state.infra.outputs.redis_port
      tfe_license   = var.tfe_license
      tfe_release   = var.tfe_release
      # Explorer database configuration
      explorer_db_host     = data.terraform_remote_state.infra.outputs.explorer_db_host
      explorer_db_name     = data.terraform_remote_state.infra.outputs.explorer_db_name
      explorer_db_user     = data.terraform_remote_state.infra.outputs.explorer_db_user
      explorer_db_password = data.terraform_remote_state.infra.outputs.explorer_db_password
    })
  ]
  timeout = 900
  wait    = false
  depends_on = [
    kubernetes_secret.example, kubernetes_namespace.terraform-enterprise
  ]
}
