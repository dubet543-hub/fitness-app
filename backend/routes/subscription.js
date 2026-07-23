const router = require('express').Router();
const Plan   = require('../models/Plan');
const { authenticate } = require('../middleware/auth');
const { entitlementsFor, FEATURES } = require('../utils/entitlements');

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
      plans: plans.map((p) => ({
        key: p.key,
        name: p.name,
        priceInr: p.priceInr,
        durationDays: p.durationDays,
        features: p.features,
      })),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
