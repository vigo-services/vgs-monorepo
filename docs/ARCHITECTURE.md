# VGS — Architecture

## Vue d'ensemble

```
                    ┌─────────────────────────────────────────┐
                    │              Cloudflare                   │
                    │                                          │
  Utilisateurs ────►│  DNS (app.vigo-services.com)             │
                    │  SSL/TLS Full + Always Use HTTPS         │
                    │  WAF (rate limit /auth, /api)            │
                    │  Bot Fight Mode                          │
                    │  CDN + Brotli compression                │
                    └───────┬──────────────────┬──────────────┘
                            │                  │
                            ▼                  ▼
                    ┌──────────────┐  ┌───────────────────────┐
                    │   Render      │  │  Cloudflare Worker     │
                    │   FastAPI     │  │  vgs-whatsapp-proxy   │
                    │   PostgreSQL  │  │  (validation HMAC)    │
                    │               │  │  (retry x3)            │
                    └──────────────┘  └───────────────────────┘
                            ▲                        ▲
                            │                        │
                        VGS API              Meta WhatsApp Cloud API
```

## Flux de données

### 1. Accès au tableau de bord

```
Utilisateur → HTTPS → Cloudflare (CDN + WAF + SSL) → Render (FastAPI)
```

- Cloudflare termine le SSL, applique le WAF, cache les assets statiques
- Render exécute FastAPI qui sert le tableau de bord responsive (PC/Android)

### 2. Authentification JWT

```
Utilisateur → POST /auth/login → Cloudflare (rate limit 10/min) → FastAPI → JWT
```

- Le WAF bloque les tentatives de brute-force (>10 POST/min/IP)
- FastAPI valide les credentials et émet un JWT

### 3. Webhook WhatsApp

```
Meta WhatsApp → POST /webhook → Worker (HMAC validation) → FastAPI → n8n
```

- Le Worker valide la signature HMAC-SHA256 avec l'App Secret Meta
- Si valide, forward vers FastAPI avec retry (3 tentatives)
- FastAPI traite le message et déclenche les workflows n8n

## Composants Cloudflare

| Composant | Ressource Terraform | Rôle |
|-----------|---------------------|------|
| Zone DNS | `cloudflare_zone` | `vigo-services.com` |
| CNAME app | `cloudflare_record` | `app` → Render (proxied) |
| SSL/TLS | `cloudflare_zone_settings_override` | Full + Always Use HTTPS + TLS 1.3 |
| Rate limit /auth | `cloudflare_ruleset` | Block >10 POST/min (brute-force) |
| Rate limit /api | `cloudflare_ruleset` | Challenge >120 req/min |
| WAF no-UA | `cloudflare_ruleset` | Block requêtes sans User-Agent |
| WAF WhatsApp skip | `cloudflare_ruleset` | Skip rate limit webhook |
| Bot Fight Mode | `cloudflare_bot_management` | Anti-bot automatique |
| Notifications | `cloudflare_notification_policy` | Alertes DDoS + origin |
| Worker | (Wrangler) | Proxy webhook WhatsApp |

## Sécurité

| Couche | Protection |
|--------|-----------|
| Edge (Cloudflare) | WAF, rate limiting, Bot Fight Mode, DDoS |
| Worker | HMAC-SHA256 validation, timing-safe comparison |
| Transport | TLS 1.3, Always Use HTTPS, HSTS |
| API (FastAPI) | JWT, vérification header `X-Webhook-Source` |
| Secrets | Wrangler secrets (jamais dans le code) |
