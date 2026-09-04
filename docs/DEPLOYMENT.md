# VGS — Guide de déploiement

## Déploiement local (sans CI/CD)

### 1. Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Éditer terraform.tfvars

export TF_VAR_cloudflare_api_token="votre-token"

terraform init
terraform plan
terraform apply

# Récupérer les nameservers
terraform output nameservers
```

### 2. Worker

```bash
cd worker
npm install

# Configurer les secrets
wrangler secret put WHATSAPP_APP_SECRET
wrangler secret put WHATSAPP_VERIFY_TOKEN

# Déployer
npm run deploy

# Vérifier
curl https://vgs-whatsapp-proxy.<subdomain>.workers.dev/health
```

### 3. Configuration Meta

1. [Meta App Dashboard](https://developers.facebook.com/apps) → WhatsApp → Configuration → Webhook
2. **Callback URL** : `https://vgs-whatsapp-proxy.<subdomain>.workers.dev/webhook`
3. **Verify Token** : la valeur de `WHATSAPP_VERIFY_TOKEN`
4. **Verify and Save**
5. Abonner aux champs : `messages`, `message_status`, `message_delivered`

### 4. Configuration Render

Votre service Render doit :
- Servir FastAPI sur le port configuré
- Avoir PostgreSQL provisionné
- Accepter `POST /api/webhooks/whatsapp` avec vérification du header `X-Webhook-Source`

### 5. Configuration Registrar

1. Chez votre registrar, remplacez les nameservers par ceux de Cloudflare
2. Attendre la propagation (5–30 min)
3. Vérifier : `dig NS vigo-services.com`

## Checklist de déploiement

- [ ] Token API Cloudflare créé avec les bonnes permissions
- [ ] `terraform.tfvars` configuré
- [ ] `terraform apply` réussi
- [ ] Nameservers configurés chez le registrar
- [ ] DNS propagé (`dig app.vigo-services.com`)
- [ ] Worker déployé (`/health` répond 200)
- [ ] Secrets Worker définis (`WHATSAPP_APP_SECRET`, `WHATSAPP_VERIFY_TOKEN`)
- [ ] Webhook Meta configuré et vérifié
- [ ] FastAPI accessible sur `https://app.vigo-services.com`
- [ ] Webhook WhatsApp fonctionnel (test avec message)

## Dépannage

### Terraform : zone existe déjà

```bash
terraform import cloudflare_zone.vigo_services <zone_id>
```

### Worker : erreur d'authentification

Vérifiez que `CLOUDFLARE_API_TOKEN` a la permission `Account:Workers Scripts:Edit`.

### DNS ne se propage pas

- Vérifiez les nameservers chez le registrar
- Attendez 5–30 minutes
- `dig NS vigo-services.com`

### Worker retourne 403

Vérifiez les secrets :
```bash
wrangler secret list
```
