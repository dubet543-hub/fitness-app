const mongoose = require('mongoose');

// Body-composition estimate — mirrors the app's on-device analysis
// (lib/screens/body_composition_screen.dart). The Flutter app currently stores
// these locally; this model lets the app sync them so coaches/admins can review
// them. Inputs are the U.S. Navy circumference measurements; the rest are the
// derived anthropometric estimates.
const bodyCompositionSchema = new mongoose.Schema({
  athlete:   { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  date:      { type: Date, default: Date.now },

  // Inputs
  isMale:    { type: Boolean, required: true },
  weightKg:  { type: Number, required: true },
  heightCm:  { type: Number, required: true },
  neckCm:    { type: Number, required: true },
  abdomenCm: { type: Number, required: true },
  hipCm:     { type: Number }, // females only

  // Primary derived composition
  bfPercent:  { type: Number }, // body-fat %
  bfKg:       { type: Number },
  lbm:        { type: Number }, // lean body mass (kg)

  // Key ratios
  smmPercent: { type: Number }, // skeletal muscle mass %
  smi:        { type: Number }, // skeletal muscle index
  ffmi:       { type: Number }, // fat-free mass index

  createdAt:  { type: Date, default: Date.now },
});

bodyCompositionSchema.index({ athlete: 1, date: -1 });

module.exports = mongoose.model('BodyComposition', bodyCompositionSchema);
