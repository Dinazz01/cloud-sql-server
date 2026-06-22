##instance-sqlserver.yaml

gcp_project: dba
instance_name: sqlserver1
environment: development

database_version: SQLSERVER_2022_STANDARD
edition: ENTERPRISE
tier: db-custom-4-15360
availability_type: REGIONAL
region: us-east4

replicas: {}

deletion_protection: false
retain_backups_on_delete: true

disk_size: 100
disk_type: PD_SSD
disk_autoresize: true

data_api_access: false

psc_config:
  allowed_consumer_projects:
    - "150000000000"

backup_config:
  enabled: true
  start_time: "04:00"
  point_in_time_recovery_enabled: false
  retained_backups: 14
  retention_unit: COUNT
  transaction_log_retention_days: null

enhanced_backup:
  enabled: false

final_backup:
  enabled: true
  description: "Final backup before SQL Server instance deletion"

advanced_dr:
  enabled: false

connection_pool_config:
  enabled: false

vertex_ai_integration:
  enabled: false

root_password_secret: csql-sqlserver-root-password

password_policy:
  enable_password_policy: false

flags: {}

iam:
  roles/cloudsql.client:
    - group:SA-AAD-GCP-CLOUD-OPS-ENGINEERING-PRVL@highmarkhealth.org

labels:
  environment: development
  team: dba
  engine: sqlserver
database-sqlserver.yaml
project: dba
instance: sqlserver1
#####################


databases:
  sqldb01:
    name: sqldb01
    charset: null
    collation: SQL_Latin1_General_CP1_CI_AS

    iam:
      roles/cloudsql.databaseUser:
        - group:SA-AAD-GCP-H@highmarkhealth.org

    users:
      sql_app_user:
        password_secret: csql-sqlserver-app-user-password

#####################################        
Update modules/google-cloud-sql/main.tf

Add SQL Server detection:

locals {
  is_mysql     = startswith(var.database_version, "MYSQL")
  is_postgres  = startswith(var.database_version, "POSTGRES")
  is_sqlserver = startswith(var.database_version, "SQLSERVER")
}

Update backup block:

backup_configuration {
  enabled                        = var.backup_configuration.enabled
  start_time                     = var.backup_configuration.start_time
  point_in_time_recovery_enabled = local.is_mysql || local.is_postgres ? var.backup_configuration.point_in_time_recovery_enabled : false
  binary_log_enabled             = local.is_mysql ? true : false
  transaction_log_retention_days = local.is_postgres ? var.backup_configuration.transaction_log_retention_days : null

  backup_retention_settings {
    retained_backups = var.backup_configuration.retained_backups
    retention_unit   = var.backup_configuration.retention_unit
  }
}

Update database resource to safely allow SQL Server:

resource "google_sql_database" "databases" {
  for_each = var.databases

  project   = var.project_id
  instance  = google_sql_database_instance.instance.name
  name      = each.value.name
  charset   = try(each.value.charset, null)
  collation = try(each.value.collation, null)
}

Create the secrets:

echo -n 'SQLServer-R00t-2026!' | gcloud secrets create csql-sqlserver-root-password \
  --data-file=- \
  --replication-policy=automatic \
  --project=dba

echo -n 'SqlApp-User-2026!' | gcloud secrets create csql-sqlserver-app-user-password \
  --data-file=- \
  --replication-policy=automatic \
  --project=dba
#################################
##################################


#modules/google-cloud-sql/main.tf.

dynamic "backup_configuration" {
  for_each = startswith(var.database_version, "SQLSERVER") ? [1] : []

  content {
    enabled    = var.backup_configuration.enabled
    start_time = var.backup_configuration.start_time

    backup_retention_settings {
      retained_backups = var.backup_configuration.retained_backups
      retention_unit   = var.backup_configuration.retention_unit
    }
  }
}

dynamic "backup_configuration" {
  for_each = startswith(var.database_version, "MYSQL") ? [1] : []

  content {
    enabled                        = var.backup_configuration.enabled
    start_time                     = var.backup_configuration.start_time
    point_in_time_recovery_enabled = var.backup_configuration.point_in_time_recovery_enabled
    binary_log_enabled             = true

    backup_retention_settings {
      retained_backups = var.backup_configuration.retained_backups
      retention_unit   = var.backup_configuration.retention_unit
    }
  }
}

dynamic "backup_configuration" {
  for_each = startswith(var.database_version, "POSTGRES") ? [1] : []

  content {
    enabled                        = var.backup_configuration.enabled
    start_time                     = var.backup_configuration.start_time
    point_in_time_recovery_enabled = var.backup_configuration.point_in_time_recovery_enabled
    transaction_log_retention_days = var.backup_configuration.transaction_log_retention_days

    backup_retention_settings {
      retained_backups = var.backup_configuration.retained_backups
      retention_unit   = var.backup_configuration.retention_unit
    }
  }
}
