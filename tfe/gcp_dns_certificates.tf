locals {
  gcp_dns_fqdn = "${var.dns_hostname}.${var.dns_zonename}"
}

# Use an existing delegated public DNS zone (e.g., doormat-accountid)
data "google_dns_managed_zone" "selected" {
  name = var.gcp_dns_zone_name
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "registration" {
  account_key_pem = tls_private_key.private_key.private_key_pem
  email_address   = var.certificate_email
}

resource "acme_certificate" "certificate_gcp" {
  account_key_pem = acme_registration.registration.account_key_pem
  common_name     = local.gcp_dns_fqdn

  recursive_nameservers        = ["1.1.1.1:53"]
  disable_complete_propagation = true

  dns_challenge {
    provider = "gcloud"

    config = {
      GCE_PROJECT = data.terraform_remote_state.infra.outputs.gcp_project
    }
  }

  depends_on = [acme_registration.registration]
}

data "kubernetes_service" "example" {
  metadata {
    name      = local.namespace
    namespace = local.namespace
  }
  depends_on = [helm_release.tfe]
}

locals {
  lb_ingress       = try(data.kubernetes_service.example.status[0].load_balancer[0].ingress, [])
  lb_hostname      = length(local.lb_ingress) > 0 ? try(local.lb_ingress[0].hostname, "") : ""
  lb_ip            = length(local.lb_ingress) > 0 ? try(local.lb_ingress[0].ip, "") : ""
  use_hostname     = local.lb_hostname != ""
  dns_record_type  = local.use_hostname ? "CNAME" : "A"
  dns_rrdatas      = local.use_hostname ? [local.lb_hostname] : local.lb_ip != "" ? [local.lb_ip] : []
}

# Create CNAME when LoadBalancer exposes a hostname; fallback to A if IP is present
resource "google_dns_record_set" "tfe_record" {
  managed_zone = data.google_dns_managed_zone.selected.name
  name         = "${var.dns_hostname}.${var.dns_zonename}."
  type         = local.dns_record_type
  ttl          = 300
  rrdatas      = local.dns_rrdatas

  depends_on = [helm_release.tfe]
}