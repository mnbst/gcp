# Cloud Run × Terraform サーバレスアーキテクチャ構築例

このリポジトリは、Google Cloud を用いて
**本番運用を想定したサーバレス API アーキテクチャ**を構築した事例です。

Go言語によるシンプルなAPIとTerraformによるIaCで、

- **フルマネージド**
- **スケーラブル**
- **セキュア**
- **インフラのコード化**
- **再現性の高いデプロイ**

を実現しています。

---

## 🧩 Architecture (全体構成)

```markdown
[Internet] → [Cloud Load Balancer + IAP] → [Cloud Run (Private)] → [VPC Network]
                       │
                       └→ [Artifact Registry / Cloud Logging]
```

- **Cloud Load Balancer**: グローバルHTTPS ロードバランサー
- **IAP**: Identity-Aware Proxy（Google認証＋アクセス制御）
- **Cloud Run**: Goアプリケーションをコンテナ実行（Private）
- **VPC Connector**: Cloud RunからVPCへのプライベート接続
- **Artifact Registry**: Dockerイメージの管理
- **Terraform**: インフラ全体をコード管理


---

## 🏗 構成技術

| Layer | Service | Notes |
|-------|----------|-------|
| Language | Go 1.25 | 軽量・高速なAPIサーバ |
| Container | Docker | マルチステージビルド |
| Compute | Cloud Run (v2) | コンテナ実行、水平スケール |
| Load Balancer | Cloud Load Balancer | グローバルHTTPS LB |
| Security | Identity-Aware Proxy (IAP) | Google認証＋アクセス制御 |
| Registry | Artifact Registry | Dockerイメージ管理 |
| Network | VPC / VPC Connector | プライベートネットワーク接続 |
| IaC | Terraform | インフラ全体をコード管理 |
| Build | Cloud Build | コンテナイメージのビルド |

---

## 🎯 この構成で実現していること

### 1. **完全サーバレス**
- VM管理なし
- 自動スケール
- リクエストに応じて課金

### 2. **Terraform によるインフラ管理**
- すべてのリソースをコード化
- 再現性の高いデプロイ
- バージョン管理可能

### 3. **コンテナベースのデプロイ**
- Dockerマルチステージビルドで最小化
- Artifact Registryで一元管理
- Cloud Buildによる自動ビルド

### 4. **VPC統合**
- VPC Connectorによるプライベート接続
- 将来的なCloud SQL等への接続に対応
- セキュアなネットワーク設計

### 5. **シンプルで拡張可能な設計**
- GoによるシンプルなAPI実装
- 段階的な機能追加が可能
- 本番運用を見据えた構成

---

## 📦 API 概要

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Hello メッセージ |
| GET | `/health` | ヘルスチェック |

---

## 🔧 使用技術（アプリ側）

- Go 1.25
- net/http (標準ライブラリ)
- Docker (マルチステージビルド)
- distroless/base-debian12 (実行環境)

---

## 🛠 ローカル動作（Docker）

```bash
cd go-api
docker build -t go-api .
docker run -p 8080:8080 go-api

# 動作確認
curl http://localhost:8080/
curl http://localhost:8080/health
```


---

## 🚀 デプロイ手順

### 1. Dockerイメージのビルド & プッシュ

```bash
cd go-api

# プロジェクトID と リージョンを設定
export PROJECT_ID=your-project-id
export REGION=asia-northeast1

# Cloud Build でイメージをビルド & Artifact Registry にプッシュ
gcloud builds submit --tag ${REGION}-docker.pkg.dev/${PROJECT_ID}/tf-app/go-api:latest
```

### 2. Terraform でインフラ構築

```bash
cd ../tf-go-api

# terraform.tfvars を作成・編集
# project_id = "your-project-id"
# authorized_members = ["user:your-email@example.com"]

# 初期化
terraform init

# プラン確認
terraform plan

# 適用
terraform apply
```

### 3. Load Balancer URLを取得してアクセス

```bash
# Load Balancer URLを取得
terraform output load_balancer_url

# ブラウザでアクセス
# https://34.xxx.xxx.xxx.nip.io

# ※ SSL証明書のプロビジョニングに最大15分かかります
```

> **注意**: このAPIはIAP（Identity-Aware Proxy）で保護されています。ブラウザでアクセスすると、Google認証画面が表示されます。`terraform.tfvars` の `authorized_members`（Google Group）に登録されたユーザーのみアクセス可能です。


---

## 🧪 構築済み内容

- ✅ Go API の実装 (net/http)
- ✅ Dockerfile のマルチステージビルド
- ✅ Artifact Registry リポジトリ作成
- ✅ Cloud Run (v2) デプロイ（Private）
- ✅ Cloud Load Balancer（グローバルHTTPS LB）
- ✅ Identity-Aware Proxy（IAP）統合
- ✅ VPC ネットワーク構築
- ✅ VPC Connector 設定
- ✅ Terraform による IaC 化
- ✅ サービスアカウント設定
- ✅ Google Workspace / Google Groups連携

---

## 🔐 セキュリティ設計

- **Identity-Aware Proxy (IAP)**: Google認証による多層防御
- **Cloud Run Private**: インターネットから直接アクセス不可
- **Google Groups連携**: グループベースのアクセス制御
- **HTTPS強制**: Google管理SSL証明書
- **サービスアカウント分離**: Cloud Run専用のサービスアカウント
- **VPC統合**: プライベートネットワークによる通信分離
- **Cloud Audit Logs**: すべてのアクセスを記録

詳細は以下を参照：
- [IAPデプロイメントガイド](docs/iap-deployment-guide.md)
- [アーキテクチャ比較](docs/iap-architecture-comparison.md)

---

## 📊 モニタリング

- Cloud Logging による自動ログ収集
- Cloud Run のビルトインメトリクス
  - リクエスト数
  - レイテンシ
  - エラー率
- 将来的な Cloud Monitoring ダッシュボード追加予定

---

## 📁 ディレクトリ構成

```bash
.
├── go-api/              # Go API アプリケーション
│   ├── main.go          # APIサーバ実装
│   ├── Dockerfile       # マルチステージビルド
│   └── go.mod           # Go モジュール定義
│
├── tf-go-api/           # Terraform インフラ定義
│   ├── main.tf          # メインリソース定義
│   ├── providers.tf     # プロバイダ設定
│   ├── variable.tf      # 変数定義
│   └── terraform.tfvars # 変数値 (gitignore)
│
├── .gitignore
├── LICENSE
└── README.md
```


---

## 🎓 学習目的 & 背景

**「本番運用に耐えうる構成を自力で構築できる」**
ことを目標に、以下を実践：

- Go によるシンプルなAPI実装
- Docker コンテナ化とマルチステージビルド
- Terraform による IaC の実践
- Cloud Run のサーバレス活用
- VPC ネットワークの構築と統合
- 段階的な機能拡張が可能な設計

---

## 📌 この構成で得た知見

- **Terraform で IaC を実践すると再現性が高い**
  - リソースの依存関係を明確化できる
  - コードレビューで設計を共有しやすい

- **Go + distroless でコンテナサイズを最小化**
  - マルチステージビルドで効率的
  - セキュリティリスクを低減

- **Cloud Run は VPC 統合が可能**
  - VPC Connector で柔軟なネットワーク設計
  - 将来的な Cloud SQL 接続に対応可能

- **段階的な構築が重要**
  - まずシンプルに動かす
  - 必要に応じて機能を追加

---

## 🔜 今後の改善予定

- [ ] Cloud SQL (PostgreSQL) との統合
- [ ] Secret Manager による認証情報管理
- [ ] API Gateway の追加
- [ ] Cloud Monitoring ダッシュボード作成
- [ ] CI/CD パイプライン構築 (Cloud Build)
- [ ] ログの構造化と Error Reporting 統合
- [ ] 負荷テストと性能測定
- [ ] マルチリージョン対応

---

## 📝 ライセンス
MIT

