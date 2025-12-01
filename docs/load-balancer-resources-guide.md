# Load Balancer リソース解説ガイド

このドキュメントは、`tf-go-api/load_balancer.tf`で定義されている各リソースの要点をまとめたものです。

## 📋 リソース一覧

| # | リソース名 | 役割 |
|---|-----------|------|
| 1 | 静的IPアドレス | Load BalancerのグローバルパブリックIP |
| 2 | Serverless NEG | Cloud RunとLoad Balancerの橋渡し |
| 3 | Backend Service | トラフィック処理、IAP、ログの中核 |
| 4 | URL Map | URLルーティングテーブル |
| 5 | SSL証明書 | HTTPS用の自動管理証明書 |
| 6 | Target HTTPS Proxy | SSL終端とHTTPSプロトコル処理 |
| 7 | HTTPS Forwarding Rule | ポート443の玄関口 |
| 8 | HTTP→HTTPSリダイレクト | HTTP(80)を自動的にHTTPS(443)へ |
| 9 | IAP設定 | Google認証とアクセス制御 |

---

## 1. 静的IPアドレス (`google_compute_global_address`)

```hcl
resource "google_compute_global_address" "lb_ip" {
  name = "go-api-lb-ip"
}
```

**要点:**
- グローバル静的IPアドレスを予約
- DNS設定やnip.ioで使用
- 削除するまで同じIPを保持
- 使用中は無料、未使用で課金

---

## 2. Serverless NEG (`google_compute_region_network_endpoint_group`)

```hcl
resource "google_compute_region_network_endpoint_group" "cloudrun_neg" {
  name                  = "go-api-cloudrun-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"
  cloud_run {
    service = google_cloud_run_v2_service.go_api.name
  }
}
```

**要点:**
- Cloud RunをLoad Balancerに接続する橋渡し役
- `SERVERLESS`タイプでサーバレスサービス専用
- リージョナルリソース（Cloud Runと同じリージョン）

**データフロー:**
```
Load Balancer → NEG → Cloud Run
```

---

## 3. Backend Service (`google_compute_backend_service`)

```hcl
resource "google_compute_backend_service" "api_backend" {
  name                  = "go-api-backend"
  protocol              = "HTTPS"
  timeout_sec           = 30
  enable_cdn            = false
  load_balancing_scheme = "EXTERNAL_MANAGED"

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
    sample_rate = 1.0  # 100%ログ記録
  }
}
```

**要点:**
- Load Balancerの中核コンポーネント
- **IAP認証**をここで有効化（OAuth2）
- タイムアウト30秒（Cloud Runが応答しないと504エラー）
- ログを100%サンプリング
- CDN無効（APIは通常不要）

**処理フロー:**
```
リクエスト → IAPチェック → NEG経由でCloud Run → ログ記録
```

---

## 4. URL Map (`google_compute_url_map`)

```hcl
resource "google_compute_url_map" "api_url_map" {
  name            = "go-api-url-map"
  default_service = google_compute_backend_service.api_backend.id
}
```

**要点:**
- URLパスに基づくルーティングテーブル
- 現在はシンプル構成（全トラフィックを`api_backend`へ）
- 将来的に複数バックエンドへの振り分けも可能

**現在の動作:**
```
すべてのリクエスト → api_backend
```

---

## 5. SSL証明書 (`google_compute_managed_ssl_certificate`)

```hcl
resource "google_compute_managed_ssl_certificate" "api_cert" {
  name = var.domain_name != "" ? "go-api-cert-custom" : "go-api-cert-nipio"
  managed {
    domains = var.domain_name != "" ? [var.domain_name] : ["${google_compute_global_address.lb_ip.address}.nip.io"]
  }
  lifecycle {
    create_before_destroy = true
  }
}
```

**要点:**
- Google管理の自動SSL証明書
- カスタムドメインまたはnip.ioに対応
- プロビジョニングに5-15分かかる
- 90日ごとに自動更新

**nip.ioとは:**
```
34.120.45.67.nip.io → 34.120.45.67 に自動DNS解決
DNS設定不要で即座に使用可能
```

**証明書ステータス:**
```
terraform apply → PROVISIONING (5-15分) → ACTIVE
```

---

## 6. Target HTTPS Proxy (`google_compute_target_https_proxy`)

```hcl
resource "google_compute_target_https_proxy" "api_https_proxy" {
  name             = "go-api-https-proxy"
  url_map          = google_compute_url_map.api_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.api_cert.id]
}
```

**要点:**
- SSL/TLS終端を実行
- HTTPSを復号化してURL Mapにルーティング
- 証明書の提示

**SSL終端フロー:**
```
クライアント(HTTPS) → Proxy(SSL終端) → URL Map(HTTP/HTTPS)
```

---

## 7. HTTPS Forwarding Rule (`google_compute_global_forwarding_rule`)

```hcl
resource "google_compute_global_forwarding_rule" "api_forwarding_rule" {
  name                  = "go-api-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.api_https_proxy.id
  ip_address            = google_compute_global_address.lb_ip.id
}
```

**要点:**
- Load Balancerの「玄関口」
- ポート443（HTTPS）でリッスン
- 静的IPアドレスにバインド
- Target HTTPS Proxyに転送

**データフロー:**
```
インターネット → 静的IP:443 → Forwarding Rule → HTTPS Proxy
```

---

## 8. HTTP→HTTPSリダイレクト (3つのリソース)

### 8-1. リダイレクト用URL Map

```hcl
resource "google_compute_url_map" "api_http_redirect" {
  name = "go-api-http-redirect"
  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"  # 301
    strip_query            = false
  }
}
```

### 8-2. Target HTTP Proxy

```hcl
resource "google_compute_target_http_proxy" "api_http_proxy" {
  name    = "go-api-http-proxy"
  url_map = google_compute_url_map.api_http_redirect.id
}
```

### 8-3. HTTP Forwarding Rule

```hcl
resource "google_compute_global_forwarding_rule" "api_http_forwarding_rule" {
  name                  = "go-api-http-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.api_http_proxy.id
  ip_address            = google_compute_global_address.lb_ip.id
}
```

**要点:**
- HTTPアクセスを自動的にHTTPSへリダイレクト
- 301（恒久的移動）ステータスコード
- クエリパラメータを保持
- 同じ静的IPでポート80と443を両方リッスン

**リダイレクトフロー:**
```
http://example.com/ (80)
  ↓
HTTP Forwarding Rule → HTTP Proxy → Redirect URL Map
  ↓
301: Location: https://example.com/
  ↓
ブラウザがHTTPSで再リクエスト
```

---

## 9. IAP関連リソース (3つのリソース)

### 9-1. OAuth Brand

```hcl
resource "google_iap_brand" "project_brand" {
  support_email     = var.iap_support_email
  application_title = "Go API Cloud Run"
  project           = data.google_project.project.number
}
```

**要点:**
- OAuth同意画面のブランディング設定
- サポートメールとアプリ名を表示

### 9-2. OAuth Client

```hcl
resource "google_iap_client" "project_client" {
  display_name = "IAP Client for Go API"
  brand        = google_iap_brand.project_brand.name
}
```

**要点:**
- OAuth2認証フローのクライアント資格情報
- Client IDとSecretを自動生成
- Backend ServiceのIAP設定で使用

### 9-3. IAP IAM Binding

```hcl
resource "google_iap_web_backend_service_iam_binding" "iap_binding" {
  project             = var.project_id
  web_backend_service = google_compute_backend_service.api_backend.name
  role                = "roles/iap.httpsResourceAccessor"
  members             = var.authorized_members
}
```

**要点:**
- 誰がアクセスできるかを制御
- `authorized_members`に含まれるユーザー/グループのみアクセス可能
- `roles/iap.httpsResourceAccessor`が必須

**認証フロー:**
```
1. ユーザーアクセス
2. IAP: Googleログイン要求
3. ユーザー: ログイン
4. IAP: authorized_membersチェック
5a. 含まれる → Cloud Runへ転送
5b. 含まれない → 403 Forbidden
```

---

## 🔄 完全なデータフロー

```
インターネット
  ↓
┌─────────────────┬─────────────────┐
│  HTTP (80)      │  HTTPS (443)    │
└────────┬────────┴────────┬────────┘
         │                 │
    [HTTP FR]         [HTTPS FR]
         │                 │
   [HTTP Proxy]      [HTTPS Proxy]
         │              ↓ SSL終端
         │          [SSL証明書]
         │                 │
   [Redirect Map]     [URL Map]
         │                 │
         └────→ 301 ───────┤
                           ↓
                   [Backend Service]
                           ↓
                     IAP認証チェック
                     - OAuth Brand
                     - OAuth Client
                     - authorized_members
                           ↓
                   [Serverless NEG]
                           ↓
                      Cloud Run
```

---

## 📝 リソース依存関係

```
lb_ip (静的IP)
  ├─→ api_cert (SSL証明書) ... ドメイン名生成
  ├─→ HTTPS Forwarding Rule
  └─→ HTTP Forwarding Rule

project_brand (OAuth Brand)
  └─→ project_client (OAuth Client)
       └─→ api_backend (Backend Service) ... IAP設定

cloudrun_neg (Serverless NEG)
  └─→ api_backend (Backend Service)
       └─→ api_url_map (URL Map)
            └─→ api_https_proxy (HTTPS Proxy)
                 └─→ HTTPS Forwarding Rule
```

---

## ⚙️ 主要な設定値

| 項目 | 設定値 | 場所 |
|-----|--------|------|
| **SSL証明書** | Google管理、自動更新 | api_cert |
| **認証方式** | IAP + OAuth2 | Backend Service |
| **アクセス制御** | authorized_members | IAM Binding |
| **ログ記録** | 100%サンプリング | Backend Service |
| **タイムアウト** | 30秒 | Backend Service |
| **CDN** | 無効 | Backend Service |
| **HTTPリダイレクト** | 301恒久的 | HTTP URL Map |
| **ポート** | 80 (HTTP), 443 (HTTPS) | Forwarding Rules |

---

## 🔐 セキュリティポイント

1. **Cloud Runは内部専用**
   - `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`
   - Load Balancer経由でのみアクセス可能

2. **IAP認証必須**
   - Backend ServiceレベルでIAP有効化
   - Googleアカウント認証が必須

3. **アクセス制御**
   - `authorized_members`で明示的に許可
   - Google GroupやユーザーメールでACL管理

4. **全通信HTTPS化**
   - HTTPは自動的にHTTPSへリダイレクト
   - SSL/TLS終端はLoad Balancerで実施

5. **監査ログ**
   - 100%のリクエストをログ記録
   - Cloud Loggingで確認可能

---

## 🚀 デプロイ時の注意点

1. **SSL証明書のプロビジョニング**
   - 初回デプロイ時は5-15分待機
   - ステータス確認: `gcloud compute ssl-certificates list`

2. **IAPサービスアカウント**
   - 手動プロビジョニングが必要:
     ```bash
     gcloud beta services identity create --service=iap.googleapis.com --project=YOUR_PROJECT_ID
     ```

3. **authorized_membersの設定**
   - `terraform.tfvars`で必ず設定
   - 空の場合は誰もアクセスできない

4. **静的IP**
   - 削除前に確認（DNSやドキュメントで使用中の可能性）

---

## 📚 関連ドキュメント

- [IAP + Cloud Run トラブルシューティングガイド](iap-cloudrun-troubleshooting.md)
- [Cloud Identity セットアップガイド](cloud-identity-setup.md)
- [Artifact Registry プッシュガイド](artifact-registry-push-guide.md)

---

## ⚠️ 注意事項

このドキュメントで使用されているプレースホルダーは、実際の環境に合わせて置き換えてください。

詳細は[README.md](README.md)を参照してください。
