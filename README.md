# VIGO-SERVICES (VGS) — Monorepo

Monorepo complet pour l'automatisation de la plate-forme VGS sur Cloudflare.

## Architecture

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

## Structure du monorepo

```
vgs-monorepo/
├── .github/
│   └── workflows/
│       ├── deploy-vgs.yml        # Pipeline principal (Terraform + Worker)
│       ├── pr-check.yml          # Validation PR (léger)
│       └── destroy-vgs.yml       # Destruction (manuel)
├── terraform/                     # Infrastructure Cloudflare (IaC)
│   ├── main.tf                   # Zone, DNS, SSL, WAF, notifications
│   ├── variables.tf              # Variables d'entrée
│   ├── outputs.tf                # Outputs (zone ID, nameservers, URLs)
│   ├── terraform.tfvars.example   # Modèle de configuration
│   └── .gitignore
├── worker/                        # Worker proxy WhatsApp Cloud API
│   ├── src/
│   │   └── index.ts              # Validation HMAC + forward + retry
│   ├── wrangler.jsonc            # Configuration Wrangler
│   ├── package.json              # Dépendances
│   ├── tsconfig.json             # Configuration TypeScript
│   ├── .dev.vars.example         # Secrets locaux (exemple)
│   └── .gitignore
├── docs/
│   ├── CI-CD-SETUP.md            # Guide configuration GitHub Actions
│   ├── ARCHITECTURE.md           # Documentation architecture
│   └── DEPLOYMENT.md             # Guide de déploiement étape par étape
├── .gitignore                    # Exclusions globales
└── README.md                     # Ce fichier
```

## Composants

| Composant | Description | Technologie |
|-----------|-------------|-------------|
| **Infrastructure** | Zone DNS, SSL, WAF, rate limiting, notifications | Terraform + Cloudflare |
| **Worker** | Proxy sécurisé webhook WhatsApp (HMAC validation, retry) | Cloudflare Workers + TypeScript |
| **CI/CD** | Déploiement automatisé Terraform + Worker | GitHub Actions |

## Démarrage rapide

### 1. Cloner le monorepo

```bash
git clone <votre-repo-url> vgs-monorepo
cd vgs-monorepo
```

### 2. Configurer les secrets GitHub

Voir [docs/CI-CD-SETUP.md](docs/CI-CD-SETUP.md).

### 3. Déployer

```bash
# Option A — Via GitHub Actions (recommandé)
git add .
git commit -m "feat: VGS monorepo — Terraform + Worker + CI/CD"
git push origin main
# → Le pipeline se déclenche automatiquement

# Option B — Déploiement local manuel
# Voir docs/DEPLOYMENT.md
```

## Documentation

- [Architecture détaillée](docs/ARCHITECTURE.md)
- [Configuration CI/CD](docs/CI-CD-SETUP.md)
- [Guide de déploiement](docs/DEPLOYMENT.md)

## Domaine cible

- **Application** : `https://app.vigo-services.com`
- **Webhook WhatsApp** : `https://vgs-whatsapp-proxy.<subdomain>.workers.dev/webhook`

## Stack technique

| Couche | Technologie |
|--------|-------------|
| Edge / Proxy | Cloudflare Workers (TypeScript) |
| DNS / CDN / WAF | Cloudflare |
| Infrastructure as Code | Terraform |
| CI/CD | GitHub Actions |
| Backend | FastAPI (Python) sur Render |
| Base de données | PostgreSQL (Render) |
| Webhook | WhatsApp Cloud API (Meta) |
| Workflows | n8n |
