variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Region for resources"
  type        = string
  default     = "asia-northeast1"
}

variable "authorized_members" {
  description = "List of members authorized to invoke Cloud Run service (e.g., user:alice@example.com, serviceAccount:sa@project.iam.gserviceaccount.com)"
  type        = list(string)
  default = [
    # デフォルトは空（誰もアクセスできない状態）
    # terraform.tfvars で実際のメンバーを指定してください
  ]
}

variable "iap_support_email" {
  description = "Support email for IAP OAuth consent screen (required)"
  type        = string
}

variable "domain_name" {
  description = "Custom domain name for the load balancer (optional, leave empty to use default)"
  type        = string
  default     = ""
}
