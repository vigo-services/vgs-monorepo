# VGS — Configuration CI/CD GitHub Actions

## Étape 1 — Secrets GitHub

**Settings → Secrets and variables → Actions → Secrets** :

| Secret | Description | Où l'obtenir |
|--------|-------------|-------------|
| `CLOUDFLARE_API_TOKEN` | Token API Cloudflare | [Dashboard → API Tokens](https://dash.cloudflare.com/profile/api-tokens) |
| `CLOUDFLARE_ACCOUNT_ID` | ID du compte Cloudflare | Dashboard → Account Home |
| `WHATSAPP_APP_SECRET` | App Secret Meta | [Meta App Dashboard](https://developers.facebook.com/apps) |
| `WHATSAPP_VERIFY_TOKEN` | Token de vérification personnalisé | Vous le définissez |

### Permissions du token Cloudflare

- `Zone:Zone:Edit`
- `Zone:DNS:Edit`
- `Zone:WAF:Edit`
- `Zone:Page Rules:Edit`
- `Zone:Settings:Edit`
- `Account:Workers Scripts:Edit`
- `Account:Bot Management:Edit`
- `Account:Notifications:Edit`

## Étape 2 — Variables GitHub

**Settings → Secrets and variables → Actions → Variables** :

| Variable | Exemple |
|----------|---------|
| `RENDER_HOSTNAME` | `vigo-services.onrender.com` |

## Étape 3 — Environment GitHub

**Settings → Environments** → créer `production` :
- Required reviewers (optionnel)
- Deployment branch: `main` uniquement

## Étape 4 — Premier déploiement

```bash
git add .
git commit -m "feat: VGS monorepo — Terraform + Worker + CI/CD"
git push origin main
```

Le workflow se déclenche automatiquement → onglet **Actions** sur GitHub.

## Étape 5 — Post-déploiement

1. Récupérer les nameservers : `cd terraform && terraform output nameservers`
2. Configurer les nameservers chez votre registrar
3. Configurer le webhook Meta avec l'URL du Worker
4. Vérifier `https://app.vigo-services.com`

## Pipeline

```
Validate → Terraform Apply + Worker Deploy → Verify
```

## Déploiement manuel

GitHub → **Actions** → **Deploy VGS** → **Run workflow**

## Destruction

GitHub → **Actions** → **Destroy VGS Infrastructure** → taper `DESTROY`
