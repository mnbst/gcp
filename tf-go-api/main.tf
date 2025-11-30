# Artifact Registry リポジトリ（tf-app）を1つ作る
resource "google_artifact_registry_repository" "tf_app" {
  repository_id = "tf-app"
  format        = "DOCKER"
  location      = var.region
  description   = "Terraform-managed repo for Go API"
}

resource "google_vpc_access_connector" "serverless" {
  name    = "tf-go-api-conn"
  region  = var.region
  network = google_compute_network.main.name

  # コネクタ用の /28 CIDR（他と被らないレンジを選ぶ）
  ip_cidr_range = "10.8.0.0/28"

  min_instances = 2
  max_instances = 3
}

# Cloud Run に使うサービスアカウント（最小）
resource "google_service_account" "go_api" {
  account_id   = "go-api-sa"
  display_name = "Service Account for Go API Cloud Run"
}

# Cloud Run (v2) サービス
resource "google_cloud_run_v2_service" "go_api" {
  name                = "go-api-tf"
  location            = var.region
  deletion_protection = false

  # Load Balancer経由のみアクセス可能に変更
  # インターネットから直接アクセスは不可（Load Balancer経由のみ）
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = google_service_account.go_api.email

    # 🔹 VPC Connector 経由で VPC に出る設定
    vpc_access {
      connector = google_vpc_access_connector.serverless.id
      # or "ALL_TRAFFIC" / "PRIVATE_RANGES_ONLY"
      egress = "ALL_TRAFFIC"
    }

    containers {
      # ここは「すでに push 済みのイメージ」を指定する想定
      # → 後で gcloud builds submit のタグをここに合わせる
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.tf_app.repository_id}/go-api:latest"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
      }
    }

    max_instance_request_concurrency = 80
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# Cloud Run IAM認証
# Load Balancer（IAP保護済み）がCloud Runを呼び出すための権限

# IAPサービスアカウントに権限を付与
resource "google_cloud_run_v2_service_iam_member" "iap_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.go_api.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-454871423104@gcp-sa-iap.iam.gserviceaccount.com"
}

# Compute Engineデフォルトサービスアカウントにも権限を付与（Load Balancer用）
resource "google_cloud_run_v2_service_iam_member" "lb_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.go_api.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:454871423104-compute@developer.gserviceaccount.com"
}

# VPC ネットワーク
resource "google_compute_network" "main" {
  name                    = "tf-go-api-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = "tf-go-api-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.main.id
}

resource "google_project_iam_audit_config" "enable_data_access_logs" {
  project = var.project_id
  service = "run.googleapis.com"
  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
