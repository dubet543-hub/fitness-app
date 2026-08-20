const mongoose = require('mongoose');

// Subscription plan catalogue. Seeded with the two annual plans (see
// utils/entitlements.js) but fully editable by the admin — price, feature set,
// duration, and availability are all data, not code, so commercial changes
// never need a deploy.
const planSchema = new mongoose.Schema({
  key:          { type: String, required: true, unique: true }, // stable id, e.g. 'athlete_optimisation'
  name:         { type: String, required: true },
  priceInr:     { type: Number, required: true, min: 0 },       // ₹ per term
  durationDays: { type: Number, required: true, default: 365 }, // term length
  features:     { type: [String], default: [] },                // feature keys (utils/entitlements.js)
  active:       { type: Boolean, default: true },               // hidden from catalogue when false
  order:        { type: Number, default: 0 },                   // display order
  // Matching Non-Renewing Subscription product id in App Store Connect, for
  // the iOS purchase path. Blank hides the plan's Buy button on iOS.
  appleProductId: { type: String, sparse: true, unique: true },
  updatedAt:    { type: Date, default: Date.now },
});

planSchema.pre('save', function (next) {
  this.updatedAt = new Date();
  next();
});

module.exports = mongoose.model('Plan', planSchema);
