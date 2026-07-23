const { entitlementsFor } = require('../utils/entitlements');

// Feature gate for API routes. Placed after `authenticate`, it enforces the
// athlete's plan server-side — a locked feature is locked no matter what
// client, URL, or hand-crafted request is used.
//
// `requireFeature('a', 'b')` passes when the subscription includes ANY of the
// listed features (used where one endpoint serves data belonging to several
// features of the same plan).
//
// Admins bypass the gate: the admin panel must be able to review athlete data
// regardless of the athlete's own subscription state.
function requireFeature(...features) {
  return async (req, res, next) => {
    try {
      if (req.user?.role === 'admin') return next();
      const ent = await entitlementsFor(req.user._id);
      req.entitlements = ent; // downstream handlers may want it
      if (features.some((f) => ent.features.includes(f))) return next();

      res.status(403).json({
        code: 'SUBSCRIPTION_REQUIRED',
        status: ent.status,
        feature: features[0],
        error: ent.status === 'suspended'
          ? 'Your subscription is suspended. Contact support to restore access.'
          : ent.status === 'expired' || ent.status === 'cancelled' || ent.status === 'none'
            ? 'Your subscription has ended. Renew your plan to regain access — all your data is safely retained.'
            : 'This feature is not included in your current plan. Upgrade to unlock it.',
      });
    } catch (err) {
      next(err);
    }
  };
}

module.exports = { requireFeature };
