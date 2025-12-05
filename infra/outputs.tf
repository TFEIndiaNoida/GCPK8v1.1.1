output "kubectl_environment" {
  value = "gcloud container clusters get-credentials ${var.tag_prefix}-gke-cluster --region ${var.gcp_region}"
}

output "cluster-name" {
  value = google_container_cluster.primary.name
}

output "prefix" {
  value = var.tag_prefix
}

output "gcp_region" {
  value = var.gcp_region
}

output "gcp_project" {
  value = var.gcp_project
}

output "service_account" {
  value = google_service_account.service_account.email
}

output "gcp_location" {
  value = var.gcp_location
}

output "pg_dbname" {
  value = google_sql_database.tfe-db.name
}

output "pg_user" {
  # value = "admin-tfe"  # Password-based authentication
  value = trimsuffix(google_service_account.service_account.email, ".gserviceaccount.com")  # IAM authentication
}

output "pg_password" {
  value     = var.rds_password
  sensitive = true
}

output "pg_address" {
  value = google_sql_database_instance.instance.private_ip_address
}

output "redis_host" {
  value = "harshit-redis.tf-support.hashicorpdemo.com"
}

output "redis_port" {
  value = 6379
}

output "redis_auth_string" {
  value     = google_redis_instance.cache.auth_string
  sensitive = true
}

output "google_bucket" {
  value = "${var.tag_prefix}-bucket"
}

output "gke_auto_pilot_enabled" {
  value = var.gke_auto_pilot_enabled
}

# Explorer database outputs
output "explorer_db_host" {
  value = google_sql_database_instance.instance.private_ip_address
  description = "Explorer database host (same instance as main TFE DB)"
}

output "explorer_db_name" {
  value = google_sql_database.tfe-explorer-db.name
}

output "explorer_db_user" {
  value = "admin-tfe-explorer"
}

output "explorer_db_password" {
  value     = var.rds_password
  sensitive = true
  description = "Explorer database password (same as main TFE DB password)"
}
