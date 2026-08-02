const mongoose = require('mongoose');

// Singleton document (key: 'billing') holding admin-tunable defaults for the
// subscription system. Changing these applies immediately — no deploy.
const appSettingsSchema = new mongoose.Schema({
  key: { type: String, required: true, unique: true },

  // Free-trial length for new signups, in days.
  trialDays: { type: Number, default: 15, min: 0 },

  // Default continued-access window after a term expires. A per-athlete
  // graceDays on the subscription overrides this.
  graceDays: { type: Number, default: 7, min: 0 },

  updatedAt: { type: Date, default: Date.now },
});

appSettingsSchema.statics.billing = async function () {
  // Upsert so the singleton always exists and first read seeds the defaults.
  return this.findOneAndUpdate(
    { key: 'billing' },
    { $setOnInsert: { key: 'billing' } },
    { new: true, upsert: true }
  );
};

module.exports = mongoose.model('AppSettings', appSettingsSchema);
