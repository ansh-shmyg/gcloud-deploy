provider "google" {
  credentials = "${file(var.gloud_creds_file)}"
  project     = "${var.project_name}"
  region      = "${var.region}"
}

provider "google-beta" {
  version = "~> 2.7.0"
  credentials = "${file(var.gloud_creds_file)}"
  project = var.project
  region  = var.region
}

terraform {
  required_version = ">= 0.12"
}

# ------------------------------------------------------------------------------
# CREATE A RANDOM SUFFIX AND PREPARE RESOURCE NAMES
# ------------------------------------------------------------------------------

locals {
  # If name_override is specified, use that - otherwise use the name_prefix with a random string
  instance_name        = var.name_override == null ? format("%s-%s", var.name_prefix, random_id.name.hex) : var.name_override
  private_network_name = "private-network-${var.cluster_name}"
  private_ip_name      = "private-ip-${var.cluster_name}"
}

# ------------------------------------------------------------------------------
# CREATE COMPUTE NETWORKS
# ------------------------------------------------------------------------------

# Simple network, auto-creates subnetworks
resource "google_compute_network" "private_network" {
  provider = "google-beta"
  name     = local.private_network_name
}

# Reserve global internal address range for the peering
resource "google_compute_global_address" "private_ip_address" {
  provider      = "google-beta"
  name          = local.private_ip_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.private_network.self_link
}

# Establish VPC network peering connection using the reserved address range
resource "google_service_networking_connection" "private_vpc_connection" {
  provider                = "google-beta"
  network                 = google_compute_network.private_network.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# ------------------------------------------------------------------------------
# CREATE DATABASE INSTANCE WITH PRIVATE IP
# ------------------------------------------------------------------------------

module "postgres" {
  source = "./modules/cloud-sql"

  project = var.project
  region  = var.region
  name    = local.instance_name
  db_name = var.db_name

  engine       = var.postgres_version
  machine_type = var.machine_type

  master_user_password = "${random_id.password_database.hex}"

  master_user_name = var.master_user_name
  master_user_host = "%"

  # Pass the private network link to the module
  private_network = google_compute_network.private_network.self_link
  dependencies = [google_service_networking_connection.private_vpc_connection.network]

  custom_labels = {
    test-id = "postgres-private-ip-example"
  }
}

resource "google_container_cluster" "primary" {
  name        = "${var.cluster_name}"
  project     = "${var.project_name}"
  description = "Demo GKE Cluster"
  location    = "${var.region}"
  min_master_version = "${var.kubernetes_ver}"
  network     = "${google_compute_network.private_network.self_link}"

  remove_default_node_pool = true
  initial_node_count = 1

  master_auth {
    username = "${random_id.username.hex}"
    password = "${random_id.password.hex}"
  }
  ip_allocation_policy {
    use_ip_aliases = true
  }
  depends_on = ["google_service_networking_connection.private_vpc_connection"]
}

resource "google_container_node_pool" "primary" {
  name       = "${var.cluster_name}-node-pool"
  project     = "${var.project_name}"
  location   = "${var.region}"
  cluster    = "${google_container_cluster.primary.name}"
  node_count = 1

  node_config {
    #preemptible  = true
    machine_type = "${var.machine_type_cluster}"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

resource "google_compute_firewall" "default_ssh_http_https" {
  name    = "${var.cluster_name}-firewall"
  network = "${google_compute_network.private_network.name}"

  allow {
    protocol = "tcp"
    ports    = [ "22", "80", "443"]
  }
  source_ranges = ["0.0.0.0/0"]
}

provider "kubernetes" {
  host = "https://${google_container_cluster.primary.endpoint}"
  cluster_ca_certificate = "${base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)}"
  username = "${random_id.username.hex}"
  password = "${random_id.password.hex}"
}

data "template_file" "kubeconfig" {
  template = file("templates/kubeconfig-template.yaml")

  vars = {
    cluster_name    = google_container_cluster.primary.name
    user_name       = google_container_cluster.primary.master_auth[0].username
    user_password   = google_container_cluster.primary.master_auth[0].password
    endpoint        = google_container_cluster.primary.endpoint
    cluster_ca      = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
    client_cert     = google_container_cluster.primary.master_auth[0].client_certificate
    client_cert_key = google_container_cluster.primary.master_auth[0].client_key
  }
}

#data "template_file" "spinnaker_chart" {
#  template = file("templates/spinnaker-chart-template.yaml")
#
#  vars = {
#    google_project_name = "${var.project_name}"
#    google_spin_bucket_name = "${google_storage_bucket.spinnaker-store.name}"
#    google_subscription_name = "${google_pubsub_subscription.spinnaker_pubsub_subscription.name}"
#    google_spin_sa_key = "${base64decode(google_service_account_key.spinnaker-store-sa-key.private_key)}"
#  }
#}

data "template_file" "google_gcp_sa" {
  template = file("templates/template-gcp-service-account.json")

  vars = {
    google_spin_sa_key = "${base64decode(google_service_account_key.spinnaker-store-sa-key.private_key)}"
  }
}


#data "template_file" "istio_chart" {
#  template = file("templates/istio-chart-template.yaml")
#}

data "template_file" "template_pipelines_spin_upload" {
  template = file("templates/template-spin-cli-upload-pipelines.yaml")

  vars = {
    google_project_name = "${var.project_name}"
  }
}

data "template_file" "template_haliard_install" {
  template = file("templates/template-haliard-install.yaml")

  vars = {
    google_project_name = "${var.project_name}"
    github_token_decoded = "${base64decode(var.github_token)}"
  }
}
  
data "template_file" "spinnaker_install_sh" {
  template = file("templates/template-create-spinnaker.sh")

  vars = {
    cluster_name = "${var.cluster_name}"
  }
}

resource "local_file" "template_haliard_install" {
  content  = data.template_file.template_haliard_install.rendered
  filename = "haliard-install.yaml"
}

resource "local_file" "file_google_gcp_sa" {
  content  = data.template_file.google_gcp_sa.rendered
  filename = "gcp-service-account.json"
}

resource "local_file" "template_pipelines_spin_upload" {
  content  = data.template_file.template_pipelines_spin_upload.rendered
  filename = "spin-cli-upload-pipelines.yaml"
}

resource "local_file" "kubeconfig" {
  content  = data.template_file.kubeconfig.rendered
  filename = "kubeconfig"
}

resource "local_file" "spinnaker_install_sh" {
  content  = data.template_file.spinnaker_install_sh.rendered
  filename = "create-spinnaker.sh"
}

resource "google_service_account" "spinnaker-store-sa" {
  account_id   = "spinnaker-store-sa-id"
  display_name = "Spinnaker-store-sa"
  # depends_on = ["google_storage_bucket.spinnaker-store"]
}
resource "google_service_account_key" "spinnaker-store-sa-key" {
  service_account_id = "${google_service_account.spinnaker-store-sa.name}"
  public_key_type = "TYPE_X509_PEM_FILE"
}
resource "google_storage_bucket" "spinnaker-store" {
  name     = "${var.project_name}-spinnaker-conf"
  location = "EU"
  force_destroy = true
//  lifecycle {
//    prevent_destroy = true
//  }
}

resource "google_storage_bucket_iam_binding" "spinnaker-bucket-iam" {
  bucket = "${google_storage_bucket.spinnaker-store.name}"
  role        = "roles/storage.admin"

  members = [
    "serviceAccount:${google_service_account.spinnaker-store-sa.email}",
  ]
}

resource "google_cloudbuild_trigger" "logicapp-trigger" {
  trigger_template {
    branch_name = "master"
    repo_name   = "github_kv-053-devops_logicapp"
  }
  description = "Trigger Git repository github_kv-053-devops_logicapp"
  filename = "cloudbuild.yaml"
}

resource "google_cloudbuild_trigger" "frontendapp-trigger" {
  trigger_template {
    branch_name = "master"
    repo_name   = "github_kv-053-devops_frontendapp"
  }
  description = "Trigger Git repository github_kv-053-devops_frontendapp"
  filename = "cloudbuild.yaml"
}

resource "google_cloudbuild_trigger" "frontendapp-queryapp" {
  trigger_template {
    branch_name = "master"
    repo_name   = "github_kv-053-devops_queryapp"
  }
  description = "Trigger Git repository github_kv-053-devops_queryapp"
  filename = "cloudbuild.yaml"
}

resource "google_cloudbuild_trigger" "frontendapp-cfgmanapp" {
  trigger_template {
    branch_name = "master"
    repo_name   = "github_kv-053-devops_cfgmanapp"
  }
  description = "Trigger Git repository github_kv-053-devops_cfgmanapp"
  filename = "cloudbuild.yaml"
}


resource "google_pubsub_subscription" "spinnaker_pubsub_subscription" {
  name  = "spinnaker-subscription"
  topic = "projects/${var.project_name}/topics/cloud-builds"

  message_retention_duration = "604800s"
  ack_deadline_seconds = 20
  expiration_policy {
    ttl = "2592000s"
  }

}

resource "google_pubsub_subscription_iam_binding" "spinnaker_pubsub_iam_read" {
  subscription = "${google_pubsub_subscription.spinnaker_pubsub_subscription.name}"
  role         = "roles/pubsub.subscriber"
  members      = [
    "serviceAccount:${google_service_account.spinnaker-store-sa.email}",
  ]
}

resource "kubernetes_namespace" "prod" {
  metadata {
    name = "prod"
    labels =  {
      istio-injection = "enabled" 
    }
  }
  depends_on = ["google_container_node_pool.primary"]
}

resource "kubernetes_namespace" "dev" {
  metadata {
    name = "dev"
    labels =  {
      istio-injection = "enabled" 
    }
  }
  depends_on = ["google_container_node_pool.primary"]
}

resource "kubernetes_namespace" "spinnaker" {
  metadata {
    name = "spinnaker"
  }
  depends_on = ["google_container_node_pool.primary"]
}

resource "kubernetes_namespace" "istio-system" {
  metadata {
    name = "istio-system"
  }
  depends_on = ["google_container_node_pool.primary"]
}
  
  
resource "kubernetes_config_map" "logicapp-env-conf-dev" {
  metadata {
    name = "logicapp-env-vars"
    namespace = "dev"
  }

  data = {
    logicapp-app-query-url = "${var.logicapp_conf_query_url}"
  }
  depends_on = ["kubernetes_namespace.dev"]
}

resource "kubernetes_config_map" "logicapp-env-conf-prod" {
  metadata {
    name = "logicapp-env-vars"
    namespace = "prod"
  }

  data = {
    logicapp-app-query-url = "${var.logicapp_conf_query_url_prod}"
  }
  depends_on = ["kubernetes_namespace.prod"]
}

resource "kubernetes_config_map" "frontendapp-env-conf-dev" {
  metadata {
    name = "frontendapp-env-vars"
    namespace = "dev"
  }

  data = {
    app_query_url = "${var.frontendapp_app_query_url}"
    app_settings_url = "${var.frontendapp_app_settings_url}"
    app_settings_save_url = "${var.frontendapp_app_settings_save_url}"
  }
  depends_on = ["kubernetes_namespace.dev"]
}

resource "kubernetes_config_map" "frontendapp-env-conf-prod" {
  metadata {
    name = "frontendapp-env-vars"
    namespace = "prod"
  }

  data = {
    app_query_url = "${var.frontendapp_app_query_url_prod}"
    app_settings_url = "${var.frontendapp_app_settings_url_prod}"
    app_settings_save_url = "${var.frontendapp_app_settings_save_url_prod}"
  }
  depends_on = ["kubernetes_namespace.prod"]
}

resource "kubernetes_config_map" "queryapp-env-conf-dev" {
  metadata {
    name = "queryapp-env-vars"
    namespace = "dev"
  }

  data = {
    config_api_url = "${var.queryapp_config_api_url}"
  }
  depends_on = ["kubernetes_namespace.dev"]
}

resource "kubernetes_config_map" "queryapp-env-conf-prod" {
  metadata {
    name = "queryapp-env-vars"
    namespace = "prod"
  }

  data = {
    config_api_url = "${var.queryapp_config_api_url_prod}"
  }
  depends_on = ["kubernetes_namespace.prod"]
}

resource "kubernetes_secret" "credentials_db_prod" {
  metadata {
    name = "credentials-db"
    namespace = "prod"
  }

  data = {
    db_user_name = "${var.master_user_name}"
    db_user_pass = "${random_id.password_database.hex}"
    db_name = module.postgres.db_name
    db_address = module.postgres.master_private_ip_address
  }
  depends_on = ["kubernetes_namespace.prod"]
}


resource "null_resource" "configure_tiller_spinnaker" {
  provisioner "local-exec" {
    command = <<LOCAL_EXEC
kubectl config use-context ${var.cluster_name} --kubeconfig=${local_file.kubeconfig.filename}
kubectl apply -f create-helm-service-account.yml --kubeconfig=${local_file.kubeconfig.filename}
helm init --service-account helm --upgrade --wait --kubeconfig=${local_file.kubeconfig.filename}
LOCAL_EXEC
  }
  depends_on = ["google_container_node_pool.primary","local_file.kubeconfig","kubernetes_namespace.spinnaker","local_file.template_haliard_install","google_storage_bucket_iam_binding.spinnaker-bucket-iam","google_pubsub_subscription_iam_binding.spinnaker_pubsub_iam_read","local_file.spinnaker_install_sh"]
}
#bash create-spinnaker.sh && bash install-istio.sh && bash apply-spin-pipelines.sh && bash upload-grafana-dashborad.sh
