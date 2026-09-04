# =============================================================================
# VGS WhatsApp Webhook Proxy — Worker Cloudflare
# =============================================================================
#
# Proxy sécurisé entre Meta (WhatsApp Cloud API) et l'API FastAPI de VGS :
#   1. Gère la vérification GET du webhook (hub.challenge)
#   2. Valide la signature HMAC-SHA256 de Meta (X-Hub-Signature-256)
#   3. Forward les webhooks valides vers FastAPI (Render)
#   4. Réessaie en cas d'échec (jusqu'à 3 fois)
#   5. Rejette les requêtes invalides (403)
#
# =============================================================================

export interface Env {
  WHATSAPP_APP_SECRET: string;
  WHATSAPP_VERIFY_TOKEN: string;
  FASTAPI_WEBHOOK_URL: string;
}

// -----------------------------------------------------------------------------
// Configuration
// -----------------------------------------------------------------------------

const MAX_RETRIES = 3;
const RETRY_DELAY_MS = 500;
const FORWARD_TIMEOUT_MS = 10_000;

// -----------------------------------------------------------------------------
// Utilitaires
// -----------------------------------------------------------------------------

/**
 * Vérifie la signature HMAC-SHA256 envoyée par Meta.
 * Format du header : `sha256=<hex>`
 */
async function verifySignature(
  rawBody: string,
  signatureHeader: string | null,
  appSecret: string
): Promise<boolean> {
  if (!signatureHeader) return false;

  const match = signatureHeader.match(/^sha256=([a-f0-9]+)$/i);
  if (!match) return false;

  const expectedHex = match[1].toLowerCase();

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(appSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(rawBody)
  );

  const computedHex = Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return timingSafeEqual(expectedHex, computedHex);
}

/**
 * Comparaison de chaînes en temps constant (anti timing attack).
 */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Forward le webhook vers FastAPI avec retry.
 */
async function forwardToFastAPI(
  body: string,
  headers: Headers,
  fastApiUrl: string
): Promise<Response> {
  let lastResponse: Response | null = null;

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), FORWARD_TIMEOUT_MS);

      const response = await fetch(fastApiUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Webhook-Source": "cloudflare-worker",
          "X-Webhook-Attempt": attempt.toString(),
          "X-Forwarded-For": headers.get("CF-Connecting-IP") || "",
        },
        body: body,
        signal: controller.signal,
      });

      clearTimeout(timeout);
      lastResponse = response;

      if (response.ok) {
        return new Response(JSON.stringify({
          status: "ok",
          forwarded: true,
          attempt: attempt,
        }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }

      if (response.status >= 400 && response.status < 500) {
        console.error(`FastAPI returned ${response.status} — not retrying`);
        return new Response(JSON.stringify({
          status: "error",
          error: `FastAPI returned ${response.status}`,
          attempt: attempt,
        }), {
          status: 502,
          headers: { "Content-Type": "application/json" },
        });
      }

      console.warn(`FastAPI returned ${response.status}, retrying (attempt ${attempt}/${MAX_RETRIES})`);
    } catch (err) {
      console.error(`Forward attempt ${attempt} failed:`, err);
      lastResponse = null;
    }

    if (attempt < MAX_RETRIES) {
      await sleep(RETRY_DELAY_MS * attempt);
    }
  }

  return new Response(JSON.stringify({
    status: "error",
    error: "FastAPI unreachable after all retries",
    attempts: MAX_RETRIES,
  }), {
    status: 502,
    headers: { "Content-Type": "application/json" },
  });
}

// -----------------------------------------------------------------------------
// Handler principal
// -----------------------------------------------------------------------------

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const method = request.method;

    // Health check
    if (url.pathname === "/health") {
      return new Response(JSON.stringify({
        status: "healthy",
        worker: "vgs-whatsapp-proxy",
        timestamp: new Date().toISOString(),
      }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // GET — Vérification du webhook par Meta
    if (method === "GET") {
      const mode = url.searchParams.get("hub.mode");
      const token = url.searchParams.get("hub.verify_token");
      const challenge = url.searchParams.get("hub.challenge");

      if (mode === "subscribe" && token === env.WHATSAPP_VERIFY_TOKEN) {
        console.log("Webhook verification successful");
        return new Response(challenge || "", {
          status: 200,
          headers: { "Content-Type": "text/plain" },
        });
      }

      console.warn("Webhook verification failed — invalid token or mode");
      return new Response("Forbidden", { status: 403 });
    }

    // POST — Réception d'un webhook WhatsApp
    if (method === "POST") {
      const rawBody = await request.text();

      // Valider la signature HMAC-SHA256
      const signatureHeader = request.headers.get("X-Hub-Signature-256");
      const isValid = await verifySignature(
        rawBody,
        signatureHeader,
        env.WHATSAPP_APP_SECRET
      );

      if (!isValid) {
        console.warn("Invalid webhook signature — rejecting");
        return new Response(JSON.stringify({
          status: "error",
          error: "Invalid signature",
        }), {
          status: 403,
          headers: { "Content-Type": "application/json" },
        });
      }

      // Vérifier que le corps est du JSON valide
      try {
        JSON.parse(rawBody);
      } catch {
        console.warn("Invalid JSON body — rejecting");
        return new Response(JSON.stringify({
          status: "error",
          error: "Invalid JSON",
        }), {
          status: 400,
          headers: { "Content-Type": "application/json" },
        });
      }

      // Forward vers FastAPI avec retry
      console.log("Webhook signature valid — forwarding to FastAPI");
      return forwardToFastAPI(rawBody, request.headers, env.FASTAPI_WEBHOOK_URL);
    }

    return new Response("Method not allowed", { status: 405 });
  },
};
