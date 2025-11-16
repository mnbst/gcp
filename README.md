# Cloud Run × API Gateway × Cloud SQL サーバレスアーキテクチャ構築例

このリポジトリは、Google Cloud を用いて
**本番運用を想定したサーバレス API アーキテクチャ**を構築した事例です。

Cloud Run、API Gateway、Cloud SQL を中心とした構成により、

- **フルマネージド**
- **スケーラブル**
- **セキュア**
- **運用コスト最小**
- **ログと監視が組み込まれた状態**

を実現しています。

---

## 🧩 Architecture (全体構成)

```markdown
[Client] → [API Gateway] → [Cloud Run Container] → [Cloud SQL (PostgreSQL)]
│
└→ [Cloud Logging / Error Reporting / Metrics]
```


---

## 🏗 構成技術

| Layer | Service | Notes |
|-------|----------|-------|
| Entry | API Gateway | 認証 & ルーティング |
| Compute | Cloud Run | コンテナ実行、水平スケール |
| Database | Cloud SQL | 永続データ管理 |
| Secrets | Secret Manager | DB接続情報の暗号化管理 |
| Network | VPC / Serverless.connector | Private IP接続 |
| Monitoring | Cloud Monitoring | p95レイテンシ監視 |
| Logging | Cloud Logging | 構造化ログ、エラー収集 |
| IaC | Terraform | 再現性・自動構築 |

---

## 🎯 この構成で実現していること

### 1. **完全サーバレス**
- VM管理なし
- 自動スケール
- リクエストに応じて課金

### 2. **セキュアな通信設計**
- Cloud Runは外部公開せず
- API Gateway経由のみアクセス可能
- Cloud SQLはPrivate IP接続
- Secret Managerで認証情報管理

### 3. **可観測性の組み込み**
- 構造化ログ出力（JSON）
- Cloud Logging × Error Reporting
- Cloud Monitoring による
  - p50/p95/p99 レイテンシ測定
  - アラート設定

### 4. **DB接続の安定化**
- Cloud SQL Auth Proxy
- 同時接続数チューニング
- バックオフリトライ

### 5. **Terraform による IaC**
- module構成
- GCS backendで state 管理
- CI/CD（plan → validate → apply）

---

## 📦 API 概要

| Method | Path | Description |
|--------|------|-------------|
| GET | `/items` | データ一覧取得 |
| GET | `/items/{id}` | 単一データ取得 |
| POST | `/items` | データ登録 |

---

## 🔧 使用技術（アプリ側）

- Python 3.11
- FastAPI
- SQLAlchemy
- psycopg2
- uvicorn
- google-cloud-logging

---

## 🛠 ローカル動作（Docker）

```bash
docker build -t app .
docker run -p 8080:8080 app
```


---

## 🚀 デプロイ手順（Terraform 版は別リポジトリ）

```bash
gcloud builds submit --tag gcr.io/$PROJECT_ID/app
gcloud run deploy app
--image gcr.io/$PROJECT_ID/app
--allow-unauthenticated=false
```


---

## 🧪 性能検証

- 同時リクエスト 200
- コールドスタート対策済
- p95 レイテンシ：**230ms**
- スケールアウト確認済

---

## 🔐 セキュリティ設計

- IAM：最小権限（Least Privilege）
- サービスアカウント分離
- API Key or IAM Auth による認証
- Private IP 接続
- Secrets は Secret Manager 管理

---

## 📊 モニタリング

- Cloud Monitoring ダッシュボード作成済
- メトリクス：
  - request_count
  - latency_p95
  - error_ratio
- Error Reporting 自動収集

---

## 📁 ディレクトリ構成

```bash
.
├── app/ # FastAPI ソース
├── Dockerfile
├── requirements.txt
├── cloudrun.yaml
└── README.md
```

Terraformは別リポジトリに分離：

terraform/
├── main.tf
├── modules/
│ ├── cloudrun
│ ├── cloudsql
│ ├── apigateway
│ └── network
└── README.md


---

## 🎓 学習目的 & 背景

クラウド実務経験はありませんが、
**「本番運用に耐えうる構成を自力で構築できる」**
ことを目標に以下を意識しました：

- 運用自動化
- セキュアな接続設計
- サーバレスによる拡張性
- ログ・監視による可観測性
- Terraform による再現性

---

## 📌 この構成で得た知見

- サーバレス構成でもネットワーク設計は重要
- Cloud SQL 接続は最適化しないとボトルネック化
- Cloud Run の同時実行数は性能に直結
- Logging/Monitoring を先に組むと改善が速い
- Terraform 化は早い段階で進めると効果が大きい

---

## 🔜 今後の改善予定

- Firestore or AlloyDB との比較検証
- Anthos or Service Mesh 対応
- BigQuery連携によるログ分析強化
- マルチリージョン設計

---

## 📝 ライセンス
MIT

