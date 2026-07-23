const mongoose = require('mongoose');

// One subscription record per athlete. This document only ever describes
// *access* — which plan, until when, in what state. It never owns athlete
// data, so assigning, upgrading, downgrading, suspending, or cancelling can
// never touch training sessions, body-composition history, or any other
// records: a downgrade locks features, an upgrade unlocks them again over the
// same untouched data.
//
// The effective status (trial / active / grace / expired / …) is *derived* at
// read time from these fields by utils/entitlements.js — nothing needs a cron
// to flip documents over when a date passes.
const subscriptionSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
  },

  // Plan key (Plan.key) — null while on trial or after cancellation.
  plan: { type: String, default: null },

  // Administrative state. Date-based states (grace, expired, trial ended) are
  // derived, not stored.
  //   trial     — signup free period, all features
  //   active    — a plan has been assigned
  //   suspended — admin paused access (reversible, keeps plan + dates)
  //   cancelled — admin ended the subscription (plan kept for the record)
  status: {
    type: String,
    enum: ['trial', 'active', 'suspended', 'cancelled'],
    default: 'trial',
  },

  trialEndsAt: { type: Date },              // end of the signup free month
  startsAt:    { type: Date },              // current term start
  expiresAt:   { type: Date },              // current term end

  // Days of continued access after expiresAt. null → use the global default
  // from AppSettings; admin can override per athlete.
  graceDays: { type: Number, default: null },

  // Complimentary subscriptions behave exactly like paid ones; flagged so the
  // admin panel and audit trail can tell them apart.
  complimentary: { type: Boolean, default: false },

  // Per-athlete access control on top of the plan: grant adds features the
  // plan lacks, revoke removes features the plan includes.
  featureOverrides: {
    grant:  { type: [String], default: [] },
    revoke: { type: [String], default: [] },
  },

  // Which status the subscription was in before a suspension, so resume can
  // put it back (a suspended trial resumes as a trial, not as 'active').
  statusBeforeSuspend: { type: String, default: null },

  notes:     { type: String, default: '' },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

subscriptionSchema.pre('save', function (next) {
  this.updatedAt = new Date();
  next();
});

module.exports = mongoose.model('Subscription', subscriptionSchema);
