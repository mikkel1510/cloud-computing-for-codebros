provider "google" {
    project = "cloudbros"
    region = "europe-west1"
}

# -------------------------------------------
# CLOUD SQL
# -------------------------------------------

resource "google_sql_database" "database" {
  name     = "the-sql"
  instance = google_sql_database_instance.instance.name
}

resource "google_sql_database_instance" "instance" {
  name             = "the-datterbasse-instance"
  region           = "europe-west1"
  database_version = "MYSQL_8_0"
  settings {
    tier = "db-f1-micro"
  }

  deletion_protection  = false
}

resource "google_sql_user" "db_user" {
    name     = "appuser"
    instance = google_sql_database_instance.instance.name
    password = "your-password"

    depends_on = [
        google_sql_database_instance.instance
    ]
}


# -------------------------------------------
# BACKEND SERVICE
# -------------------------------------------
resource "google_cloud_run_service" "backend" {
    name = "backend-run"
    location = "europe-west1"

    template {
        spec {
            containers {
                image = "europe-west1-docker.pkg.dev/cloudbros/backend-repo/backend:latest"

                env {
                    name = "DB_NAME"
                    value = google_sql_database.database.name
                }
                env {
                    name = "INSTANCE_CONNECTION_NAME"
                    value = google_sql_database_instance.instance.connection_name
                }
                env {
                    name = "DB_USER"
                    value = google_sql_user.db_user.name
                }
                env {
                    name = "DB_PASS"
                    value = google_sql_user.db_user.password
                }
            }

        }

        metadata {
            annotations = {
                "autoscaling.knative.dev/maxScale" = "200"
                "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.instance.connection_name
                "run.googleapis.com/client-name"        = "terraform"
            }
        }
    }

    traffic {
        percent = 100
        latest_revision = true
    }
}

# -------------------------------------------
# FRONTEND SERVICE
# -------------------------------------------
resource "google_cloud_run_service" "frontend" {
    name = "frontend-run"
    location = "europe-west1"

    template {
        spec {
            containers {
                image = "europe-west1-docker.pkg.dev/cloudbros/frontend-repo/frontend:latest"

                env {
                    name = "API_ADDRESS"
                    value = google_cloud_run_service.backend.status[0].url
                }
            }
        }
    }

    traffic {
        percent         = 100
        latest_revision = true
    }
}

# ---------------------------------------
# Outputs
# ---------------------------------------
output "frontend_url" {
  value = google_cloud_run_service.frontend.status[0].url
}

output "backend_url" {
  value = google_cloud_run_service.backend.status[0].url
}

output "db_connection_name" {
  value = google_sql_database_instance.instance.connection_name
}