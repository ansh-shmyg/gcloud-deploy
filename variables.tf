# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------
# DATABASE
variable "project" {
  description = "The project ID to host the database in."
  type        = string
  default     = "gcpssproject-248009"
}

variable "region" {
  description = "The region to host the database in."
  type        = string
  default     = "europe-west1"
}

# Note, after a name db instance is used, it cannot be reused for up to one week.
variable "name_prefix" {
  description = "The name prefix for the database instance. Will be appended with a random string. Use lowercase letters, numbers, and hyphens. Start with a letter."
  type        = string
  default     = "main-postgress-"
}

variable "master_user_name" {
  description = "The username part for the default user credentials, i.e. 'master_user_name'@'master_user_host' IDENTIFIED BY 'master_user_password'. This should typically be set as the environment variable TF_VAR_master_user_name so you don't check it into source control."
  type        = string
  default     = "postrges"
}

#   description = "The password part for the default user credentials, i.e. 'master_user_name'@'master_user_host' IDENTIFIED BY 'master_user_password'. This should typically be set as the environment variable TF_VAR_master_user_password so you don't check it into source control."
resource "random_id" "password_database" {
  byte_length = 16
}

resource "random_id" "name" {
  byte_length = 2
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "postgres_version" {
  description = "The engine version of the database, e.g. `POSTGRES_9_6`. See https://cloud.google.com/sql/docs/db-versions for supported versions."
  type        = string
  default     = "POSTGRES_9_6"
}

variable "machine_type" {
  description = "The machine type to use, see https://cloud.google.com/sql/pricing for more details"
  type        = string
  default     = "db-f1-micro"
}

variable "db_name" {
  description = "Name for the db"
  type        = string
  default     = "main"
}

variable "name_override" {
  description = "You may optionally override the name_prefix + random string by specifying an override"
  type        = string
  default     = null
}

# Kluster configuration
# GKE
variable "cluster_name" {
  default = "gke-gevops"
}
variable "project_name" {
  default = "gcpssproject-248009"
}

variable "gloud_creds_file" {
  default = "~/.gcloud/gcpssproject-248009-54dc60693c76.json"
}

variable "machine_type_cluster" {
//  default = "g1-small"
  default = "n1-standard-2"
}


variable "kubernetes_ver" {
  default = "1.13"
}

variable "logicapp_conf_query_url" {
  default = "http://queryapp.dev.svc:5003/query/yml_data"
}

variable "frontendapp_app_query_url" {
  default = "http://logicapp.dev.svc:5002/logic/query_data"
}

variable "frontendapp_app_settings_url" {
  default = "http://cfgmanapp.dev.svc:5004/start"
}

variable "frontendapp_app_settings_save_url" {
  default = "http://cfgmanapp.dev.svc:5004/save"
}

variable "queryapp_config_api_url" {
  default = "http://cfgmanapp.dev.svc:5004/conf/query"
}

resource "random_id" "username" {
  byte_length = 14
}

resource "random_id" "password" {
  byte_length = 16
}

## Misc
variable "github_token" {
  default = "ZThmYzQ3NmMxMzA3YWNlOGM0ZjZhYWM1YWZhNzMxNGI3MWUzZDA5Zgo=" 
}
