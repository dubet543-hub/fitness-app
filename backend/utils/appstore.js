// ── Apple StoreKit 2 transaction verification ───────────────────────────────
// The `in_app_purchase` Flutter plugin's `serverVerificationData` on modern
// iOS is a StoreKit 2 signed JWS transaction (three dot-separated base64url
// segments, header starting `eyJhbGci...`) — NOT the legacy base64 App Store
// receipt blob. Sending it to the old /verifyReceipt REST endpoint fails with
// status 21002 ("malformed receipt data") because that endpoint only ever
// understood the old format. This verifies the JWS directly against Apple's
// own signature instead, per Apple's official app-store-server-library.

const fs = require('fs');
const path = require('path');
const {
  SignedDataVerifier, VerificationException, VerificationStatus, Environment,
} = require('@apple/app-store-server-library');

class AppStoreConfigError extends Error {}

const BUNDLE_ID = 'com.solidcore.ams';
const ROOT_CA = fs.readFileSync(path.join(__dirname, '../certs/AppleRootCA-G3.cer'));

let sandboxVerifier = null;
let productionVerifier = null;

function sharedSecretConfigured() {
  // Historical name from the legacy receipt-verification env var; kept so
  // existing Render config doesn't need renaming. Its presence is still the
  // signal that Apple IAP has been set up for this deployment.
  return !!process.env.APPLE_IAP_SHARED_SECRET;
}

/** True when Apple IAP verification is configured. */
function paymentsConfiguredApple() {
  return sharedSecretConfigured();
}

function getSandboxVerifier() {
  if (!sharedSecretConfigured()) {
    throw new AppStoreConfigError('APPLE_IAP_SHARED_SECRET is not configured');
  }
  if (!sandboxVerifier) {
    sandboxVerifier = new SignedDataVerifier(
      [ROOT_CA], true, Environment.SANDBOX, BUNDLE_ID);
  }
  return sandboxVerifier;
}

/**
 * Production verification needs the app's numeric App Store Connect id
 * (Apple ID), which only exists once the app has a real App Store listing —
 * set APPLE_APP_STORE_ID once that's available. Until then, production
 * purchases simply can't be verified yet, which is fine pre-launch.
 */
function getProductionVerifier() {
  const appAppleId = process.env.APPLE_APP_STORE_ID;
  if (!appAppleId) return null;
  if (!productionVerifier) {
    productionVerifier = new SignedDataVerifier(
      [ROOT_CA], true, Environment.PRODUCTION, BUNDLE_ID, appAppleId);
  }
  return productionVerifier;
}

/**
 * Verify a StoreKit 2 signed transaction and return its key fields. Tries
 * sandbox first (where all TestFlight/development purchases live) and falls
 * back to production — mirroring the old 21007 sandbox/prod retry, just for
 * the new format.
 * @returns {{transactionId: string, productId: string, purchaseDate: Date}}
 */
async function verifyTransaction({ signedTransaction }) {
  let decoded;
  try {
    decoded = await getSandboxVerifier().verifyAndDecodeTransaction(signedTransaction);
  } catch (err) {
    if (!(err instanceof VerificationException) ||
        err.status !== VerificationStatus.INVALID_ENVIRONMENT) {
      throw err;
    }
    const prodVerifier = getProductionVerifier();
    if (!prodVerifier) {
      throw new Error('Production Apple purchases are not verifiable yet '
        + '(APPLE_APP_STORE_ID not configured)');
    }
    decoded = await prodVerifier.verifyAndDecodeTransaction(signedTransaction);
  }

  if (!decoded.transactionId || !decoded.productId) {
    throw new Error('Verified transaction is missing required fields');
  }

  return {
    transactionId: decoded.transactionId,
    productId: decoded.productId,
    purchaseDate: new Date(decoded.purchaseDate),
  };
}

module.exports = { verifyTransaction, paymentsConfiguredApple, AppStoreConfigError };
