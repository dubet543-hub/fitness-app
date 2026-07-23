const jwt = require('jsonwebtoken');
const { createPublicKey } = require('crypto');

// ── Google / Apple identity-token verification ──────────────────────────────
//
// Both providers hand the app a signed JWT ("ID token" for Google, "identity
// token" for Apple). Trusting the email inside it without checking the
// signature would let anyone mint a session for any account, so every token is
// verified against the provider's published signing keys before we look at a
// single claim.
//
// Uses only `jsonwebtoken` plus Node's built-in JWK support — no extra deps.

const PROVIDERS = {
  google: {
    jwks:    'https://www.googleapis.com/oauth2/v3/certs',
    issuers: ['accounts.google.com', 'https://accounts.google.com'],
    envIds:  'GOOGLE_CLIENT_IDS',
  },
  apple: {
    jwks:    'https://appleid.apple.com/auth/keys',
    issuers: ['https://appleid.apple.com'],
    envIds:  'APPLE_CLIENT_IDS',
  },
};

// Signing keys rotate, so they are re-fetched periodically. A `kid` miss also
// forces a refresh, which covers a rotation happening mid-cache-window.
const KEY_TTL_MS = 60 * 60 * 1000;
const cache = {}; // provider -> { fetchedAt, keys: { kid: pem } }

async function fetchKeys(provider) {
  const res = await fetch(PROVIDERS[provider].jwks);
  if (!res.ok) throw new Error(`Could not fetch ${provider} signing keys`);
  const { keys } = await res.json();
  const pems = {};
  for (const jwk of keys) {
    pems[jwk.kid] = createPublicKey({ key: jwk, format: 'jwk' })
      .export({ type: 'spki', format: 'pem' });
  }
  cache[provider] = { fetchedAt: Date.now(), keys: pems };
  return pems;
}

async function publicKeyFor(provider, kid) {
  const cached = cache[provider];
  const fresh = cached && Date.now() - cached.fetchedAt < KEY_TTL_MS;
  if (fresh && cached.keys[kid]) return cached.keys[kid];
  const keys = await fetchKeys(provider); // stale, or an unknown kid → refresh
  if (!keys[kid]) throw new Error(`Unknown ${provider} signing key`);
  return keys[kid];
}

/// Allowed audiences, i.e. the client IDs this backend issues sessions for.
/// Comma-separated in the environment: an app that signs in from iOS, Android,
/// and the web presents a different `aud` on each platform.
function allowedAudiences(provider) {
  const raw = process.env[PROVIDERS[provider].envIds] || '';
  const ids = raw.split(',').map((s) => s.trim()).filter(Boolean);
  if (!ids.length) {
    throw new Error(
      `${PROVIDERS[provider].envIds} is not configured — refusing to accept ${provider} sign-ins`);
  }
  return ids;
}

/// Verifies a provider identity token and returns its claims. Throws when the
/// signature, issuer, audience, or expiry does not check out.
async function verifyIdentityToken(provider, token) {
  if (!PROVIDERS[provider]) throw new Error(`Unsupported provider ${provider}`);
  if (!token || typeof token !== 'string') throw new Error('Missing identity token');

  const decoded = jwt.decode(token, { complete: true });
  if (!decoded?.header?.kid) throw new Error('Malformed identity token');

  const key = await publicKeyFor(provider, decoded.header.kid);
  const payload = jwt.verify(token, key, {
    algorithms: [decoded.header.alg === 'ES256' ? 'ES256' : 'RS256'],
    audience:   allowedAudiences(provider),
    issuer:     PROVIDERS[provider].issuers,
  });

  // Google marks unverified addresses; Apple only ever returns verified ones.
  if (provider === 'google' && payload.email && payload.email_verified === false) {
    throw new Error('Google account email is not verified');
  }
  if (!payload.sub) throw new Error('Identity token has no subject');
  return payload;
}

module.exports = { verifyIdentityToken };
