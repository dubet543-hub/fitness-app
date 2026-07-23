// Verification for the subscription system. Plain node + assert, no test
// framework (matches test-api.js style). Run: node test-subscriptions.js
//
// 1. computeEntitlements state machine — pure, exhaustive over the states.
// 2. requireFeature middleware — allow / deny / admin bypass, via stubs.
// 3. Admin action routes end-to-end over express with stubbed models —
//    assign → downgrade → upgrade → suspend → resume → cancel → extend →
//    overrides — asserting the audit trail records every step.

const assert = require('assert');
const { computeEntitlements, ALL_FEATURES } = require('./utils/entitlements');

const DAY = 86400000;
const NOW = new Date('2026-07-24T12:00:00Z');
const days = (n) => new Date(NOW.getTime() + n * DAY);

const PLANS = [
  { key: 'athlete_optimisation', name: 'Athlete Optimisation', priceInr: 20000, durationDays: 365,
    features: ['workload_monitoring', 'recovery', 'load_modulation', 'body_composition'] },
  { key: 'solidcore_bio_lab', name: 'Solidcore Bio-Lab', priceInr: 25000, durationDays: 365,
    features: ALL_FEATURES },
];
const SETTINGS = { trialDays: 30, graceDays: 7 };
const ent = (sub) => computeEntitlements(sub, PLANS, SETTINGS, NOW);

let passed = 0;
function check(label, fn) {
  try { fn(); passed++; console.log('  ✓', label); }
  catch (e) { console.error('  ✗', label, '\n   ', e.message); process.exitCode = 1; }
}

console.log('computeEntitlements:');

check('no subscription → none, no features', () => {
  const e = ent(null);
  assert.equal(e.status, 'none');
  assert.deepEqual(e.features, []);
});

check('live trial → all features', () => {
  const e = ent({ status: 'trial', trialEndsAt: days(10) });
  assert.equal(e.status, 'trial');
  assert.deepEqual([...e.features].sort(), [...ALL_FEATURES].sort());
});

check('ended trial → expired, nothing unlocked', () => {
  const e = ent({ status: 'trial', trialEndsAt: days(-1) });
  assert.equal(e.status, 'expired');
  assert.deepEqual(e.features, []);
});

check('active base plan → exactly its four features', () => {
  const e = ent({ status: 'active', plan: 'athlete_optimisation', expiresAt: days(100) });
  assert.equal(e.status, 'active');
  assert.deepEqual([...e.features].sort(),
    ['body_composition', 'load_modulation', 'recovery', 'workload_monitoring']);
  assert.ok(!e.features.includes('posture'), 'Bio-Lab feature must stay locked');
});

check('active Bio-Lab → all eight features', () => {
  const e = ent({ status: 'active', plan: 'solidcore_bio_lab', expiresAt: days(100) });
  assert.deepEqual([...e.features].sort(), [...ALL_FEATURES].sort());
});

check('expired 3 days ago with 7-day grace → grace, features kept', () => {
  const e = ent({ status: 'active', plan: 'athlete_optimisation', expiresAt: days(-3) });
  assert.equal(e.status, 'grace');
  assert.ok(e.features.includes('workload_monitoring'));
  assert.equal(+e.graceEndsAt, +days(4));
});

check('expired past grace → expired, locked', () => {
  const e = ent({ status: 'active', plan: 'athlete_optimisation', expiresAt: days(-8) });
  assert.equal(e.status, 'expired');
  assert.deepEqual(e.features, []);
});

check('per-athlete graceDays overrides the default', () => {
  const e = ent({ status: 'active', plan: 'athlete_optimisation', expiresAt: days(-8), graceDays: 30 });
  assert.equal(e.status, 'grace');
});

check('suspended → locked even mid-term, overrides ignored', () => {
  const e = ent({ status: 'suspended', plan: 'solidcore_bio_lab', expiresAt: days(100),
    featureOverrides: { grant: ['posture'], revoke: [] } });
  assert.equal(e.status, 'suspended');
  assert.deepEqual(e.features, []);
});

check('cancelled → locked, but explicit grants persist', () => {
  const e = ent({ status: 'cancelled', plan: 'athlete_optimisation',
    featureOverrides: { grant: ['recovery'], revoke: [] } });
  assert.equal(e.status, 'cancelled');
  assert.deepEqual(e.features, ['recovery']);
});

check('grant adds a Bio-Lab feature on the base plan', () => {
  const e = ent({ status: 'active', plan: 'athlete_optimisation', expiresAt: days(50),
    featureOverrides: { grant: ['bowling'], revoke: [] } });
  assert.ok(e.features.includes('bowling'));
});

check('revoke removes a plan feature for one athlete', () => {
  const e = ent({ status: 'active', plan: 'solidcore_bio_lab', expiresAt: days(50),
    featureOverrides: { grant: [], revoke: ['bowling'] } });
  assert.ok(!e.features.includes('bowling'));
  assert.ok(e.features.includes('posture'));
});

check('complimentary flag carries through', () => {
  const e = ent({ status: 'active', plan: 'solidcore_bio_lab', expiresAt: days(10), complimentary: true });
  assert.equal(e.complimentary, true);
});

// ── Middleware + admin routes over express with stubbed models ─────────────

const Module = require('module');
const path = require('path');

// In-memory model stubs, injected via the require cache before the routes load.
const state = {
  sub: null,
  audits: [],
  settings: { key: 'billing', trialDays: 30, graceDays: 7, save: async () => {}, updatedAt: new Date() },
};

class FakeSub {
  constructor(doc) { Object.assign(this, {
    status: 'trial', plan: null, graceDays: null, complimentary: false,
    featureOverrides: { grant: [], revoke: [] }, statusBeforeSuspend: null, notes: '',
  }, doc); }
  toObject() { const { save, toObject, ...rest } = this; return JSON.parse(JSON.stringify(rest)); }
  async save() { state.sub = this; return this; }
}
FakeSub.findOne = async (q) => state.sub;
FakeSub.create = async (doc) => { state.sub = new FakeSub(doc); return state.sub; };
FakeSub.find = async () => (state.sub ? [state.sub] : []);

const FakePlan = {
  findOne: async ({ key }) => PLANS.find((p) => p.key === key) || null,
  find: async () => PLANS,
};
const FakeAudit = {
  create: async (doc) => { state.audits.push(doc); return doc; },
  find: () => ({ sort: () => ({ limit: () => ({ populate: () => ({ populate: async () => state.audits }) }) }) }),
};
const FakeSettings = { billing: async () => state.settings };

function stub(relPath, exports) {
  const full = require.resolve(relPath);
  delete require.cache[full];
  require.cache[full] = { id: full, filename: full, loaded: true, exports };
}
stub('./models/Plan', FakePlan);
stub('./models/Subscription', FakeSub);
stub('./models/SubscriptionAudit', FakeAudit);
stub('./models/AppSettings', FakeSettings);
// utils/entitlements late-requires the models, so it picks the stubs up.
delete require.cache[require.resolve('./utils/entitlements')];
delete require.cache[require.resolve('./middleware/entitlements')];
delete require.cache[require.resolve('./routes/adminSubscriptions')];

const { requireFeature } = require('./middleware/entitlements');

async function runMiddleware(mw, user) {
  return new Promise((resolve) => {
    const req = { user };
    const res = {
      statusCode: 200,
      status(c) { this.statusCode = c; return this; },
      json(body) { resolve({ status: this.statusCode, body, nexted: false }); },
    };
    mw(req, res, () => resolve({ status: 200, body: null, nexted: true }));
  });
}

(async () => {
  console.log('requireFeature middleware:');
  const athlete = { _id: 'u1', role: 'athlete' };

  state.sub = new FakeSub({ user: 'u1', status: 'trial', trialEndsAt: days(5) });
  let r = await runMiddleware(requireFeature('bowling'), athlete);
  check('trial passes any feature gate', () => assert.ok(r.nexted));

  state.sub = new FakeSub({ user: 'u1', status: 'active', plan: 'athlete_optimisation', expiresAt: days(50) });
  r = await runMiddleware(requireFeature('posture'), athlete);
  check('base plan blocked from Bio-Lab feature with SUBSCRIPTION_REQUIRED', () => {
    assert.equal(r.status, 403);
    assert.equal(r.body.code, 'SUBSCRIPTION_REQUIRED');
  });
  r = await runMiddleware(requireFeature('workload_monitoring', 'recovery'), athlete);
  check('any-of gate passes on base plan', () => assert.ok(r.nexted));

  state.sub = new FakeSub({ user: 'u1', status: 'suspended', plan: 'solidcore_bio_lab', expiresAt: days(50) });
  r = await runMiddleware(requireFeature('recovery'), athlete);
  check('suspended athlete is blocked everywhere', () => assert.equal(r.status, 403));

  r = await runMiddleware(requireFeature('recovery'), { _id: 'a1', role: 'admin' });
  check('admin bypasses feature gates', () => assert.ok(r.nexted));

  // ── Admin actions round-trip ────────────────────────────────────────────
  console.log('admin subscription actions:');
  const express = require('express');
  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => { req.user = { _id: 'admin1', role: 'admin' }; next(); });
  app.use(require('./routes/adminSubscriptions'));
  const server = app.listen(0);
  const base = `http://localhost:${server.address().port}`;
  const act = async (body) => {
    const res = await fetch(`${base}/athletes/u1/subscription`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    return { status: res.status, body: await res.json() };
  };

  state.sub = new FakeSub({ user: 'u1', status: 'trial', trialEndsAt: days(3) });
  state.audits = [];

  r = await act({ action: 'assign', plan: 'solidcore_bio_lab', note: 'paid ₹25,000' });
  check('assign Bio-Lab → active with all features', () => {
    assert.equal(r.status, 200);
    assert.equal(r.body.subscription.status, 'active');
    assert.ok(r.body.entitlements.features.includes('bowling'));
  });

  r = await act({ action: 'change_plan', plan: 'athlete_optimisation', note: 'downgrade' });
  check('downgrade locks Bio-Lab features, keeps expiry', () => {
    assert.equal(r.status, 200);
    assert.ok(!r.body.entitlements.features.includes('bowling'));
    assert.ok(r.body.entitlements.features.includes('recovery'));
    assert.ok(r.body.subscription.expiresAt, 'term dates survive the downgrade');
  });

  r = await act({ action: 'change_plan', plan: 'solidcore_bio_lab', note: 'upgrade again' });
  check('upgrade restores Bio-Lab access', () =>
    assert.ok(r.body.entitlements.features.includes('bowling')));

  r = await act({ action: 'suspend' });
  check('suspend empties features', () =>
    assert.deepEqual(r.body.entitlements.features, []));

  r = await act({ action: 'resume' });
  check('resume returns to active', () =>
    assert.equal(r.body.subscription.status, 'active'));

  const beforeExtend = new Date(state.sub.expiresAt).getTime();
  r = await act({ action: 'extend', days: 30 });
  check('extend adds 30 days to the term', () =>
    assert.equal(new Date(r.body.subscription.expiresAt).getTime(), beforeExtend + 30 * DAY));

  r = await act({ action: 'override_features', revoke: ['bowling'], grant: [] });
  check('per-athlete revoke applies immediately', () =>
    assert.ok(!r.body.entitlements.features.includes('bowling')));

  r = await act({ action: 'override_features', grant: ['nonsense'], revoke: [] });
  check('unknown feature keys are rejected', () => assert.equal(r.status, 400));

  r = await act({ action: 'cancel' });
  check('cancel ends access', () =>
    assert.equal(r.body.entitlements.status, 'cancelled'));

  // ── Purchase flow (Razorpay) ────────────────────────────────────────────
  console.log('purchase flow:');
  process.env.RAZORPAY_KEY_ID = 'rzp_test_key';
  process.env.RAZORPAY_KEY_SECRET = 'test-secret';
  const crypto = require('crypto');
  const rz = require('./utils/razorpay');

  check('signature verification accepts the genuine HMAC only', () => {
    const sig = crypto.createHmac('sha256', 'test-secret')
      .update('order_1|pay_1').digest('hex');
    assert.ok(rz.verifySignature({ orderId: 'order_1', paymentId: 'pay_1', signature: sig }));
    assert.ok(!rz.verifySignature({ orderId: 'order_1', paymentId: 'pay_1', signature: 'f'.repeat(64) }));
    assert.ok(!rz.verifySignature({ orderId: 'order_2', paymentId: 'pay_1', signature: sig }));
  });

  // Stub PaymentOrder + Razorpay's REST call, then run order → verify end-to-end
  // over the user-facing subscription router.
  const orders = [];
  class FakeOrder {
    constructor(doc) { Object.assign(this, { status: 'created' }, doc); }
    async save() { return this; }
  }
  FakeOrder.create = async (doc) => { const o = new FakeOrder(doc); orders.push(o); return o; };
  FakeOrder.findOne = async (q) =>
    orders.find((o) => o.orderId === q.orderId && String(o.user) === String(q.user)
      && o.status === q.status) || null;
  stub('./models/PaymentOrder', FakeOrder);
  const userModelPath = require.resolve('./models/User');
  require.cache[userModelPath] = { id: userModelPath, filename: userModelPath, loaded: true,
    exports: { findById: () => ({ select: async () => ({ _id: 'u1', role: 'athlete', active: true }) }) } };
  delete require.cache[require.resolve('./middleware/auth')];
  delete require.cache[require.resolve('./routes/subscription')];

  const realFetch = global.fetch;
  global.fetch = async (url, opts) => {
    if (String(url).includes('api.razorpay.com')) {
      const req = JSON.parse(opts.body);
      return { ok: true, json: async () => ({ id: 'order_test_1', amount: req.amount }) };
    }
    return realFetch(url, opts);
  };

  const jwt = require('jsonwebtoken');
  process.env.JWT_SECRET = process.env.JWT_SECRET || 'x';
  const token = jwt.sign({ id: 'u1' }, process.env.JWT_SECRET);
  const app2 = express();
  app2.use(express.json());
  app2.use('/api/subscription', require('./routes/subscription'));
  const server2 = app2.listen(0);
  const base2 = `http://localhost:${server2.address().port}/api/subscription`;
  const call = async (path, body) => {
    const res = await fetch(`${base2}${path}`, {
      method: body ? 'POST' : 'GET',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: body ? JSON.stringify(body) : undefined,
    });
    return { status: res.status, body: await res.json() };
  };

  state.sub = new FakeSub({ user: 'u1', status: 'trial', trialEndsAt: days(20) });
  r = await call('/order', { plan: 'solidcore_bio_lab' });
  check('mid-trial purchase: order created with key + paise amount', () => {
    assert.equal(r.status, 200);
    assert.equal(r.body.orderId, 'order_test_1');
    assert.equal(r.body.keyId, 'rzp_test_key');
    assert.equal(r.body.amountPaise, 25000 * 100);
  });

  const goodSig = crypto.createHmac('sha256', 'test-secret')
    .update('order_test_1|pay_test_1').digest('hex');

  r = await call('/verify', { orderId: 'order_test_1', paymentId: 'pay_test_1', signature: 'bad' });
  check('forged signature rejected, plan NOT activated', () => {
    assert.equal(r.status, 400);
    assert.equal(state.sub.status, 'trial');
  });

  // failed attempt consumed the order; recreate for the genuine one
  orders[0].status = 'created';
  r = await call('/verify', { orderId: 'order_test_1', paymentId: 'pay_test_1', signature: goodSig });
  check('verified payment activates the plan for a full term', () => {
    assert.equal(r.status, 200);
    assert.equal(r.body.subscription.status, 'active');
    assert.equal(r.body.subscription.plan, 'solidcore_bio_lab');
    assert.ok(r.body.entitlements.features.includes('bowling'));
  });

  r = await call('/verify', { orderId: 'order_test_1', paymentId: 'pay_test_1', signature: goodSig });
  check('an order cannot be redeemed twice', () => assert.equal(r.status, 400));

  check('purchase recorded in the audit trail', () => {
    const last = state.audits[state.audits.length - 1];
    assert.equal(last.action, 'purchase');
    assert.ok(/pay_test_1/.test(last.note));
  });

  server2.close();
  global.fetch = realFetch;

  check('audit trail recorded every action with before/after', () => {
    const admin = state.audits.filter((a) => a.actor === 'admin1');
    assert.deepEqual(admin.map((a) => a.action), ['assign', 'change_plan',
      'change_plan', 'suspend', 'resume', 'extend', 'override_features', 'cancel']);
    for (const a of admin) assert.ok(a.before && a.after, `${a.action} missing snapshots`);
  });

  server.close();
  console.log(`\n${passed} checks passed${process.exitCode ? ' — WITH FAILURES' : ''}`);
})();
