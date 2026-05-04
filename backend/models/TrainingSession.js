const mongoose = require('mongoose');

const trainingSessionSchema = new mongoose.Schema({
  athlete:          { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  date:             { type: Date, default: Date.now },

  // Readiness (1 = best, 5 = worst)
  sleep:            { type: Number, min: 1, max: 5 },
  wellness:         { type: Number, min: 1, max: 5 },
  soreness:         { type: Number, min: 1, max: 5 },
  fatigue:          { type: Number, min: 1, max: 5 },

  // Primary session
  primaryTypes:     [String],
  primaryDuration:  Number,
  primaryRpe:       { type: Number, min: 1, max: 10 },

  // Secondary session
  hasSecondary:     { type: Boolean, default: false },
  secondaryTypes:   [String],
  secondaryDuration: Number,
  secondaryRpe:     { type: Number, min: 1, max: 10 },

  // Additional metrics
  distance:         Number,
  sprints:          Number,
  maxHR:            Number,
  avgHR:            Number,

  // Skill session
  hasSkill:         { type: Boolean, default: false },
  skillTypes:       [String],
  skillDuration:    Number,
  skillRpe:         { type: Number, min: 1, max: 10 },
  ballsBowled:      Number,
  skillMaxHR:       Number,
  skillAvgHR:       Number,

  // Computed & stored for fast queries
  primaryLoad:      Number,
  secondaryLoad:    Number,
  skillLoad:        Number,
  totalLoad:        Number,
  scaledGrade:      Number,
  readinessPercent: Number,

  createdAt:        { type: Date, default: Date.now },
});

trainingSessionSchema.index({ athlete: 1, date: -1 });
trainingSessionSchema.index({ date: -1 });

trainingSessionSchema.pre('save', function (next) {
  this.primaryLoad   = (this.primaryRpe || 0) * (this.primaryDuration || 0);
  this.secondaryLoad = this.hasSecondary
    ? (this.secondaryRpe || 0) * (this.secondaryDuration || 0)
    : 0;
  this.skillLoad     = this.hasSkill
    ? (this.skillRpe || 0) * (this.skillDuration || 0)
    : 0;
  this.totalLoad     = this.primaryLoad + this.secondaryLoad + this.skillLoad;
  this.scaledGrade   = this.totalLoad > 0
    ? (Math.log(this.totalLoad) / Math.log(1000)) * 10
    : 0;

  const sl = this.sleep    || 3;
  const wl = this.wellness || 3;
  const so = this.soreness || 3;
  const fa = this.fatigue  || 3;
  this.readinessPercent =
    ((5 - sl) + (5 - wl) + (5 - so) + (5 - fa)) / 16 * 100;

  next();
});

module.exports = mongoose.model('TrainingSession', trainingSessionSchema);
