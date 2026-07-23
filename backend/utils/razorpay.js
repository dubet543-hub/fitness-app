const crypto = require('crypto');

// ── Razorpay integration ────────────────────────────────────────────────────
// Uses Razorpay's plain REST API + Node's crypto — no SDK dependency. The key
// secret never leaves the server; the app only ever sees the public key id.

class RazorpayConfigError extends Error {}

function credentials() {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const secret = process.env.RAZORPAY_KEY_SECRET;
  if (!keyId || !secret) {
    throw new RazorpayConfigError('RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET are not configured');
  }
  return { keyId, secret };
}

/** True when payment credentials are configured (drives catalogue `payments` flag). */
function paymentsConfigured() {
  return !!(process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET);
}

/**
 * Create a Razorpay order for `amountInr` rupees.
 * @returns {{orderId: string, keyId: string, amountPaise: number}}
 */
async function createOrder({ amountInr, receipt, notes }) {
  const { keyId, secret } = credentials();
  const amountPaise = Math.round(amountInr * 100);
  const res = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Basic ' + Buffer.from(`${keyId}:${secret}`).toString('base64'),
    },
    body: JSON.stringify({ amount: amountPaise, currency: 'INR', receipt, notes }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || !body.id) {
    throw new Error(body?.error?.description || `Razorpay order failed (${res.status})`);
  }
  return { orderId: body.id, keyId, amountPaise };
}

/**
 * Verify Razorpay's checkout signature: HMAC-SHA256(order_id|payment_id)
 * keyed with the secret must equal the signature Razorpay handed the client.
 */
function verifySignature({ orderId, paymentId, signature }) {
  const { secret } = credentials();
  if (!orderId || !paymentId || !signature) return false;
  const expected = crypto
    .createHmac('sha256', secret)
    .update(`${orderId}|${paymentId}`)
    .digest('hex');
  const a = Buffer.from(expected);
  const b = Buffer.from(String(signature));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

module.exports = { createOrder, verifySignature, paymentsConfigured, RazorpayConfigError };
