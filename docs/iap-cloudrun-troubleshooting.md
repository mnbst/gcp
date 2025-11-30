# IAP + Cloud Run + Load Balancer トラブルシューティングガイド

このドキュメントは、Cloud Run、Load Balancer、IAPを組み合わせた構成でのトラブルシューティング経験と解決策をまとめたものです。

## アーキテクチャ概要

```
[Internet] → [Cloud Load Balancer (HTTPS)] → [IAP認証] → [Backend Service] → [Cloud Run (Private)]
```

- **Cloud Run**: `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`（プライベート）
- **Load Balancer**: グローバルHTTPS Load Balancer
- **IAP**: Identity-Aware Proxy（OAuth 2.0認証）
- **SSL証明書**: Google管理証明書（nip.io または カスタムドメイン）

---

## 遭遇した問題と解決策

### 1. OAuth Brand "Already Exists" エラー

#### 問題
```
Error: Error creating Brand: googleapi: Error 409: Requested entity already exists
  with google_iap_brand.project_brand
```

#### 原因
- GCPプロジェクトには**1つのOAuth Brandしか作成できない**
- 以前のTerraform実行で作成されたBrandがまだプロジェクトに存在
- Terraform stateファイルが削除/初期化されたため、Terraformが既存リソースを認識できない
- OAuth BrandはAPIやTerraformで**削除不可**

#### 解決策

**Step 1: 既存のOAuth Brand名を取得**
```bash
gcloud iap oauth-brands list --project=<PROJECT_ID>
```

出力例：
```
name: projects/<PROJECT_NUMBER>/brands/<BRAND_ID>
applicationTitle: Go API Cloud Run
supportEmail: your-email@example.com
```

**Step 2: Terraform stateにインポート**
```bash
cd tf-go-api
terraform import google_iap_brand.project_brand projects/<PROJECT_NUMBER>/brands/<BRAND_ID>
```

**Step 3: Terraform設定を修正**

load_balancer.tf の OAuth Brand リソースで、プロジェクトIDではなく**プロジェクトNumber**を使用：

```hcl
resource "google_iap_brand" "project_brand" {
  support_email     = var.iap_support_email
  application_title = "Go API Cloud Run"
  project           = "YOUR_PROJECT_NUMBER"  # プロジェクトNumberを使用（IDではない）
}
```

**Step 4: OAuth Clientもインポート（必要に応じて）**
```bash
gcloud iap oauth-clients list projects/<PROJECT_NUMBER>/brands/<BRAND_ID>
terraform import google_iap_client.project_client projects/<PROJECT_NUMBER>/brands/<BRAND_ID>/identityAwareProxyClients/<CLIENT_ID>
```

#### 学び
- OAuth Brandリソースは慎重に扱う（削除不可）
- プロジェクトNumber（数値）とプロジェクトID（文字列）の違いに注意
- 既存リソースは必ずインポートしてから管理する

---

### 2. SSL証明書のプロビジョニング遅延

#### 問題
- カスタムドメイン（yourdomain.com）のSSL証明書が `PROVISIONING` のまま完了しない
- DNS設定とLoad Balancer IPアドレスが一致していない

#### 原因
```bash
# DNS確認
dig +short yourdomain.com
# → 198.49.23.144, 198.185.159.144 (Load Balancer IPではない)

# Load Balancer IP
terraform output load_balancer_ip
# → YOUR_LOAD_BALANCER_IP (DNSと不一致)
```

Google管理SSL証明書は、ドメインのDNSが正しくLoad Balancer IPを向いていることを確認してからプロビジョニングされます。

#### 解決策

**オプション1: DNS設定を修正**
```
A レコード: yourdomain.com → YOUR_LOAD_BALANCER_IP
```
変更後、SSL証明書のプロビジョニングに最大15分待つ。

**オプション2: nip.ioドメインに切り替え（即座にアクセス可能）**

terraform.tfvarsを変更：
```hcl
domain_name = ""  # 空にするとnip.ioを使用
```

load_balancer.tfでSSL証明書名を動的に変更：
```hcl
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
```

nip.ioドメイン（例: `YOUR_LOAD_BALANCER_IP.nip.io`）はDNS設定不要で、SSL証明書も数分でACTIVEになります。

#### 学び
- nip.ioは開発・テスト環境に最適（DNS設定不要）
- カスタムドメイン使用時はDNS設定を先に済ませる
- SSL証明書名を動的にすることで、ドメイン変更時の `create_before_destroy` が機能する

---

### 3. IAPサービスアカウント未プロビジョニングエラー

#### 問題
```
The IAP service account is not provisioned.
Please follow the instructions to create service account and rectify IAP and Cloud Run setup
```

ブラウザでアクセスしても、このエラーメッセージが表示される。

#### 原因分析

**確認1: IAP設定**
```bash
gcloud compute backend-services describe go-api-backend --global --format="yaml(iap)"
```
結果: IAP有効化されている ✓

**確認2: IAP API**
```bash
gcloud services list --enabled --filter="name:iap"
```
結果: iap.googleapis.com 有効 ✓

**確認3: サービスアカウント**
```bash
gcloud iam service-accounts list --filter="email:iap"
```
結果: **IAPサービスアカウントが存在しない** ✗

**根本原因:**
- TerraformでIAPを有効化しただけでは、IAPサービスアカウント（`service-PROJECT_NUMBER@gcp-sa-iap.iam.gserviceaccount.com`）は自動作成されない
- このサービスアカウントは、GCP Consoleから初めてIAPを有効化したときに作成される
- または、明示的にプロビジョニングする必要がある

#### 解決策

**Step 1: IAPサービスアカウントを手動作成**
```bash
gcloud beta services identity create --service=iap.googleapis.com --project=<PROJECT_ID>
```

出力:
```
Service identity created: service-<PROJECT_NUMBER>@gcp-sa-iap.iam.gserviceaccount.com
```

**Step 2: Terraform設定を更新**

main.tfに以下を追加：
```hcl
# IAPサービスアカウントに権限を付与
resource "google_cloud_run_v2_service_iam_member" "iap_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.go_api.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-<PROJECT_NUMBER>@gcp-sa-iap.iam.gserviceaccount.com"
}

# Compute Engineデフォルトサービスアカウントにも権限を付与
resource "google_cloud_run_v2_service_iam_member" "lb_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.go_api.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:<PROJECT_NUMBER>-compute@developer.gserviceaccount.com"
}
```

**Step 3: 適用**
```bash
terraform apply
```

#### 試行錯誤した他のアプローチ

**失敗1: `allUsers` を使用**
```hcl
member = "allUsers"
```
エラー: 組織ポリシーにより `allUsers` の使用が制限されている

**失敗2: IAPサービスアカウントのみ**

最初はCompute Engineサービスアカウントの権限が不要と考えたが、両方必要だった。

#### 学び
- **IAPサービスアカウントは手動でプロビジョニングが必要**（Terraformでは自動作成されない）
- `gcloud beta services identity create` で明示的に作成
- Cloud Run IAM権限として、**IAPサービスアカウント**と**Compute Engineサービスアカウント**の両方に `roles/run.invoker` を付与
- 組織ポリシーにより `allUsers` や `allAuthenticatedUsers` が使用できない場合がある

---

## ベストプラクティス

### 1. Terraform State管理

- **絶対にstateファイルを削除しない**
- リモートバックエンド（GCS、S3等）を使用してstateを保存
- 既存リソースは必ず `terraform import` でインポート
- OAuth BrandなどのAPI削除不可リソースは特に注意

### 2. IAP + Cloud Run構成

**必須の設定:**

1. Cloud Runのingress設定
   ```hcl
   ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
   ```

2. IAPサービスアカウントのプロビジョニング
   ```bash
   gcloud beta services identity create --service=iap.googleapis.com
   ```

3. 2つのサービスアカウントに権限付与
   - `service-PROJECT_NUMBER@gcp-sa-iap.iam.gserviceaccount.com`
   - `PROJECT_NUMBER-compute@developer.gserviceaccount.com`

4. IAP Backend Service設定
   ```hcl
   iap {
     enabled              = true
     oauth2_client_id     = google_iap_client.project_client.client_id
     oauth2_client_secret = google_iap_client.project_client.secret
   }
   ```

### 3. SSL証明書管理

- 開発環境: nip.ioドメインを使用（DNS不要、即座にACTIVE）
- 本番環境: カスタムドメインを使用（事前にDNS設定）
- 証明書名を動的にして `create_before_destroy` を有効化

```hcl
resource "google_compute_managed_ssl_certificate" "api_cert" {
  name = var.domain_name != "" ? "cert-custom" : "cert-nipio"

  lifecycle {
    create_before_destroy = true
  }
}
```

### 4. トラブルシューティング手順

**問題発生時のチェックリスト:**

1. SSL証明書のステータス確認
   ```bash
   gcloud compute ssl-certificates describe <CERT_NAME> --global \
     --format="value(managed.status, managed.domainStatus)"
   ```

2. IAP設定確認
   ```bash
   gcloud compute backend-services describe <BACKEND_NAME> --global \
     --format="yaml(iap)"
   ```

3. サービスアカウント存在確認
   ```bash
   gcloud iam service-accounts list --filter="email:iap"
   ```

4. Cloud Run IAM権限確認
   ```bash
   gcloud run services get-iam-policy <SERVICE_NAME> \
     --region=<REGION>
   ```

5. Load Balancerログ確認
   ```bash
   gcloud logging read "resource.type=http_load_balancer" \
     --limit=50 --format=json
   ```

---

## まとめ

### 重要な学び

1. **OAuth Brandは削除不可** → インポートして管理
2. **IAPサービスアカウントは手動プロビジョニング** → Terraformだけでは不十分
3. **2つのサービスアカウントが必要** → IAPとCompute Engine
4. **プロジェクトNumberとIDの違い** → OAuth BrandはプロジェクトNumberを使用
5. **nip.ioは開発に最適** → DNS不要、SSL証明書が即座にACTIVE
6. **組織ポリシーに注意** → `allUsers` が使用できない場合がある

### 推奨される構築手順

1. VPCネットワークとサブネット作成
2. Cloud Runサービス作成（Private ingress）
3. IAP API有効化
4. **IAPサービスアカウント手動作成** ← 重要！
5. OAuth Brand/Client作成（または既存をインポート）
6. SSL証明書作成（nip.ioから始める）
7. Load Balancer + Backend Service作成（IAP有効化）
8. Cloud Run IAM権限設定（2つのサービスアカウント）
9. アクセステスト
10. 本番環境用にカスタムドメインへ移行

### 参考リンク

- [Enabling IAP for Cloud Run](https://cloud.google.com/iap/docs/enabling-cloud-run)
- [Managing SSL certificates](https://cloud.google.com/load-balancing/docs/ssl-certificates)
- [Cloud Run IAM permissions](https://cloud.google.com/run/docs/reference/iam/roles)
