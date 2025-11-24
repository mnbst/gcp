# ベースイメージとして Cloud Workstations のプリ構成イメージを選択
FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/code-oss:latest

# 必要なパッケージ + Terraform のインストール
RUN apt-get update && \
    apt-get install -y gnupg software-properties-common curl && \
    # HashiCorp のリポジトリを追加
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install -y terraform && \
    terraform version

# （必要なら）デフォルトのワークディレクトリ・シェルなどを設定
WORKDIR /home/user
