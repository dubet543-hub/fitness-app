const router       = require('express').Router();
const Plan         = require('../models/Plan');
const Subscription = require('../models/Subscription');
const Audit        = require('../models/SubscriptionAudit');
const AppSettings  = require('../models/AppSettings');
const {
  ALL_FEATURES, FEATURES, computeEntitlements,
  getOrCreateSubscription, entitlementsFor, audit,
} = require('../utils/entitlements');

// Mounted inside routes/admin.js, so authenticate + requireAdmin already ran.

const DAY = 86400000;

function badFeatures(list) {
  return (list || []).filter((f) => !ALL_FEATURES.includes(f));
}

// ── Billing configuration ──────────────────────────────────────────────────

// GET /api/admin/billing — settings + full plan catalogue + feature vocabulary
router.get('/billing', async (_req, res) => {
  try {
    const [settings, plans] = await Promise.all([
      AppSettings.billing(),
      Plan.find({}).sort({ order: 1 }),
    ]);
    res.json({
      settings: { trialDays: settings.trialDays, graceDays: settings.graceDays },
      plans,
      featureNames: FEATURES,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/admin/billing/settings — trial length + default grace period
router.put('/billing/settings', async (req, res) => {
  try {
    const { trialDays, graceDays } = req.body;
    const settings = await AppSettings.billing();
    const before = { trialDays: settings.trialDays, graceDays: settings.graceDays };
    if (trialDays !== undefined) {
      if (!(Number(trialDays) >= 0)) return res.status(400).json({ error: 'trialDays must be ≥ 0' });
      settings.trialDays = Number(trialDays);
    }
    if (graceDays !== undefined) {
      if (!(Number(graceDays) >= 0)) return res.status(400).json({ error: 'graceDays must be ≥ 0' });
      settings.graceDays = Number(graceDays);
    }
    settings.updatedAt = new Date();
    await settings.save();
    const after = { trialDays: settings.trialDays, graceDays: settings.graceDays };
    await audit(req.user._id, req.user._id, 'settings_updated', before, after,
      'Billing defaults changed');
    res.json({ settings: after });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/admin/billing/plans/:key — price, features, name, duration, availability
router.put('/billing/plans/:key', async (req, res) => {
  try {
    const plan = await Plan.findOne({ key: req.params.key });
    if (!plan) return res.status(404).json({ error: 'Plan not found' });

    const { name, priceInr, durationDays, features, active, order, appleProductId } = req.body;
    if (features !== undefined) {
      const bad = badFeatures(features);
      if (bad.length) return res.status(400).json({ error: `Unknown features: ${bad.join(', ')}` });
    }
    const before = plan.toObject();
    if (name         !== undefined) plan.name         = String(name);
    if (priceInr     !== undefined) plan.priceInr     = Number(priceInr);
    if (durationDays !== undefined) plan.durationDays = Number(durationDays);
    if (features     !== undefined) plan.features     = features;
    if (active       !== undefined) plan.active       = !!active;
    if (order        !== undefined) plan.order        = Number(order);
    // Empty string clears the mapping rather than tripping the unique index
    // with multiple plans stored as "".
    if (appleProductId !== undefined) {
      plan.appleProductId = appleProductId ? String(appleProductId) : undefined;
    }
    await plan.save();
    await audit(req.user._id, req.user._id, 'plan_updated', before, plan.toObject(),
      `Plan ${plan.key} edited`);
    res.json(plan);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// ── Per-athlete subscription management ────────────────────────────────────

// GET /api/admin/athletes/:id/subscription — record + effective access + history
router.get('/athletes/:id/subscription', async (req, res) => {
  try {
    const [subscription, entitlements, history] = await Promise.all([
      getOrCreateSubscription(req.params.id),
      entitlementsFor(req.params.id),
      Audit.find({ user: req.params.id })
        .sort({ createdAt: -1 }).limit(100)
        .populate('actor', 'name email'),
    ]);
    res.json({ subscription, entitlements, history });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/athletes/:id/subscription — every management action.
// Body: { action, note?, ...params }. Only ever rewrites the Subscription
// document — athlete data is untouched by design, so upgrades/downgrades
// lock and unlock features over the same retained records.
router.post('/athletes/:id/subscription', async (req, res) => {
  try {
    const { action, note = '' } = req.body;
    const sub = await getOrCreateSubscription(req.params.id);
    const before = sub.toObject();

    switch (action) {
      // Assign (or renew) a plan. Also covers complimentary subscriptions.
      case 'assign': {
        const plan = await Plan.findOne({ key: req.body.plan });
        if (!plan) return res.status(400).json({ error: 'Unknown plan' });
        sub.plan = plan.key;
        sub.status = 'active';
        sub.startsAt = new Date();
        sub.expiresAt = req.body.expiresAt
          ? new Date(req.body.expiresAt)
          : new Date(Date.now() + plan.durationDays * DAY);
        sub.complimentary = !!req.body.complimentary;
        sub.statusBeforeSuspend = null;
        break;
      }

      // Upgrade/downgrade in place: plan changes, dates stay, data untouched.
      case 'change_plan': {
        const plan = await Plan.findOne({ key: req.body.plan });
        if (!plan) return res.status(400).json({ error: 'Unknown plan' });
        if (sub.status !== 'active')
          return res.status(400).json({ error: 'No active subscription — use assign instead' });
        sub.plan = plan.key;
        break;
      }

      case 'suspend':
        if (sub.status === 'suspended')
          return res.status(400).json({ error: 'Already suspended' });
        sub.statusBeforeSuspend = sub.status;
        sub.status = 'suspended';
        break;

      case 'resume':
        if (sub.status !== 'suspended')
          return res.status(400).json({ error: 'Not suspended' });
        sub.status = sub.statusBeforeSuspend || (sub.plan ? 'active' : 'trial');
        sub.statusBeforeSuspend = null;
        break;

      case 'cancel':
        sub.status = 'cancelled';
        sub.statusBeforeSuspend = null;
        break;

      // Extend the current term (or trial) by N days, or to an explicit date.
      case 'extend': {
        if (sub.status === 'trial') {
          const base = sub.trialEndsAt && sub.trialEndsAt > new Date() ? sub.trialEndsAt : new Date();
          if (req.body.days == null) return res.status(400).json({ error: 'days required' });
          sub.trialEndsAt = new Date(base.getTime() + Number(req.body.days) * DAY);
        } else if (req.body.expiresAt) {
          sub.expiresAt = new Date(req.body.expiresAt);
        } else if (req.body.days != null) {
          const base = sub.expiresAt && sub.expiresAt > new Date() ? sub.expiresAt : new Date();
          sub.expiresAt = new Date(base.getTime() + Number(req.body.days) * DAY);
        } else {
          return res.status(400).json({ error: 'days or expiresAt required' });
        }
        break;
      }

      case 'set_expiry':
        if (!req.body.expiresAt) return res.status(400).json({ error: 'expiresAt required' });
        sub.expiresAt = new Date(req.body.expiresAt);
        break;

      case 'set_trial':
        if (!req.body.trialEndsAt) return res.status(400).json({ error: 'trialEndsAt required' });
        sub.trialEndsAt = new Date(req.body.trialEndsAt);
        break;

      // Per-athlete grace override; null falls back to the global default.
      case 'set_grace':
        sub.graceDays = req.body.graceDays == null ? null : Number(req.body.graceDays);
        break;

      // Individual access control on top of the plan.
      case 'override_features': {
        const grant  = req.body.grant  || [];
        const revoke = req.body.revoke || [];
        const bad = [...badFeatures(grant), ...badFeatures(revoke)];
        if (bad.length) return res.status(400).json({ error: `Unknown features: ${bad.join(', ')}` });
        sub.featureOverrides = { grant, revoke };
        break;
      }

      default:
        return res.status(400).json({ error: `Unknown action '${action}'` });
    }

    await sub.save();
    await audit(req.params.id, req.user._id, action, before, sub.toObject(), note);

    const entitlements = await entitlementsFor(req.params.id);
    res.json({ subscription: sub, entitlements });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// GET /api/admin/billing/audit?athlete=&limit= — the complete change history
router.get('/billing/audit', async (req, res) => {
  try {
    const q = req.query.athlete ? { user: req.query.athlete } : {};
    const limit = Math.min(Number(req.query.limit) || 200, 500);
    const entries = await Audit.find(q)
      .sort({ createdAt: -1 }).limit(limit)
      .populate('user', 'name email')
      .populate('actor', 'name email');
    res.json(entries);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

// Small helper reused by the athletes list to avoid N×3 queries.
module.exports.summariseAll = async function summariseAll(userIds) {
  const [subs, plans, settings] = await Promise.all([
    Subscription.find({ user: { $in: userIds } }),
    Plan.find({}),
    AppSettings.billing(),
  ]);
  const byUser = new Map(subs.map((s) => [String(s.user), s]));
  const out = {};
  for (const id of userIds) {
    const ent = computeEntitlements(byUser.get(String(id)) || null, plans, settings);
    out[String(id)] = {
      status: ent.status, plan: ent.plan, planName: ent.planName,
      expiresAt: ent.expiresAt, trialEndsAt: ent.trialEndsAt,
      complimentary: ent.complimentary,
    };
  }
  return out;
};
