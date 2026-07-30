const mongoose = require('mongoose');

const trainingSessionSchema = new mongoose.Schema({
  athlete:          { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  date:             { type: Date, default: Date.now },

  // Readiness (1 = best, 5 = worst)
  sleep:            { type: Number, min: 1, max: 5 },
  wellness:         { type: Number, min: 1, max: 5 },
  soreness:         { type: Number, min: 1, max: 5 },
  fatigue:          { type: Number, min: 1, max: 5 },

  // Sleep details (always collected)
  sleepTimeToBed:   { type: String }, // "HH:MM" 24h format
  sleepFellAsleep:  { type: String }, // "HH:MM" 24h format
  sleepWakeUpTime:  { type: String }, // "HH:MM" 24h format
  sleepOutOfBedTime: { type: String }, // "HH:MM" 24h format
  sleepDisturbances:       { type: Boolean, default: false },
  sleepDisturbanceDetails: { type: String },
  sleepDisturbanceMinutes: { type: Number },
  sleepRoomTemp:    { type: String },
  sleepRoomNoise:   { type: String },
  sleepRoomLight:   { type: String },
  sleepDuration:    { type: Number }, // hours, computed from bed/wake times
  sleepTimeInBedMinutes: { type: Number }, // out-of-bed minus time-to-bed
  sleepMinutes:     { type: Number },       // wake minus fell-asleep, less disturbance minutes
  sleepEfficiency:  { type: Number },        // sleepMinutes / sleepTimeInBedMinutes, 0-100

  // Mood questions (collected when wellness >= 3 OR fatigue >= 3)
  // motivation: very_low | low | moderate | high | very_high
  moodMotivation:   { type: String },
  // appetite: no_change | decreased | increased
  moodAppetite:     { type: String },
  // external factors: academic | family | relationship | financial | injury | coach_team | none
  moodExternalFactors: [String],
  // psychologist: yes_urgent | yes_this_week | maybe | no
  moodNeedsPsychologist: { type: String },

  // Fatigue questions (collected when wellness >= 3 OR fatigue >= 3)
  // symptoms: heavy_legs | headache | loss_of_appetite | increased_hr | slow_recovery | frequent_illness | joint_pain | none
  fatigueSymptoms:  [String],
  // performance: significant | slight | stable | improved
  fatiguePerformanceDecrease: { type: String },
  fatiguePerformanceDescription: { type: String },

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
  skillSubTypes:    [String],
  skillSubDuration: Number,
  skillSubRpe:      { type: Number, min: 1, max: 10 },
  ballsBowled:      Number,
  subBallsBowled:   Number,
  skillMaxHR:       Number,
  skillAvgHR:       Number,

  // Session information
  sessionType:      { type: String, trim: true }, // "Match day", "Strength Program", etc.

  // Computed & stored for fast queries
  primaryLoad:      Number,
  secondaryLoad:    Number,
  skillLoad:        Number,
  totalLoad:        Number,
  scaledGrade:      Number,
  readinessPercent: Number,
  standardDeviation: Number,
  zScore:           Number,

  createdAt:        { type: Date, default: Date.now },
});

trainingSessionSchema.index({ athlete: 1, date: -1 });
trainingSessionSchema.index({ date: -1 });

function parseSleepDuration(bedTime, wakeTime) {
  if (!bedTime || !wakeTime) return undefined;
  const [bh, bm] = bedTime.split(':').map(Number);
  const [wh, wm] = wakeTime.split(':').map(Number);
  if (isNaN(bh) || isNaN(bm) || isNaN(wh) || isNaN(wm)) return undefined;
  let diffMins = (wh * 60 + wm) - (bh * 60 + bm);
  if (diffMins < 0) diffMins += 24 * 60; // midnight crossing
  return Math.round((diffMins / 60) * 100) / 100;
}

// "HH:MM" -> minutes from midnight, or null if unparsable.
function toMinutes(hhmm) {
  if (!hhmm) return null;
  const [h, m] = hhmm.split(':').map(Number);
  if (Number.isNaN(h) || Number.isNaN(m)) return null;
  return h * 60 + m;
}

// Wraps a minute difference into [0, 1440) — same MOD(x, 1) the sheet uses,
// mirrored from lib/services/sleep_metrics.dart so client and server agree.
function wrapMinutes(diff) {
  return ((diff % 1440) + 1440) % 1440;
}

// Mirrors SleepNight in lib/services/sleep_metrics.dart: sleep time, time in
// bed and efficiency all derive from the same four clocks so this stays the
// authoritative calculation regardless of what (if anything) the client sent.
function computeSleepMetrics(doc) {
  const timeToBed = toMinutes(doc.sleepTimeToBed);
  const wokeUp    = toMinutes(doc.sleepWakeUpTime);
  if (timeToBed === null || wokeUp === null) return {};

  // Fall back to the bed/wake clocks when the finer-grained ones are absent,
  // same as nightFromLog's fallback on the client.
  const fellAsleep = toMinutes(doc.sleepFellAsleep) ?? timeToBed;
  const outOfBed   = toMinutes(doc.sleepOutOfBedTime) ?? wokeUp;
  const awakeMinutes = doc.sleepDisturbances ? (doc.sleepDisturbanceMinutes || 0) : 0;

  const sleepMinutes = Math.max(0, Math.min(1440,
    wrapMinutes(wokeUp - fellAsleep) - awakeMinutes));
  const timeInBedMinutes = wrapMinutes(outOfBed - timeToBed);
  const efficiency = timeInBedMinutes > 0
    ? Math.round((sleepMinutes / timeInBedMinutes) * 100 * 100) / 100
    : 0;

  return { sleepMinutes, timeInBedMinutes, efficiency };
}

trainingSessionSchema.pre('save', function (next) {
  this.sleepDuration = parseSleepDuration(this.sleepTimeToBed, this.sleepWakeUpTime);

  const { sleepMinutes, timeInBedMinutes, efficiency } = computeSleepMetrics(this);
  if (sleepMinutes !== undefined) {
    this.sleepMinutes          = sleepMinutes;
    this.sleepTimeInBedMinutes = timeInBedMinutes;
    this.sleepEfficiency       = efficiency;
  }

  this.primaryLoad   = (this.primaryRpe || 0) * (this.primaryDuration || 0);
  this.secondaryLoad = this.hasSecondary
    ? (this.secondaryRpe || 0) * (this.secondaryDuration || 0)
    : 0;
  const skillMain = this.hasSkill
    ? (this.skillRpe || 0) * (this.skillDuration || 0)
    : 0;
  const skillSub = this.hasSkill
    ? (this.skillSubRpe || 0) * (this.skillSubDuration || 0)
    : 0;
  this.skillLoad     = skillMain + skillSub;
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

  // Z-Score and stdDev require historical context; computed in summary endpoint, not per-session
  this.standardDeviation = 0;
  this.zScore = 0;

  next();
});

module.exports = mongoose.model('TrainingSession', trainingSessionSchema);
