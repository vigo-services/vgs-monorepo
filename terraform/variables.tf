# =============================================================================
# Variables — VIGO-SERVICES (VGS)
# =============================================================================

variable "cloudflare_api_token" {
  description = "Token API Cloudflare (ne pas committer — utiliser TF_VAR ou env)"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "ID du compte Cloudflare"
  type        = string
}

variable "zone_name" {
  description = "Nom de la zone DNS"
  type        = string
  default     = "vigo-services.com"
}

variable "render_hostname" {
  description = "Hostname Render (CNAME cible). Ex: vigo-services.onrender.com"
  type        = string
}
