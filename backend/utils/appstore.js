// ── Apple App Store receipt verification ────────────────────────────────────
// Classic `verifyReceipt` endpoint + an app-specific shared secret — no SDK
// dependency, mirroring razorpay.js's plain-fetch approach.

class AppStoreConfigError extends Error {}

const PROD_URL    = 'https://buy.itunes.apple.com/verifyReceipt';
const SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';

function sharedSecret() {
  const secret = process.env.APPLE_IAP_SHARED_SECRET;
  if (!secret) {
    throw new AppStoreConfigError('APPLE_IAP_SHARED_SECRET is not configured');
  }
  return secret;
}

/** True when Apple IAP receipt verification is configured. */
function paymentsConfiguredApple() {
  return !!process.env.APPLE_IAP_SHARED_SECRET;
}

async function postReceipt(url, receiptData, secret) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      'receipt-data': receiptData,
      password: secret,
      'exclude-old-transactions': true,
    }),
  });
  return res.json();
}

/**
 * Verify a StoreKit receipt against Apple's servers and return the latest
 * transaction. Sandbox receipts submitted to the prod endpoint come back with
 * status 21007 — Apple's documented signal to retry against sandbox, which
 * happens for every TestFlight/sandbox purchase, so this retry is mandatory.
 * @returns {{transactionId: string, productId: string, purchaseDate: Date}}
 */
async function verifyReceipt({ receiptData }) {
  const secret = sharedSecret();
  // TEMP diagnostic: shape of what the client actually sent, to distinguish
  // a truncated/empty receipt from a StoreKit-2 JWS (three dot-separated
  // base64url segments) being sent to this StoreKit-1-only endpoint.
  console.log('[payments] receipt diagnostic:', {
    length: receiptData?.length,
    dotSegments: receiptData?.split('.').length,
    head: receiptData?.slice(0, 24),
    tail: receiptData?.slice(-24),
  });
  let body = await postReceipt(PROD_URL, receiptData, secret);
  if (body.status === 21007) {
    body = await postReceipt(SANDBOX_URL, receiptData, secret);
  }
  if (body.status !== 0) {
    throw new Error(`Apple receipt verification failed (status ${body.status})`);
  }

  const transactions = body.latest_receipt_info || body.receipt?.in_app || [];
  if (!transactions.length) {
    throw new Error('Receipt contained no transactions');
  }
  const latest = transactions.reduce((a, b) =>
    Number(b.purchase_date_ms) > Number(a.purchase_date_ms) ? b : a);

  return {
    transactionId: latest.transaction_id,
    productId: latest.product_id,
    purchaseDate: new Date(Number(latest.purchase_date_ms)),
  };
}

module.exports = { verifyReceipt, paymentsConfiguredApple, AppStoreConfigError };
