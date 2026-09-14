# =============================================================================
# VIGO-SERVICES (VGS) — Infrastructure Cloudflare via Terraform
# =============================================================================
#
# Provisionne :
#   - Zone DNS vigo-services.com
#   - CNAME app -> Render (proxied)
#   - SSL/TLS Full + Always Use HTTPS
#   - WAF (rate limiting /auth, /api)
#   - Bot Fight Mode
#   - Notifications (DDoS + origin unreachable)
#
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# -----------------------------------------------------------------------------
# Zone DNS
# -----------------------------------------------------------------------------
resource "cloudflare_zone" "vigo_services" {
  account_id = var.cloudflare_account_id
  zone       = var.zone_name
}

# -----------------------------------------------------------------------------
# SSL/TLS — Full + Always Use HTTPS
# -----------------------------------------------------------------------------
resource "cloudflare_zone_settings_override" "vigo_settings" {
  zone_id = cloudflare_zone.vigo_services.id

  settings {
    ssl                  = "full"
    always_use_https     = "on"
    automatic_https_rewrites = "on"
    min_tls_version     = "1.2"
    tls_1_3             = "on"
    brotli              = "on"
    opportunistic_encryption = "on"
  }
}

# -----------------------------------------------------------------------------
# CNAME app -> Render
# -----------------------------------------------------------------------------
resource "cloudflare_record" "app_cname" {
  zone_id = cloudflare_zone.vigo_services.id
  name    = "app"
  value   = var.render_hostname
  type    = "CNAME"
  proxied = true
  comment = "CNAME vers Render pour app.vigo-services.com"
}

# -----------------------------------------------------------------------------
# Page Rule — www -> app (301)
# -----------------------------------------------------------------------------
resource "cloudflare_page_rule" "www_to_app" {
  zone_id = cloudflare_zone.vigo_services.id
  target  = "www.${var.zone_name}/*"

  actions {
    forwarding_url {
      status_code = 301
      url         = "https://app.${var.zone_name}$1"
    }
  }
  depends_on = [cloudflare_zone_settings_override.vigo_settings]
}

# -----------------------------------------------------------------------------
# WAF — Rate limit /auth (protection brute-force JWT)
# -----------------------------------------------------------------------------
resource "cloudflare_ruleset" "rate_limit_auth" {
  zone_id     = cloudflare_zone.vigo_services.id
  name        = "VGS - Rate limit /auth"
  description = "Limite les tentatives de connexion sur /auth/*"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules {
    action = "block"
    ratelimit {
      characteristics = ["ip.src"]
      period         = 60
      requests_per_period = 10
    }
    expression  = "(http.request.uri.path starts with \"/auth\" and http.request.method eq \"POST\")"
    description = "Block >10 POST /auth par minute par IP"
    enabled     = true
  }
}

# -----------------------------------------------------------------------------
# WAF — Rate limit /api (protection API générale)
# -----------------------------------------------------------------------------
resource "cloudflare_ruleset" "rate_limit_api" {
  zone_id     = cloudflare_zone.vigo_services.id
  name        = "VGS - Rate limit /api"
  description = "Limite le débit global sur l'API FastAPI"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules {
    action = "managed_challenge"
    ratelimit {
      characteristics = ["ip.src"]
      period         = 60
      requests_per_period = 120
    }
    expression  = "(http.request.uri.path starts with \"/api\")"
    description = "Challenge >120 req /api par minute par IP"
    enabled     = true
  }
}

# -----------------------------------------------------------------------------
# WAF — Block requêtes sans User-Agent
# -----------------------------------------------------------------------------
resource "cloudflare_ruleset" "block_no_ua" {
  zone_id     = cloudflare_zone.vigo_services.id
  name        = "VGS - Block no User-Agent"
  description = "Bloque les requêtes sans User-Agent"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules {
    action      = "block"
    expression  = "http.user_agent eq \"\""
    description = "Block requests without User-Agent"
    enabled     = true
  }
}

# -----------------------------------------------------------------------------
# WAF — Skip rate limit pour le webhook WhatsApp
# -----------------------------------------------------------------------------
resource "cloudflare_ruleset" "whatsapp_webhook" {
  zone_id     = cloudflare_zone.vigo_services.id
  name        = "VGS - WhatsApp webhook skip"
  description = "Autorise les IP Meta/WhatsApp sur /webhooks/whatsapp sans rate limit"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules {
    action      = "skip"
    action_parameters {
      ruleset = "http_ratelimit"
    }
    expression  = "(http.request.uri.path eq \"/api/webhooks/whatsapp\" and http.request.method eq \"POST\")"
    description = "Skip rate limiting pour le webhook WhatsApp"
    enabled     = true
  }
}

# -----------------------------------------------------------------------------
# Bot Fight Mode
# -----------------------------------------------------------------------------
resource "cloudflare_bot_management" "bot_fight_mode" {
  zone_id      = cloudflare_zone.vigo_services.id
  enable_js   = true
  fight_mode   = true
}

# -----------------------------------------------------------------------------
# Notifications
# -----------------------------------------------------------------------------
resource "cloudflare_notification_policy" "security_alerts" {
  account_id  = var.cloudflare_account_id
  name        = "VGS - Alertes sécurité"
  description = "Notifications pour attaques et incidents"
  alert_type  = "ddos_attack_alert"

  email_integration {
    id = "cloudflare-notification-email"
  }

  filters {
    enabled = ["on"]
  }
}

resource "cloudflare_notification_policy" "security_alerts "origin_unreachable"{                                                                                   enabled = true
                           
  account_id  = var.cloudflare_account_id
  name        = "VGS - Origin indisponible"
  description = "Alerte si Render (origin) est injoignable"
  alert_type  = "origin_error"

  email_integration {
    id = "cloudflare-notification-email"
  }

  filters {
    enabled = ["on"]
  }
}                                                                                                                                                 enabled = true

