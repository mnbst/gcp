# ============================================
# Cloud Load Balancer + IAP 設定
# ============================================

# 静的IPアドレス（グローバル）
resource "google_compute_global_address" "lb_ip" {
  name = "go-api-lb-ip"
}

# Serverless NEG (Network Endpoint Group)
# Cloud RunをLoad Balancerのバックエンドとして登録
resource "google_compute_region_network_endpoint_group" "cloudrun_neg" {
  name                  = "go-api-cloudrun-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.go_api.name
  }
}

# Backend Service
# IAP設定をここに含める
resource "google_compute_backend_service" "api_backend" {
  name                  = "go-api-backend"
  protocol              = "HTTPS"
  port_name             = "http"
  timeout_sec           = 30
  enable_cdn            = false
  load_balancing_scheme = "EXTERNAL_MANAGED"

  # IAP設定
  iap {
    enabled              = true
    oauth2_client_id     = google_iap_client.project_client.client_id
    oauth2_client_secret = google_iap_client.project_client.secret
  }

  backend {
    group = google_compute_region_network_endpoint_group.cloudrun_neg.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# URL Map
# HTTPSリクエストをBackend Serviceにルーティング
resource "google_compute_url_map" "api_url_map" {
  name            = "go-api-url-map"
  default_service = google_compute_backend_service.api_backend.id
}

# SSL証明書（Google管理）
resource "google_compute_managed_ssl_certificate" "api_cert" {
  # ドメインが変わるたびに新しい証明書を作成できるように、動的な名前を使用
  name = var.domain_name != "" ? "go-api-cert-custom" : "go-api-cert-nipio"

  managed {
    domains = var.domain_name != "" ? [var.domain_name] : ["${google_compute_global_address.lb_ip.address}.nip.io"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Target HTTPS Proxy
resource "google_compute_target_https_proxy" "api_https_proxy" {
  name             = "go-api-https-proxy"
  url_map          = google_compute_url_map.api_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.api_cert.id]
}

# Global Forwarding Rule
# 外部からのHTTPSトラフィックを受け付ける
resource "google_compute_global_forwarding_rule" "api_forwarding_rule" {
  name                  = "go-api-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.api_https_proxy.id
  ip_address            = google_compute_global_address.lb_ip.id
}

# HTTP to HTTPS リダイレクト用のURL Map
resource "google_compute_url_map" "api_http_redirect" {
  name = "go-api-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# Target HTTP Proxy（リダイレクト用）
resource "google_compute_target_http_proxy" "api_http_proxy" {
  name    = "go-api-http-proxy"
  url_map = google_compute_url_map.api_http_redirect.id
}

# HTTP Forwarding Rule（リダイレクト用）
resource "google_compute_global_forwarding_rule" "api_http_forwarding_rule" {
  name                  = "go-api-http-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.api_http_proxy.id
  ip_address            = google_compute_global_address.lb_ip.id
}

# ============================================
# IAP (Identity-Aware Proxy) 設定
# ============================================

# OAuth Brand（OAuth同意画面）
resource "google_iap_brand" "project_brand" {
  support_email     = var.iap_support_email
  application_title = "Go API Cloud Run"
  project           = data.google_project.project.number  # プロジェクトNumberを動的に取得
}

# OAuth Client
resource "google_iap_client" "project_client" {
  display_name = "IAP Client for Go API"
  brand        = google_iap_brand.project_brand.name
}

# IAP Web バックエンドサービスへのアクセス権限
resource "google_iap_web_backend_service_iam_binding" "iap_binding" {
  project             = var.project_id
  web_backend_service = google_compute_backend_service.api_backend.name
  role                = "roles/iap.httpsResourceAccessor"
  members             = var.authorized_members
}

# ============================================
# Outputs
# ============================================

output "load_balancer_ip" {
  description = "Load Balancer IP address"
  value       = google_compute_global_address.lb_ip.address
}

output "load_balancer_url" {
  description = "Load Balancer URL"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "https://${google_compute_global_address.lb_ip.address}.nip.io"
}

output "oauth_client_id" {
  description = "OAuth Client ID for IAP"
  value       = google_iap_client.project_client.client_id
  sensitive   = true
}
