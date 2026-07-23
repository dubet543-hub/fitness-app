// ── Entitlements engine ─────────────────────────────────────────────────────
//
// Single source of truth for "what can this athlete use right now". The API
// middleware, the user-facing subscription endpoint, and the admin panel all
// answer that question through computeEntitlements() so they can never
// disagree.
//
// computeEntitlements() is deliberately pure (plain objects in, plain object
// out, caller supplies `now`) so the state machine is unit-testable without a
// database.

const FEATURES = {
  workload_monitoring: 'Workload Monitoring',
  recovery:            'Proactive Recovery',
  load_modulation:     'Strategic Load Modulation',
  body_composition:    'Body Composition Analysis',
  posture:             'Postural Analysis',
  corrective:          'Corrective Measures',
  running:             'Running Mechanics',
  bowling:             'Bowling Analysis',
};
const ALL_FEATURES = Object.keys(FEATURES);

// Seed catalogue — inserted once if missing; after that the Plan documents are
// the source of truth and the admin edits them freely.
const DEFAULT_PLANS = [
  {
    key: 'athlete_optimisation',
    name: 'Athlete Optimisation',
    priceInr: 20000,
    durationDays: 365,
    order: 1,
    features: ['workload_monitoring', 'recovery', 'load_modulation', 'body_composition'],
  },
  {
    key: 'solidcore_bio_lab',
    name: 'Solidcore Bio-Lab',
    priceInr: 25000,
    durationDays: 365,
    order: 2,
    features: ALL_FEATURES,
  },
];

/**
 * Derive the effective subscription state.
 *
 * @param {object|null} sub      Subscription document (or plain object)
 * @param {object[]}    plans    Plan documents (active catalogue)
 * @param {object}      settings { trialDays, graceDays }
 * @param {Date}        now
 * @returns {{status, plan, planName, features, expiresAt, trialEndsAt,
 *            graceEndsAt, complimentary, overrides}}
 *
 * Statuses: trial | active | grace | expired | suspended | cancelled | none
 */
function computeEntitlements(sub, plans, settings, now = new Date()) {
  const result = {
    status: 'none',
    plan: null,
    planName: null,
    features: [],
    expiresAt: null,
    trialEndsAt: null,
    graceEndsAt: null,
    complimentary: false,
    overrides: { grant: [], revoke: [] },
  };
  if (!sub) return result;

  result.trialEndsAt   = sub.trialEndsAt || null;
  result.expiresAt     = sub.expiresAt || null;
  result.complimentary = !!sub.complimentary;
  result.overrides = {
    grant:  sub.featureOverrides?.grant  || [],
    revoke: sub.featureOverrides?.revoke || [],
  };

  const planDoc = sub.plan ? plans.find((p) => p.key === sub.plan) : null;
  if (planDoc) {
    result.plan = planDoc.key;
    result.planName = planDoc.name;
  }

  // Admin states override everything date-based.
  if (sub.status === 'suspended') {
    result.status = 'suspended';
    return finish(result); // overrides do NOT apply while suspended
  }
  if (sub.status === 'cancelled') {
    result.status = 'cancelled';
    return finish(result, /*base*/ []); // grants still honoured (admin-granted access)
  }

  if (sub.status === 'trial') {
    if (sub.trialEndsAt && now <= new Date(sub.trialEndsAt)) {
      result.status = 'trial';
      return finish(result, ALL_FEATURES); // trial = every feature, per spec
    }
    result.status = 'expired';
    return finish(result, []);
  }

  // status === 'active' — walk the date windows.
  if (sub.status === 'active' && planDoc) {
    const expiresAt = sub.expiresAt ? new Date(sub.expiresAt) : null;
    if (!expiresAt || now <= expiresAt) {
      result.status = 'active';
      return finish(result, planDoc.features);
    }
    const graceDays = sub.graceDays ?? settings.graceDays ?? 0;
    const graceEnd = new Date(expiresAt.getTime() + graceDays * 86400000);
    if (now <= graceEnd) {
      result.status = 'grace';
      result.graceEndsAt = graceEnd;
      return finish(result, planDoc.features);
    }
    result.status = 'expired';
    return finish(result, []);
  }

  // 'active' without a recognised plan (plan deleted/deactivated) → grants only.
  if (sub.status === 'active') {
    result.status = 'active';
    return finish(result, []);
  }

  return result;

  function finish(res, baseFeatures = null) {
    if (baseFeatures === null) { res.features = []; return res; } // suspended
    const set = new Set(baseFeatures);
    for (const f of res.overrides.grant) set.add(f);
    for (const f of res.overrides.revoke) set.delete(f);
    res.features = [...set].filter((f) => ALL_FEATURES.includes(f));
    return res;
  }
}

// ── Database helpers ────────────────────────────────────────────────────────

function models() {
  // Late-required so the pure part of this module can be unit-tested without
  // mongoose being connected.
  return {
    Plan:         require('../models/Plan'),
    Subscription: require('../models/Subscription'),
    Audit:        require('../models/SubscriptionAudit'),
    AppSettings:  require('../models/AppSettings'),
  };
}

/** Idempotent seeding of the plan catalogue + settings singleton. */
async function seedBilling() {
  const { Plan, AppSettings } = models();
  for (const plan of DEFAULT_PLANS) {
    await Plan.updateOne(
      { key: plan.key },
      { $setOnInsert: plan },
      { upsert: true }
    );
  }
  await AppSettings.billing();
  console.log('✓ Subscription plans ready');
}

/** Append an audit entry. Never throws — auditing must not break the action. */
async function audit(userId, actorId, action, before, after, note = '') {
  try {
    const { Audit } = models();
    await Audit.create({ user: userId, actor: actorId || null, action, before, after, note });
  } catch (err) {
    console.error('[audit] failed to record', action, err.message);
  }
}

/** Start the signup free trial for a user (idempotent). */
async function startTrial(userId, actorId = null, note = 'Signup free trial') {
  const { Subscription, AppSettings } = models();
  const existing = await Subscription.findOne({ user: userId });
  if (existing) return existing;
  const settings = await AppSettings.billing();
  const sub = await Subscription.create({
    user: userId,
    status: 'trial',
    trialEndsAt: new Date(Date.now() + settings.trialDays * 86400000),
  });
  await audit(userId, actorId, 'trial_started', null, sub.toObject(), note);
  return sub;
}

/**
 * Subscription for a user, creating the trial lazily for accounts that
 * predate the subscription system so they also get the free month.
 */
async function getOrCreateSubscription(userId) {
  const { Subscription } = models();
  return (await Subscription.findOne({ user: userId })) || startTrial(userId);
}

/** Entitlements for a user, straight from the database. */
async function entitlementsFor(userId, now = new Date()) {
  const { Plan, AppSettings } = models();
  const [sub, plans, settings] = await Promise.all([
    getOrCreateSubscription(userId),
    Plan.find({}),
    AppSettings.billing(),
  ]);
  return computeEntitlements(sub, plans, settings, now);
}

module.exports = {
  FEATURES,
  ALL_FEATURES,
  DEFAULT_PLANS,
  computeEntitlements,
  seedBilling,
  startTrial,
  getOrCreateSubscription,
  entitlementsFor,
  audit,
};
