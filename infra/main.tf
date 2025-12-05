resource "google_compute_network" "tfe_vpc" {
  name                    = "${var.tag_prefix}-vpc"
  auto_create_subnetworks = false
}


resource "google_compute_subnetwork" "tfe_subnet" {
  name          = "${var.tag_prefix}-public1"
  ip_cidr_range = cidrsubnet(var.vnet_cidr, 8, 1)
  network       = google_compute_network.tfe_vpc.self_link
}

resource "google_compute_router" "tfe_router" {
  name    = "${var.tag_prefix}-router"
  network = google_compute_network.tfe_vpc.self_link
}

resource "google_compute_firewall" "default" {
  name    = "test-firewall"
  network = google_compute_network.tfe_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "443", "5432", "8201", "6379"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_storage_bucket" "tfe-bucket" {
  name          = "${var.tag_prefix}-bucket"
  location      = var.gcp_location
  force_destroy = true

  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
}

resource "google_compute_global_address" "private_ip_address" {
  # provider = google-beta

  name          = "tfe-vpc-internal2"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.tfe_vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  # provider = google-beta

  network                 = google_compute_network.tfe_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]

  deletion_policy = "ABANDON"

  depends_on = [
    google_project_service.apis["servicenetworking.googleapis.com"],
  ]
}


resource "google_sql_database_instance" "instance" {
  provider = google-beta

  name             = "${var.tag_prefix}-database"
  region           = var.gcp_region
  database_version = "POSTGRES_15"

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = "db-g1-small" ## possible issue in size
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.tfe_vpc.id
      enable_private_path_for_google_cloud_services = true
    }
    
    # Enable IAM authentication for passwordless database access
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
  }
  deletion_protection = false
}

resource "google_project_iam_binding" "example_storage_admin_binding" {
  project = var.gcp_project
  role    = "roles/storage.admin"

  members = [
    "serviceAccount:${google_service_account.service_account.email}"
  ]
}


resource "google_service_account" "service_account" {
  account_id   = "${var.tag_prefix}-bucket-test2"
  display_name = "${var.tag_prefix}-bucket-test2"
  project      = var.gcp_project
}

resource "google_service_account_key" "tfe_bucket" {
  service_account_id = google_service_account.service_account.name
}


data "google_project" "project" {
}


# Enable required Google Cloud APIs
resource "google_project_service" "apis" {
  for_each           = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
    "redis.googleapis.com",
    "iam.googleapis.com",
  ])
  project            = var.gcp_project
  service            = each.value
  disable_on_destroy = false
}

# these are for the service account when using auto-pilot GKE
resource "google_storage_bucket_iam_member" "object_viewer_binding" {
  # Bindings for GKE Autopilot using Workload Identity (Kubernetes SA principal)
  count  = var.gke_auto_pilot_enabled ? 1 : 0
  bucket = google_storage_bucket.tfe-bucket.name

  role   = "roles/storage.objectAdmin"
  # GKE Workload Identity member format: serviceAccount:PROJECT_ID.svc.id.goog[namespace/serviceaccount]
  member = "serviceAccount:${var.gcp_project}.svc.id.goog[terraform-enterprise/terraform-enterprise]"
}

resource "google_storage_bucket_iam_member" "object_viewer_binding2" {
  # Bindings for GKE Autopilot using Workload Identity (Kubernetes SA principal)
  count  = var.gke_auto_pilot_enabled ? 1 : 0
  bucket = google_storage_bucket.tfe-bucket.name

  role   = "roles/storage.legacyBucketReader"
  # GKE Workload Identity member format: serviceAccount:PROJECT_ID.svc.id.goog[namespace/serviceaccount]
  member = "serviceAccount:${var.gcp_project}.svc.id.goog[terraform-enterprise/terraform-enterprise]"
}



# these are for the service account when using non auto-pilot GKE
resource "google_storage_bucket_iam_member" "member-object" {
  # Bindings for non-Autopilot (using Google Service Account directly)
  count  = var.gke_auto_pilot_enabled ? 0 : 1
  bucket = google_storage_bucket.tfe-bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_storage_bucket_iam_member" "member-bucket" {
  # Bindings for non-Autopilot (using Google Service Account directly)
  count  = var.gke_auto_pilot_enabled ? 0 : 1
  bucket = google_storage_bucket.tfe-bucket.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_sql_database" "tfe-db" {
  # provider = google-beta
  name     = "tfe"
  instance = google_sql_database_instance.instance.name
}

resource "google_sql_user" "tfeadmin" {
  # provider = google-beta
  name            = "admin-tfe"
  instance        = google_sql_database_instance.instance.name
  password        = var.rds_password
  deletion_policy = "ABANDON"
}

# Explorer database (on same Cloud SQL instance)
resource "google_sql_database" "tfe-explorer-db" {
  name     = "tfe-explorer"
  instance = google_sql_database_instance.instance.name
}

resource "google_sql_user" "tfe-explorer-admin" {
  name            = "admin-tfe-explorer"
  instance        = google_sql_database_instance.instance.name
  password        = var.rds_password  # Using same password as main DB for simplicity
  deletion_policy = "ABANDON"
}
