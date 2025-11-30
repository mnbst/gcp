# Artifact Registry へのプッシュガイド

このドキュメントでは、Google Artifact Registry へ Docker イメージをプッシュする方法を詳しく解説します。

---

## 📖 概要

### Artifact Registry とは

Google Artifact Registry は、コンテナイメージ、言語パッケージ（npm、Maven、Python など）を安全に保管・管理できる Google Cloud のフルマネージドサービスです。従来の Container Registry (GCR) の後継サービスとして、より多機能で柔軟な構成が可能です。

### このプロジェクトでの役割

本プロジェクトでは、Artifact Registry を以下の目的で使用しています：

- Go API の Docker イメージを保管
- Cloud Run サービスが自動的にイメージを取得
- バージョン管理とイメージの履歴保持
- セキュアなイメージ配信

### 現在の設定

| 項目 | 設定値 |
|------|--------|
| **リポジトリ名** | `tf-app` |
| **形式** | DOCKER |
| **リージョン** | `asia-northeast1` (東京) |
| **プロジェクトID** | `YOUR_PROJECT_ID` |
| **完全なレジストリURL** | `asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app` |

この設定は [tf-go-api/main.tf](../tf-go-api/main.tf) で Terraform により管理されています。

---

## ✅ 前提条件

### 必須ツール

1. **Google Cloud SDK (`gcloud`)** がインストール済みであること
   ```bash
   # インストール確認
   gcloud --version

   # インストールされていない場合
   # https://cloud.google.com/sdk/docs/install
   ```

2. **Docker** (ローカルビルドを行う場合)
   ```bash
   # インストール確認
   docker --version
   ```

### 必要な権限

以下のいずれかの IAM ロールが必要です：

- `roles/artifactregistry.writer` - イメージのプッシュが可能
- `roles/artifactregistry.repoAdmin` - リポジトリの完全な管理権限
- `roles/editor` または `roles/owner` - プロジェクト全体の編集権限

### API の有効化

以下の API が有効化されている必要があります（Terraform で自動有効化済み）：

- Artifact Registry API
- Cloud Build API（Cloud Build を使用する場合）

---

## 🔐 認証設定

### 1. gcloud 認証

```bash
# Google アカウントで認証
gcloud auth login

# プロジェクトを設定
gcloud config set project YOUR_PROJECT_ID

# 現在の設定を確認
gcloud config list
```

### 2. Docker 認証設定（ローカルプッシュの場合）

```bash
# Docker credential helper の設定
gcloud auth configure-docker asia-northeast1-docker.pkg.dev

# 成功すると以下のメッセージが表示されます：
# Adding credentials for: asia-northeast1-docker.pkg.dev
# Docker configuration file updated.
```

この設定により、Docker が Artifact Registry に対して自動的に認証を行うようになります。

### 3. サービスアカウント認証（CI/CD 用）

CI/CD パイプライン（GitHub Actions、Cloud Build など）で使用する場合：

```bash
# サービスアカウントキーで認証
gcloud auth activate-service-account --key-file=/path/to/key.json

# または、環境変数で指定
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
```

---

## 🚀 プッシュ方法

### パターン1: Cloud Build を使用（推奨）

**現在のプロジェクトで採用している方法です。**

```bash
cd go-api

# イメージをビルド & Artifact Registry にプッシュ
gcloud builds submit --tag asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest
```

#### メリット
- ローカルマシンに Docker イメージを保持する必要がない
- Google Cloud のインフラでビルドされるため高速
- ビルド履歴が Cloud Build で管理される
- ローカルの Docker 環境が不要

#### デメリット
- Cloud Build API の有効化が必要（無料枠あり）
- ビルドごとに課金が発生（無料枠：1日120分）

#### 実行例

```bash
$ cd go-api
$ gcloud builds submit --tag asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest

Creating temporary tarball archive of 5 file(s) totalling 1.2 KiB before compression.
Uploading tarball of [.] to [gs://YOUR_PROJECT_ID_cloudbuild/source/...]
Created [https://cloudbuild.googleapis.com/v1/projects/YOUR_PROJECT_ID/locations/global/builds/...].
Logs are available at [...].
------------------------------ REMOTE BUILD OUTPUT -------------------------------
starting build "..."

DONE
--------------------------------------------------------------------------------

ID                                    CREATE_TIME                DURATION  SOURCE  IMAGES  STATUS
abc123-def456-ghi789-jkl012-mno345    2025-11-30T10:15:30+00:00  1M 45S    gs://   asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest (+1 more)  SUCCESS
```

---

### パターン2: ローカルビルド + Docker Push

ローカルで Docker イメージをビルドしてからプッシュする方法です。

```bash
# Step 1: Docker 認証設定（初回のみ）
gcloud auth configure-docker asia-northeast1-docker.pkg.dev

# Step 2: イメージをビルド
cd go-api
docker build -t asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest .

# Step 3: Artifact Registry にプッシュ
docker push asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest
```

#### メリット
- ローカルでビルドして動作確認してからプッシュできる
- オフライン環境でもビルド可能
- ビルドプロセスを細かく制御できる

#### デメリット
- ローカルに Docker 環境が必要
- マシンスペックによってはビルドが遅い
- ローカルにイメージが残る（ディスク容量を消費）

#### 実行例

```bash
$ docker build -t asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest .
[+] Building 45.2s (12/12) FINISHED
 => [internal] load build definition from Dockerfile
 => => transferring dockerfile: 512B
 => [internal] load .dockerignore
 => [stage-1 1/3] FROM gcr.io/distroless/base-debian12
 => [builder 5/5] RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o server .
 => [stage-1 3/3] COPY --from=builder /app/server /app/server
 => exporting to image
 => => exporting layers
 => => writing image sha256:abc123...
 => => naming to asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest

$ docker push asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest
The push refers to repository [asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api]
abc123: Pushed
def456: Pushed
latest: digest: sha256:xyz789... size: 1234
```

---

### パターン3: タグ管理（バージョニング）

本番運用では、`latest` だけでなく、バージョンタグを付けることを推奨します。

#### 特定バージョンをタグ付け

```bash
# v1.0.0 というタグでプッシュ
gcloud builds submit --tag asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:v1.0.0
```

#### latest と特定バージョンの両方をタグ付け

```bash
# 複数のタグを同時に指定
gcloud builds submit \
  --tag asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest \
  --tag asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:v1.0.0
```

#### Git コミットハッシュをタグに使用

```bash
# Git のコミットハッシュを取得
export GIT_COMMIT=$(git rev-parse --short HEAD)

# コミットハッシュをタグとして使用
gcloud builds submit \
  --tag asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest \
  --tag asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:${GIT_COMMIT}
```

#### タグ付けのベストプラクティス

- `latest` - 常に最新のイメージ（開発・テスト用）
- `v1.0.0`, `v1.0.1` - セマンティックバージョニング（本番用）
- `abc123f` - Git コミットハッシュ（トレーサビリティ）
- `prod-20251130` - 日付ベース（本番デプロイ記録）

---

## 🔍 イメージの確認方法

### 1. gcloud コマンドでイメージ一覧を表示

```bash
# リポジトリ内の全イメージを表示
gcloud artifacts docker images list asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app

# 出力例：
# IMAGE                                                                                    DIGEST         CREATE_TIME          UPDATE_TIME
# asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest          sha256:abc...  2025-11-30T10:15:30  2025-11-30T10:15:30
# asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:v1.0.0          sha256:abc...  2025-11-30T10:15:30  2025-11-30T10:15:30
```

### 2. 特定イメージの詳細を表示

```bash
# イメージのメタデータを表示
gcloud artifacts docker images describe \
  asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest

# イメージのタグ一覧を表示
gcloud artifacts docker tags list \
  asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api
```

### 3. GCP Console での確認

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. プロジェクト `YOUR_PROJECT_ID` を選択
3. 左メニューから **Artifact Registry** を選択
4. リポジトリ `tf-app` をクリック
5. イメージ一覧とタグが表示されます

---

## 🔧 トラブルシューティング

### エラー: Permission denied

**症状**
```
ERROR: (gcloud.builds.submit) PERMISSION_DENIED: Permission 'artifactregistry.repositories.uploadArtifacts' denied
```

**原因**
Artifact Registry への書き込み権限がない

**解決策**
```bash
# 現在の権限を確認
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:YOUR-EMAIL@example.com"

# 権限が不足している場合、プロジェクトオーナーに以下のロールを付与してもらう
# roles/artifactregistry.writer
```

---

### エラー: Repository not found

**症状**
```
ERROR: (gcloud.artifacts.docker.images.list) NOT_FOUND: Repository not found
```

**原因**
Artifact Registry リポジトリが作成されていない

**解決策**
```bash
# Terraform でインフラを構築
cd tf-go-api
terraform init
terraform apply

# または、手動でリポジトリを作成
gcloud artifacts repositories create tf-app \
  --repository-format=docker \
  --location=asia-northeast1 \
  --description="Terraform-managed repo for Go API"
```

---

### エラー: Region mismatch

**症状**
```
ERROR: Invalid value for --tag: must match region asia-northeast1
```

**原因**
リージョンの指定が間違っている

**解決策**
- 必ず `asia-northeast1-docker.pkg.dev` を使用してください
- `us-docker.pkg.dev` や `gcr.io` などは使用できません

正しい形式：
```bash
asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest
```

---

### エラー: Docker authentication required

**症状**
```
Error response from daemon: unauthorized: authentication required
```

**原因**
Docker の認証設定がされていない

**解決策**
```bash
# Docker credential helper を再設定
gcloud auth configure-docker asia-northeast1-docker.pkg.dev

# 認証情報をリフレッシュ
gcloud auth application-default login
```

---

### エラー: Cloud Build API not enabled

**症状**
```
ERROR: (gcloud.builds.submit) FAILED_PRECONDITION: Cloud Build API has not been used in project
```

**原因**
Cloud Build API が有効化されていない

**解決策**
```bash
# Cloud Build API を有効化
gcloud services enable cloudbuild.googleapis.com --project=YOUR_PROJECT_ID
```

---

## 🤖 CI/CD 統合のヒント

### Cloud Build YAML による自動ビルド

プロジェクトルートに `cloudbuild.yaml` を作成すると、自動ビルド・デプロイが可能です。

```yaml
# cloudbuild.yaml の例
steps:
  # Step 1: Docker イメージをビルド
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - 'asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:$COMMIT_SHA'
      - '-t'
      - 'asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest'
      - './go-api'

  # Step 2: Artifact Registry にプッシュ
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - '--all-tags'
      - 'asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api'

  # Step 3: Cloud Run にデプロイ
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args:
      - 'run'
      - 'services'
      - 'update'
      - 'go-api-tf'
      - '--image=asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:$COMMIT_SHA'
      - '--region=asia-northeast1'

images:
  - 'asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:$COMMIT_SHA'
  - 'asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest'

options:
  logging: CLOUD_LOGGING_ONLY
```

実行方法：
```bash
# ローカルから実行
gcloud builds submit --config=cloudbuild.yaml

# GitHub と連携してトリガーを設定
gcloud builds triggers create github \
  --repo-name=your-repo \
  --repo-owner=your-username \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml
```

---

### GitHub Actions との連携

`.github/workflows/deploy.yml` の例：

```yaml
name: Deploy to Cloud Run

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Build and Push to Artifact Registry
        run: |
          cd go-api
          gcloud builds submit \
            --tag asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest \
            --tag asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:${{ github.sha }}

      - name: Deploy to Cloud Run
        run: |
          gcloud run services update go-api-tf \
            --image asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:${{ github.sha }} \
            --region asia-northeast1
```

---

## 🔒 セキュリティベストプラクティス

### 1. イメージの脆弱性スキャン

Artifact Registry には自動脆弱性スキャン機能があります。

```bash
# スキャン結果を確認
gcloud artifacts docker images list asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app \
  --include-tags \
  --format="table(package,version,tags,create_time)"

# 特定イメージの脆弱性を表示
gcloud artifacts docker images describe \
  asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest \
  --show-all-metadata
```

GCP Console でも確認可能：
1. Artifact Registry → tf-app → go-api
2. 「脆弱性」タブをクリック

---

### 2. 最小権限の原則

サービスアカウントには必要最小限の権限のみを付与します。

```bash
# Cloud Run サービスアカウントに Artifact Registry Reader 権限を付与
gcloud artifacts repositories add-iam-policy-binding tf-app \
  --location=asia-northeast1 \
  --member="serviceAccount:go-api-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.reader"

# CI/CD 用のサービスアカウントには Writer 権限
gcloud artifacts repositories add-iam-policy-binding tf-app \
  --location=asia-northeast1 \
  --member="serviceAccount:ci-cd-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"
```

---

### 3. イメージの署名と検証（Binary Authorization）

本番環境では、署名されたイメージのみデプロイを許可する設定が推奨されます。

```bash
# Binary Authorization を有効化
gcloud services enable binaryauthorization.googleapis.com

# ポリシーを作成
gcloud container binauthz policy import policy.yaml
```

---

## 📚 参考リンク

### 公式ドキュメント

- [Artifact Registry 公式ドキュメント](https://cloud.google.com/artifact-registry/docs)
- [Docker イメージの管理](https://cloud.google.com/artifact-registry/docs/docker)
- [Cloud Build でのイメージビルド](https://cloud.google.com/build/docs/building/build-containers)
- [Cloud Run へのデプロイ](https://cloud.google.com/run/docs/deploying)

### プロジェクト内の関連ファイル

- [go-api/Dockerfile](../go-api/Dockerfile) - マルチステージビルド設定
- [tf-go-api/main.tf](../tf-go-api/main.tf) - Artifact Registry と Cloud Run の Terraform 定義
- [README.md](../README.md) - プロジェクト全体の概要とデプロイ手順

### 料金情報

- [Artifact Registry 料金](https://cloud.google.com/artifact-registry/pricing)
- [Cloud Build 料金](https://cloud.google.com/build/pricing)
  - 無料枠：1日あたり 120 ビルド分

---

## 🎯 まとめ

このガイドで解説した内容：

1. ✅ Artifact Registry の概要と設定確認
2. ✅ 認証設定（gcloud、Docker、サービスアカウント）
3. ✅ 3つのプッシュ方法（Cloud Build、ローカルビルド、タグ管理）
4. ✅ イメージの確認方法
5. ✅ トラブルシューティング
6. ✅ CI/CD 統合のヒント
7. ✅ セキュリティベストプラクティス

**推奨フロー（初心者向け）:**

```bash
# 1. 認証
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# 2. ビルド＆プッシュ（Cloud Build 推奨）
cd go-api
gcloud builds submit --tag asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest

# 3. イメージ確認
gcloud artifacts docker images list asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app

# 4. Terraform でデプロイ
cd ../tf-go-api
terraform apply
```

これで Artifact Registry への Docker イメージプッシュが完了します！
