const mongoose = require('mongoose');

// Separate from User: a code can be requested for an email that has no
// account yet (the /verify step creates one on success, mirroring federated
// sign-in's create-on-first-sign-in behaviour).
const otpCodeSchema = new mongoose.Schema({
  email:      { type: String, required: true, unique: true, lowercase: true, trim: true },
  codeHash:   { type: String, required: true },
  expiresAt:  { type: Date, required: true },
  attempts:   { type: Number, default: 0 },
  lastSentAt: { type: Date, default: Date.now },
});

// TTL index: Mongo removes the document once expiresAt has passed.
otpCodeSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model('OtpCode', otpCodeSchema);
