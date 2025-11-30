# Cloud Identity Free セットアップガイド

## 概要
IAPを使用するためにCloud Identity Free（無料）でOrganizationを作成する手順

## 前提条件
- Googleアカウント（your-email@example.com）
- GCPプロジェクト（YOUR_PROJECT_ID）

---

## 手順

### 1. Cloud Identity Free に登録

1. **登録ページにアクセス**
   - URL: https://workspace.google.com/signup/gcpidentity/welcome

2. **ビジネス情報を入力**
   ```
   ビジネス名: Gaku Development (任意の名前)
   従業員数: 1
   国: 日本
   現在のメール: your-email@example.com
   ```

3. **ドメインを選択**

   **オプションA: 無料のGoogleドメイン（簡単）**
   - "I don't have a domain name" を選択
   - `yourname.gcp-directory.cloud` 形式のドメインを取得
   - 所有権確認は不要

   **オプションB: 既存ドメインを使用**
   - 持っているドメインを入力
   - DNS TXTレコードで所有権確認が必要

4. **管理者アカウント作成**
   ```
   ユーザー名: admin (または任意)
   完全なアドレス: admin@yourname.gcp-directory.cloud
   パスワード: 強力なパスワードを設定
   ```

5. **登録完了**
   - Organizationが自動作成されます

---

### 2. ドメイン所有権の確認（既存ドメイン使用時のみ）

#### DNSレコードで確認（推奨）
1. Google Admin Consoleにログイン
2. 確認用のTXTレコードをコピー
3. DNSプロバイダーで設定:
   ```
   Type: TXT
   Host: @ (or your domain)
   Value: google-site-verification=xxxxxxxxxxxx
   TTL: 3600
   ```
4. 数分〜数時間待って「確認」をクリック

#### HTMLファイルで確認
1. 指定されたHTMLファイルをダウンロード
2. ウェブサイトのルートにアップロード
3. 「確認」をクリック

---

### 3. GCPプロジェクトをOrganizationに移行

#### 方法1: GCPコンソールから

1. **GCPコンソールにアクセス**
   - https://console.cloud.google.com

2. **プロジェクトを選択**
   - `YOUR_PROJECT_ID` を選択

3. **IAM & Admin → Settings**
   - 左メニューから「IAM & Admin」→「Settings」

4. **Migrate Project**
   - 「Migrate」ボタンをクリック
   - 作成したOrganizationを選択
   - 確認して実行

#### 方法2: gcloudコマンドから

```bash
# 1. Organization IDを確認
gcloud organizations list

# 出力例:
# DISPLAY_NAME          ID            DIRECTORY_CUSTOMER_ID
# Gaku Development      123456789012  C01234567

# 2. プロジェクトを移行
gcloud projects move YOUR_PROJECT_ID \
  --organization=123456789012

# 3. 確認
gcloud projects describe YOUR_PROJECT_ID \
  --format="value(parent.id, parent.type)"
```

---

### 4. Organization設定完了を確認

```bash
# Organization IDが表示されればOK
gcloud projects describe YOUR_PROJECT_ID
```

`parent` フィールドに `type: organization` と `id` が表示されていれば成功

---

### 5. Terraformで IAP を再実行

```bash
cd /Users/gaku/project/gcp/tf-go-api

# プラン確認
terraform plan

# 適用
terraform apply
```

今度はIAP Brand作成エラーが出ずに成功します。

---

## トラブルシューティング

### Q1: Organization IDが見つからない
```bash
# Google Workspace Admin SDKを有効化
gcloud services enable admin.googleapis.com

# 再度確認
gcloud organizations list
```

### Q2: プロジェクトの移行権限がない
- Cloud Identity Adminとして認証されているか確認
- `gcloud auth login` で管理者アカウントでログイン

### Q3: ドメイン確認が失敗する
- DNSレコードの反映には最大48時間かかる場合があります
- TTL値を短く（300-600秒）設定すると早く反映されます

---

## 参考リンク

- [Cloud Identity Free のドキュメント](https://cloud.google.com/identity/docs/overview)
- [GCP Organization の作成](https://cloud.google.com/resource-manager/docs/creating-managing-organization)
- [IAP の要件](https://cloud.google.com/iap/docs/enabling-compute-howto)

---

## 次のステップ

Organization作成後:
1. `terraform plan` を実行してエラーがないか確認
2. `terraform apply` でIAPを含む全リソースをデプロイ
3. Load Balancer URLにアクセスしてGoogle認証を確認
