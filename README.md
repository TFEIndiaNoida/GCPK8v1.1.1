# Terraform Enterprise FDO - GCP with IAM Passwordless Authentication

This repository deploys Terraform Enterprise (TFE) Flexible Deployment Option (FDO) on Google Kubernetes Engine (GKE) with external services on GCP. 

## Key Features
- **IAM Passwordless Authentication** for Cloud SQL PostgreSQL
- External PostgreSQL database with IAM-based authentication
- Redis with mTLS authentication
- Google Cloud Storage for object storage
- TLS certificates via Let's Encrypt (ACME)
- Standard GKE cluster (non-Autopilot)

## Architecture
- **Compute**: GKE Standard cluster with managed node pools
- **Database**: Cloud SQL PostgreSQL with IAM authentication enabled
- **Cache**: Redis instance with mTLS
- **Storage**: Google Cloud Storage bucket
- **Networking**: Private VPC with service networking  

# Prerequisites

## License
Make sure you have a valid TFE license available

## GCP Setup

### Authentication
Configure your GCP credentials:

```bash
gcloud config set account <your-account>
gcloud auth activate-service-account --key-file=key.json
gcloud config set project <your-project>
gcloud auth application-default login
export USE_GKE_GCLOUD_AUTH_PLUGIN=True  # Required for kubectl integration
```

### Required GCP APIs
Enable the following APIs:

```bash
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable redis.googleapis.com
gcloud services enable iam.googleapis.com
```

### IAM Permissions
Your GCP account needs these roles:
- Compute Network Admin
- Compute Storage Admin
- Editor
- Project IAM Admin
- Kubernetes Engine Admin
- Kubernetes Engine Cluster Admin

**Or simply:** Owner role

### Important: IAM Database Authentication
This setup uses **IAM passwordless authentication** for Cloud SQL PostgreSQL. The infrastructure creates:
1. A service account for GKE nodes
2. An IAM database user (format: `service-account-name@project-id.iam`)
3. Cloud SQL instance with IAM authentication enabled

## GCP DNS (using Google Cloud DNS)

This repository uses Google Cloud DNS for DNS management. Ensure you have a managed DNS zone created in your GCP project.

## Install terraform  
See the following documentation [How to install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

## TLS certificate
You need valid TLS certificates for the DNS name you'll use to access TFE.  
  
This repository automatically provisions certificates using **Let's Encrypt (ACME)** with DNS-01 challenge via Google Cloud DNS. 

## kubectl
Make sure kubectl is available on your system. Please see the documentation [here](https://kubernetes.io/docs/tasks/tools/).

## helm
Make sure helm is available on your system. Please see the documentation [here](https://helm.sh/docs/intro/install/)

# Deployment Guide

## Step 1: Clone Repository

```bash
git clone https://github.com/TFEIndiaNoida/GCPK8v1.1.1.git
cd GCPK8v1.1.1
```

## Step 2: GCP Service Account Key

Add your GCP service account authentication key as `key.json` to the root directory of the repository.

## Step 3: Deploy Infrastructure (GKE, PostgreSQL, Redis, Storage)

Navigate to the infrastructure directory:
```bash
cd infra
```

Create `variables.auto.tfvars` with your configuration:
```hcl
# General
tag_prefix             = "tfe29"                          # Prefix for resource names
# GCP Configuration
gcp_region             = "asia-south1"                    # GCP region (e.g., asia-south1, us-central1)
vnet_cidr              = "10.214.0.0/16"                  # VPC network CIDR
gcp_project            = "hc-f4cfe5fcacd245c7985c932215d" # Your GCP project ID
gcp_location           = "EU"                             # Storage bucket location (US, EU, ASIA)
rds_password           = "Password#1"                     # PostgreSQL password (for traditional users if needed)
gke_auto_pilot_enabled = false                            # Use standard GKE (not Autopilot)
```

**Important Notes:**
- Set `gke_auto_pilot_enabled = false` for standard GKE cluster
- The `rds_password` is used only for creating a traditional PostgreSQL user as backup
- IAM authentication will be the primary authentication method
Initialize and deploy the infrastructure:
```bash
terraform init
terraform plan
terraform apply
```

Expected output (creates ~20 resources):
```
Apply complete! Resources: 20 added, 0 changed, 0 destroyed.

Outputs:

cluster-name = "tfe29-gke-cluster"
explorer_db_host = "10.43.1.3"
explorer_db_name = "tfe-explorer"
explorer_db_password = <sensitive>
explorer_db_user = "admin-tfe-explorer"
gcp_location = "EU"
gcp_project = "hc-f4cfe5fcacd245c7985c932215d"
gcp_region = "asia-south1"
gke_auto_pilot_enabled = false
google_bucket = "tfe29-bucket"
kubectl_environment = "gcloud container clusters get-credentials tfe29-gke-cluster --region asia-south1"
pg_address = "10.43.1.3"
pg_dbname = "tfe"
pg_password = <sensitive>
pg_user = "tfe29-bucket-test2@hc-f4cfe5fcacd245c7985c932215d.iam"
prefix = "tfe29"
redis_auth_string = <sensitive>
redis_host = "harshit-redis.tf-support.hashicorpdemo.com"
redis_port = 6379
service_account = "tfe29-bucket-test2@hc-f4cfe5fcacd245c7985c932215d.iam.gserviceaccount.com"

**Key Points:**
- Note the `pg_user` output - it's in IAM format (`name@project-id.iam`)
- The `service_account` is used by GKE nodes to authenticate
- Configure `kubectl` using the `kubectl_environment` command

## Step 4: Deploy Terraform Enterprise on GKE

Navigate to the TFE directory:
```bash
cd ../tfe
```

Create `variables.auto.tfvars` with your configuration:
```hcl
# DNS Configuration
dns_hostname               = "tfe29"                                   # Hostname used for TFE
dns_zonename               = "hc-f4cfe5fcacd245c7985c932215d.gcp.sbx.hashicorpdemo.com"
certificate_email          = "ramit.bansal@hashicorp.com"             # email address used for creating valid certificates
tfe_encryption_password    = "Password#1"                              # encryption key used by TFE
tfe_license                = "02MV4UU43BK5HGYYTOJZWFQMTMNNEWU33JJVVECMSNNJMTKTTKIF2FSVCNPJHGSMLIJVCE42KMKRAXUWLNKV2E6V2FGBGVOTJRJZ5FCMSZKRCXOSLJO5UVSM2WPJSEOOLULJMEUZTBK5IWST3JJF5E4MSRGNNFIQLZJV4TC3KZPJRXQTCXJJWFSVCNORMTEVTJJ5JTA6CNIRHGSWTKLF3U6RCFO5GTEVLJJRBUU4DCNZHDAWKXPBZVSWCSOBRDENLGMFLVC2KPNFEXCSLJO5UWCWCOPJSFOVTGMRDWY5C2KNETMSLKJF3U22SVORGUIULUJVCFUVKNKRETMTSEMM3E4VDLOVGWU2ZTJVVFS6KNKRATAV3JJFZUS3SOGBMVQSRQLAZVE4DCK5KWST3JJF4U2RCJGFGFIQJQJRKECMSWIRAXOT3KIF3U62SBO5LWSSLTJFWVMNDDI5WHSWKYKJYGEMRVMZSEO3DULJJUSNSJNJEXOTLKLF2E2RCRORGUIVSVJVVE2NSOKRVTMTSUNN2U6VDLGVLWSSLTJFXFE3DDNUYXAYTNIYYGCVZZOVMDGUTQMJLVK2KPNFEXSTKEJEZEYVCBGJGFIQJQKZCES6SPNJKTKT3KKU2UY2TLGVHVM33JJRBUU53DNU4WWZCXJYYES2TPNFSEOVTZMNWUM3LCGNFHISLJO5UVU3LYNBNDGTLJJ5XHIOLGKE6T2LTMK43EO6JUK5RGOMTWPBUDA3CPI5ZU4L3KPBRVS5TZGZZWSSLVLBAWEWK2IE4XOK3RLB4ECRDGJVHHG5BRJZ4TMZJUPJNGGS3DNJLC6ODYOFZUYOCVK54W4TLPI5IU2WDPLBWUUQLQGFSEC23DME2GIVRQGMZTQUDXNVLGYYLWJJIDI4CKPBEUSOKEGZKUMTCVMFLFA2TLK5FHIY2EGZYGC3BWN5HWMR3OJMZHUUCLJJJG2R2IKYZWKWTXOFDGKK3PG5VS64ZLIFKE42CQLJTVGL2LKZMWOL2LFNWEOUDXJQ3WUQTYJE3UOT3BNM3FKYLJMFEG6ZLLGBJFI3ZXGJCFCPJ5"

                    
replica_count              = 2                                         # Number of replicas for TFE you would like to have started (Explorer requires minimum 2 replicas)

tfe_release                = "1.1.1"                               # The version of TFE application you wish to be deployed   

```

**Important Configuration Notes:**
- The TFE deployment uses **passwordless IAM authentication** automatically
- `TFE_DATABASE_PASSWORDLESS_GOOGLE_USE_DEFAULT_CREDENTIALS` is set to `"true"` in `overrides-gke.yaml`
- Database username is automatically set to the IAM service account format
- No database password is stored or transmitted

Initialize and deploy TFE:
```bash
terraform init
terraform apply
```

Expected output (creates ~7 resources):
```
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:

execute_script_to_create_user_admin = "./configure_tfe.sh tfe29.hc-f4cfe5fcacd245c7985c932215d.gcp.sbx.hashicorpdemo.com your.email@example.com Password#1"
tfe_application_url = "https://tfe29.hc-f4cfe5fcacd245c7985c932215d.gcp.sbx.hashicorpdemo.com"
```

## Step 5: Configure TFE

Execute the configuration script to create an admin user:
```bash
./configure_tfe.sh tfe29.hc-f4cfe5fcacd245c7985c932215d.gcp.sbx.hashicorpdemo.com your.email@example.com Password#1
```

This script will:
- Create an admin user with the specified credentials
- Create a default organization called `test`

## Step 6: Access TFE

Login to your TFE instance at:
```
https://tfe29.hc-f4cfe5fcacd245c7985c932215d.gcp.sbx.hashicorpdemo.com
```

### Verify IAM Authentication

To verify passwordless IAM authentication is working, check the pod logs:
```bash
kubectl logs -n terraform-enterprise -l app=terraform-enterprise --tail=50 | grep -i "managed identity\|iam"
```

You should see:
```
Managed Identity authentication enabled for PostgreSQL via CloudManagedIdentityDBAuthPatch
```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n terraform-enterprise
```

### View Pod Logs
```bash
kubectl logs -n terraform-enterprise <pod-name> --tail=100
```

### Describe Pod
```bash
kubectl describe pod -n terraform-enterprise <pod-name>
```

### Verify Database Connection
The pod should authenticate to Cloud SQL using IAM. Check logs for:
```
database.pgmultiauth: getting initial db auth token
```

## Key Features of This Setup

✅ **IAM Passwordless Authentication**: No database passwords stored or transmitted  
✅ **mTLS for Redis**: Secure Redis connections using mutual TLS  
✅ **Automatic Certificate Management**: Let's Encrypt certificates via ACME  
✅ **High Availability**: Multiple TFE replicas with external services  
✅ **Secure by Design**: Uses GCP IAM for authentication and authorization  

## Important Files

- `infra/outputs.tf`: Updated to use IAM database user format
- `tfe/overrides-gke.yaml`: Configured with `TFE_DATABASE_PASSWORDLESS_GOOGLE_USE_DEFAULT_CREDENTIALS: "true"`
- `.gitignore`: Excludes sensitive files (.tfstate, .tfvars, certificates, etc.)

## Architecture Highlights

- **Database**: Cloud SQL PostgreSQL with IAM authentication enabled
- **Authentication Method**: Service account attached to GKE nodes provides credentials
- **Database User Format**: `service-account-name@project-id.iam` (not traditional username)
- **No Passwords**: IAM tokens are obtained automatically from GCP metadata service

## Completed Features

- [x] Build VPC network with private subnets
- [x] Create GKE cluster (standard mode)
- [x] Deploy Redis with mTLS
- [x] Create Cloud SQL PostgreSQL with IAM authentication
- [x] Configure IAM database user
- [x] Create GCS bucket
- [x] Generate TLS certificates via Let's Encrypt
- [x] Deploy TFE using Helm chart with IAM passwordless auth
- [x] Configure DNS records
- [x] Enable passwordless database authentication

## Version
TFE v1.1.1 with IAM Passwordless Authentication for GCP
