# =============================================================================
# Outputs — VIGO-SERVICES (VGS)
# =============================================================================

output "zone_id" {
  description = "ID de la zone Cloudflare"
  value       = cloudflare_zone.vigo_services.id
}

output "nameservers" {
  description = "Nameservers Cloudflare à configurer chez votre registrar"
  value       = cloudflare_zone.vigo_services.name_servers
}

output "app_url" {
  description = "URL publique de l'application VGS"
  value       = "https://app.${var.zone_name}"
}

output "ssl_mode" {
  description = "Mode SSL/TLS configuré"
  value       = cloudflare_zone_settings_override.vigo_settings.settings[0].ssl
}

output "rate_limit_auth_rule_id" {
  description = "ID de la règle de rate limiting /auth"
  value       = cloudflare_ruleset.rate_limit_auth.id
}

output "rate_limit_api_rule_id" {
  description = "ID de la règle de rate limiting /api"
  value       = cloudflare_ruleset.rate_limit_api.id
}
