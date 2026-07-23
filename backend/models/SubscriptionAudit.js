const mongoose = require('mongoose');

// Append-only audit trail of every subscription change — who did what to
// whose access, when, and what the record looked like before and after.
// Nothing in the codebase updates or deletes these documents.
const subscriptionAuditSchema = new mongoose.Schema({
  user:   { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  actor:  { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, // null → system (e.g. trial at signup)
  action: { type: String, required: true }, // trial_started | assign | change_plan | suspend | resume | cancel | extend | set_expiry | set_trial | override_features | plan_updated | settings_updated | …
  before: { type: Object },                 // subscription snapshot pre-change
  after:  { type: Object },                 // subscription snapshot post-change
  note:   { type: String, default: '' },
  createdAt: { type: Date, default: Date.now, index: true },
});

subscriptionAuditSchema.index({ user: 1, createdAt: -1 });

module.exports = mongoose.model('SubscriptionAudit', subscriptionAuditSchema);
