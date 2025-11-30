# ドキュメント / Documentation

このディレクトリには、プロジェクトのセットアップとトラブルシューティングに関するドキュメントが含まれています。

## ⚠️ 重要な注意事項

これらのドキュメントには**プレースホルダー**が含まれています。実際に使用する前に、以下のプレースホルダーを**あなたの環境に合わせた値**に置き換えてください。

### プレースホルダー一覧

| プレースホルダー | 説明 | 取得方法 |
|---------------|------|---------|
| `YOUR_PROJECT_ID` | GCPプロジェクトID | `gcloud config get-value project` |
| `YOUR_PROJECT_NUMBER` | GCPプロジェクトNumber | `gcloud projects describe YOUR_PROJECT_ID --format="value(projectNumber)"` |
| `your-email@example.com` | あなたのメールアドレス | Googleアカウントのメールアドレス |
| `YOUR_LOAD_BALANCER_IP` | Load BalancerのIPアドレス | `terraform output load_balancer_ip` |
| `yourdomain.com` | カスタムドメイン | 所有しているドメイン名、またはnip.ioを使用 |

### 使用例

**置き換え前（テンプレート）:**
```bash
gcloud builds submit --tag asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/tf-app/go-api:latest
```

**置き換え後（実際の値）:**
```bash
gcloud builds submit --tag asia-northeast1-docker.pkg.dev/my-gcp-project/tf-app/go-api:latest
```

## 📁 ドキュメント一覧

### 1. [Artifact Registry プッシュガイド](artifact-registry-push-guide.md)
DockerイメージをGoogle Artifact Registryにプッシュする方法の詳細ガイド。

**内容:**
- Artifact Registryの概要と設定
- 認証設定
- 3つのプッシュ方法（Cloud Build推奨、ローカルビルド、タグ管理）
- トラブルシューティング
- CI/CD統合のヒント
- セキュリティベストプラクティス

### 2. [Cloud Identity セットアップガイド](cloud-identity-setup.md)
IAP使用のためのCloud Identity Free組織のセットアップ手順。

**内容:**
- Cloud Identity Freeの登録方法
- ドメイン所有権の確認
- GCPプロジェクトのOrganization移行
- トラブルシューティング

### 3. [IAP + Cloud Run トラブルシューティングガイド](iap-cloudrun-troubleshooting.md)
IAP、Cloud Run、Load Balancerを組み合わせた構成での実際のトラブルシューティング経験をまとめたガイド。

**内容:**
- OAuth Brand "Already Exists" エラーの解決
- SSL証明書プロビジョニング遅延の対処
- IAPサービスアカウント未プロビジョニングエラーの解決
- ベストプラクティス
- 推奨される構築手順

## 🔒 セキュリティに関する注意

### 公開してはいけない情報

以下の情報は**絶対にGitHubなどの公開リポジトリにコミットしないでください**：

- ❌ 実際のGCPプロジェクトID
- ❌ プロジェクトNumber
- ❌ 実際のメールアドレス
- ❌ IPアドレス
- ❌ OAuth Client IDやSecret
- ❌ サービスアカウントキー
- ❌ 実際のドメイン名（必要に応じて）

### バックアップファイルについて

`*.backup` ファイルには実際の機密情報が含まれています。これらのファイルは`.gitignore`で除外されており、Gitリポジトリには含まれません。

**ローカル環境にのみ保存し、決して共有しないでください。**

## 🚀 使用方法

1. **このリポジトリをクローン**
   ```bash
   git clone <repository-url>
   cd gcp
   ```

2. **ドキュメントを読む**
   - 各ガイドを確認し、必要な手順を理解する

3. **プレースホルダーを置き換える**
   - 実際のコマンドを実行する際は、プレースホルダーを実際の値に置き換える
   - ローカル環境で`.backup`ファイルを参照することも可能

4. **実行**
   - 置き換えたコマンドを実行

## 📝 貢献

ドキュメントの改善提案がある場合は、以下の点に注意してください：

1. **機密情報を含めない** - プレースホルダーを使用する
2. **実際の値は`.backup`ファイルに保存** - Gitには含めない
3. **プレースホルダーは統一する** - 上記の表を参照

## ライセンス

このドキュメントはMITライセンスの下で公開されています。
