const router = require('express').Router();
const Plan         = require('../models/Plan');
const PaymentOrder = require('../models/PaymentOrder');
const { authenticate } = require('../middleware/auth');
const {
  entitlementsFor, getOrCreateSubscription, activatePlan, FEATURES,
} = require('../utils/entitlements');
const {
  createOrder, verifySignature, paymentsConfigured, RazorpayConfigError,
} = require('../utils/razorpay');
const {
  verifyTransaction, paymentsConfiguredApple, AppStoreConfigError,
} = require('../utils/appstore');

router.use(authenticate);

// GET /api/subscription/me — the signed-in athlete's effective access, plus
// the plan catalogue so the app can render the paywall/upgrade page from live
// prices rather than anything hard-coded.
router.get('/me', async (req, res) => {
  try {
    const [entitlements, plans] = await Promise.all([
      entitlementsFor(req.user._id),
      Plan.find({ active: true }).sort({ order: 1 }),
    ]);
    res.json({
      entitlements,
      featureNames: FEATURES,
      // Buy buttons only render when the server can actually take payments —
      // `enabled` is a back-compat alias for "at least one provider works".
      payments: {
        enabled: paymentsConfigured() || paymentsConfiguredApple(),
        razorpay: paymentsConfigured(),
        apple: paymentsConfiguredApple(),
      },
      plans: plans.map((p) => ({
        key: p.key,
        name: p.name,
        priceInr: p.priceInr,
        durationDays: p.durationDays,
        features: p.features,
        appleProductId: p.appleProductId || null,
      })),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Purchase flow ───────────────────────────────────────────────────────────
// Buying is open in every self-serve state — including mid-trial — except
// suspension, which is an admin hold a payment must not silently lift.

// POST /api/subscription/order { plan } → Razorpay order for the checkout UI
router.post('/order', async (req, res) => {
  try {
    const plan = await Plan.findOne({ key: req.body.plan, active: true });
    if (!plan) return res.status(400).json({ error: 'Unknown plan' });

    const sub = await getOrCreateSubscription(req.user._id);
    if (sub.status === 'suspended') {
      return res.status(403).json({
        error: 'Your subscription is suspended. Contact support before purchasing.' });
    }

    // Razorpay caps receipts at 40 chars — tail of the user id + base36 time
    // stays well under while remaining unique enough for reconciliation (the
    // notes carry the full ids).
    const receipt = `sub_${String(req.user._id).slice(-8)}_${Date.now().toString(36)}`;
    const { orderId, keyId, amountPaise } = await createOrder({
      amountInr: plan.priceInr,
      receipt,
      notes: { user: String(req.user._id), plan: plan.key },
    });
    await PaymentOrder.create({
      user: req.user._id,
      plan: plan.key,
      planName: plan.name,
      amountInr: plan.priceInr,
      orderId,
    });
    res.json({
      orderId,
      keyId,
      amountPaise,
      currency: 'INR',
      planName: plan.name,
    });
  } catch (err) {
    if (err instanceof RazorpayConfigError) {
      console.warn('[payments]', err.message);
      return res.status(503).json({ error: 'Payments are not available right now.' });
    }
    res.status(500).json({ error: err.message });
  }
});

// POST /api/subscription/verify { orderId, paymentId, signature }
// Signature-checked server-side; only then does the plan activate.
router.post('/verify', async (req, res) => {
  try {
    const { orderId, paymentId, signature } = req.body;
    const order = await PaymentOrder.findOne({
      orderId, user: req.user._id, status: 'created',
    });
    if (!order) return res.status(400).json({ error: 'Unknown or already-used order' });

    if (!verifySignature({ orderId, paymentId, signature })) {
      order.status = 'failed';
      await order.save();
      return res.status(400).json({ error: 'Payment could not be verified' });
    }

    const plan = await Plan.findOne({ key: order.plan });
    if (!plan) return res.status(400).json({ error: 'Plan no longer exists' });

    order.status = 'paid';
    order.paymentId = paymentId;
    order.paidAt = new Date();
    await order.save();

    const sub = await activatePlan(req.user._id, req.user._id, plan,
      `Razorpay ${paymentId} — ${plan.name} ₹${order.amountInr}`);

    res.json({
      subscription: sub,
      entitlements: await entitlementsFor(req.user._id),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/subscription/verify-apple { receipt, plan }
// Apple's server is the source of truth for what was actually bought — the
// `plan` param is only a hint for a clearer error message, never trusted for
// activation. The receipt's own product id decides which plan gets applied.
router.post('/verify-apple', async (req, res) => {
  try {
    const { receipt } = req.body;
    if (!receipt) return res.status(400).json({ error: 'Missing receipt' });

    let verified;
    try {
      verified = await verifyTransaction({ signedTransaction: receipt });
    } catch (err) {
      if (err instanceof AppStoreConfigError) {
        console.warn('[payments]', err.message);
        return res.status(503).json({ error: 'Payments are not available right now.' });
      }
      console.error('[payments] Apple transaction verification failed:', err.message);
      return res.status(400).json({ error: 'Could not verify this purchase with Apple.' });
    }

    const plan = await Plan.findOne({ appleProductId: verified.productId, active: true });
    if (!plan) {
      console.error('[payments] No plan matches Apple productId:', verified.productId);
      return res.status(400).json({ error: 'This purchase does not match a known plan.' });
    }

    // Apple's transaction id is stable across re-fetches of the same receipt,
    // so the unique index on orderId is what makes this idempotent — a
    // concurrent double-submit races here and one loses to the index.
    const existing = await PaymentOrder.findOne({ orderId: verified.transactionId });
    if (existing) {
      return res.json({
        subscription: await getOrCreateSubscription(req.user._id),
        entitlements: await entitlementsFor(req.user._id),
      });
    }

    let order;
    try {
      order = await PaymentOrder.create({
        user: req.user._id,
        plan: plan.key,
        planName: plan.name,
        amountInr: plan.priceInr,
        provider: 'apple',
        orderId: verified.transactionId,
        status: 'paid',
        paymentId: verified.transactionId,
        paidAt: verified.purchaseDate,
      });
    } catch (err) {
      if (err.code === 11000) {
        // Lost the create race to a concurrent request — already processed.
        return res.json({
          subscription: await getOrCreateSubscription(req.user._id),
          entitlements: await entitlementsFor(req.user._id),
        });
      }
      throw err;
    }

    const sub = await activatePlan(req.user._id, req.user._id, plan,
      `Apple IAP ${order.orderId} — ${plan.name} ₹${plan.priceInr}`);

    res.json({
      subscription: sub,
      entitlements: await entitlementsFor(req.user._id),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
