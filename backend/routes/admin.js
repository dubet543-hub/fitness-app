const router            = require('express').Router();
const User              = require('../models/User');
const TrainingSession   = require('../models/TrainingSession');
const BodyComposition   = require('../models/BodyComposition');
const Subscription      = require('../models/Subscription');
const SubscriptionAudit = require('../models/SubscriptionAudit');
const PaymentOrder      = require('../models/PaymentOrder');
const { authenticate, requireAdmin } = require('../middleware/auth');
const M                = require('../utils/metrics');

router.use(authenticate, requireAdmin);

// Subscription management (plans, settings, per-athlete actions, audit trail)
const adminSubscriptions = require('./adminSubscriptions');
router.use(adminSubscriptions);

// ── Athletes ───────────────────────────────────────────────────────────────────

// GET /api/admin/athletes
router.get('/athletes', async (req, res) => {
  try {
    const athletes = await User.find({ role: 'athlete' })
      .select('-password')
      .sort({ createdAt: -1 });

    // One batched lookup for every athlete's subscription state (list chips).
    const subSummaries = await adminSubscriptions.summariseAll(athletes.map((a) => a._id));

    // Attach last session info + app-consistent metrics
    const withStats = await Promise.all(athletes.map(async (a) => {
      const last = await TrainingSession.findOne({ athlete: a._id }).sort({ date: -1 });
      const readinessPct = last?.readinessPercent ?? null;
      return {
        ...a.toJSON(),
        subscription:      subSummaries[String(a._id)],
        lastSession:       last?.date      || null,
        lastTotalLoad:     last?.totalLoad || null,
        lastReadiness:     readinessPct,
        lastExertion:      last ? M.round(M.exertion(last.totalLoad)) : null,
        flagged:           readinessPct != null ? M.isFlagged({ readinessPercent: readinessPct }) : false,
      };
    }));
    res.json(withStats);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/athletes  — create athlete (admin only)
router.post('/athletes', async (req, res) => {
  try {
    const { name, email, password, sport } = req.body;
    if (!name || !email || !password)
      return res.status(400).json({ error: 'name, email and password required' });

    const exists = await User.findOne({ email });
    if (exists) return res.status(409).json({ error: 'Email already registered' });

    const athlete = await User.create({
      name,
      email,
      password,
      sport,
      role: 'athlete',
      createdBy: req.user._id,
    });
    await require('../utils/entitlements').startTrial(athlete._id, req.user._id);
    res.status(201).json(athlete);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// GET /api/admin/athletes/:id
router.get('/athletes/:id', async (req, res) => {
  try {
    const athlete = await User.findById(req.params.id).select('-password');
    if (!athlete) return res.status(404).json({ error: 'Not found' });
    res.json(athlete);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/admin/athletes/:id
router.put('/athletes/:id', async (req, res) => {
  try {
    const { name, sport, active } = req.body;
    const athlete = await User.findByIdAndUpdate(
      req.params.id,
      { name, sport, active },
      { new: true, runValidators: true }
    ).select('-password');
    res.json(athlete);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// POST /api/admin/athletes/:id/reset-password  — set a new password for an
// athlete who's lost/forgotten theirs. Goes through .save() rather than
// findByIdAndUpdate, since only the pre('save') hook hashes it.
router.post('/athletes/:id/reset-password', async (req, res) => {
  try {
    const { password } = req.body;
    if (!password || password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters.' });
    }
    const athlete = await User.findOne({ _id: req.params.id, role: 'athlete' });
    if (!athlete) return res.status(404).json({ error: 'Athlete not found' });
    athlete.password = password;
    await athlete.save();
    res.json({ message: 'Password reset' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// DELETE /api/admin/athletes/:id  — soft delete
router.delete('/athletes/:id', async (req, res) => {
  try {
    await User.findByIdAndUpdate(req.params.id, { active: false });
    res.json({ message: 'Athlete deactivated' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/admin/athletes/:id/permanent  — erases the athlete and every
// record tied to them (sessions, body composition, subscriptions). Cannot be undone.
router.delete('/athletes/:id/permanent', async (req, res) => {
  try {
    const athlete = await User.findOne({ _id: req.params.id, role: 'athlete' });
    if (!athlete) return res.status(404).json({ error: 'Athlete not found' });

    await Promise.all([
      TrainingSession.deleteMany({ athlete: athlete._id }),
      BodyComposition.deleteMany({ athlete: athlete._id }),
      Subscription.deleteMany({ user: athlete._id }),
      SubscriptionAudit.deleteMany({ user: athlete._id }),
      PaymentOrder.deleteMany({ user: athlete._id }),
    ]);
    await athlete.deleteOne();

    res.json({ message: 'Athlete permanently deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Body composition ─────────────────────────────────────────────────────────

// GET /api/admin/athletes/:id/body-composition  — latest estimate + history,
// synced from the athlete's app.
router.get('/athletes/:id/body-composition', async (req, res) => {
  try {
    const { limit = 24 } = req.query;
    const records = await BodyComposition.find({ athlete: req.params.id })
      .sort({ date: -1, createdAt: -1 });
    // Older app builds uploaded each reading twice; collapse records that share
    // a measurement timestamp so each reading appears once.
    const seen = new Set();
    const history = records
      .filter(r => {
        const key = r.date?.getTime();
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      })
      .slice(0, Number(limit));
    res.json({
      latest:  history[0] || null,
      history: history.slice(1), // older entries only; latest is returned separately
      synced:  history.length > 0,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/athletes/:id/body-composition  — a coach enters/corrects a
// measurement on the athlete's behalf (e.g. relayed over phone/WhatsApp,
// rather than the athlete running the analysis themselves in the app).
// Upserts on (athlete, date) like the athlete's own sync route, so
// re-submitting the same day's entry corrects it instead of duplicating.
router.post('/athletes/:id/body-composition', async (req, res) => {
  try {
    const athlete = await User.findOne({ _id: req.params.id, role: 'athlete' });
    if (!athlete) return res.status(404).json({ error: 'Athlete not found' });

    const { date: rawDate, ...fields } = req.body;
    const date = rawDate ? new Date(rawDate) : new Date();
    if (isNaN(date)) return res.status(400).json({ error: 'Invalid date' });

    const entry = await BodyComposition.findOneAndUpdate(
      { athlete: athlete._id, date },
      { $set: { ...fields, date, athlete: athlete._id } },
      { upsert: true, new: true, runValidators: true, setDefaultsOnInsert: true },
    );
    res.status(201).json(entry);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// PUT /api/admin/athletes/:id/body-composition/:recordId  — update one
// existing reading directly by its id. The create route above upserts by
// matching (athlete, date) exactly, which silently misses an entry that
// isn't at precise UTC midnight (e.g. one the app itself synced with a
// real timestamp) — editing by id always hits the right document.
router.put('/athletes/:id/body-composition/:recordId', async (req, res) => {
  try {
    const { date: rawDate, ...fields } = req.body;
    const update = { ...fields };
    if (rawDate) {
      const date = new Date(rawDate);
      if (isNaN(date)) return res.status(400).json({ error: 'Invalid date' });
      update.date = date;
    }
    const entry = await BodyComposition.findOneAndUpdate(
      { _id: req.params.recordId, athlete: req.params.id },
      { $set: update },
      { new: true, runValidators: true },
    );
    if (!entry) return res.status(404).json({ error: 'Reading not found' });
    res.json(entry);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// DELETE /api/admin/athletes/:id/body-composition/:recordId  — removes one
// reading, e.g. a stray duplicate left over from a mismatched upsert.
router.delete('/athletes/:id/body-composition/:recordId', async (req, res) => {
  try {
    const result = await BodyComposition.deleteOne({ _id: req.params.recordId, athlete: req.params.id });
    if (!result.deletedCount) return res.status(404).json({ error: 'Reading not found' });
    res.json({ message: 'Reading deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Sessions ───────────────────────────────────────────────────────────────────

// GET /api/admin/athletes/:id/sessions
router.get('/athletes/:id/sessions', async (req, res) => {
  try {
    const { from, to, date, limit = 100 } = req.query;
    const query = { athlete: req.params.id };

    if (date) {
      const d = new Date(date);
      const n = new Date(d); n.setDate(n.getDate() + 1);
      query.date = { $gte: d, $lt: n };
    } else {
      if (from || to) query.date = {};
      if (from) query.date.$gte = new Date(from);
      if (to)   query.date.$lte = new Date(to);
    }

    const sessions = await TrainingSession.find(query)
      .sort({ date: -1 })
      .limit(Number(limit));
    res.json(sessions);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/admin/athletes/:id/summary  — computed ACWR, acute/chronic load, z-score,
// targets, plus app-consistent exertion / composite performance / zone / flag.
router.get('/athletes/:id/summary', async (req, res) => {
  try {
    const sessions = await TrainingSession.find({ athlete: req.params.id })
      .sort({ date: 1 })
      .select('date totalLoad primaryLoad secondaryLoad skillLoad readinessPercent scaledGrade');

    const summary = M.loadSummary(sessions);
    const lastReadiness = sessions.length
      ? (sessions[sessions.length - 1]?.readinessPercent ?? null)
      : null;
    const lastLoad = sessions.length ? (sessions[sessions.length - 1]?.totalLoad || 0) : 0;

    res.json({
      ...summary,
      lastReadiness,
      exertion:    M.round(M.exertion(lastLoad)),                         // 0–10, matches app
      performance: Math.round(M.performance((lastReadiness ?? 0) / 100, summary.acwr) * 100), // %, composite
      zone:        M.acwrZone(summary.acwr),                             // { label, level, color }
      flagged:     M.isFlagged({ acwr: summary.acwr, readinessPercent: lastReadiness ?? 100 }),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Dashboard overview ─────────────────────────────────────────────────────────

// GET /api/admin/dashboard
router.get('/dashboard', async (req, res) => {
  try {
    const totalAthletes  = await User.countDocuments({ role: 'athlete' });
    const totalSessions  = await TrainingSession.countDocuments();

    const avgLoadArr = await TrainingSession.aggregate([
      { $group: { _id: null, avg: { $avg: '$totalLoad' } } },
    ]);
    const avgLoad = Math.round(avgLoadArr[0]?.avg || 0);

    // Sessions per day (last 30 days)
    const thirtyDaysAgo = new Date(); thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const sessionsPerDay = await TrainingSession.aggregate([
      { $match: { date: { $gte: thirtyDaysAgo } } },
      { $group: {
          _id:   { $dateToString: { format: '%Y-%m-%d', date: '$date' } },
          count: { $sum: 1 },
          avgLoad: { $avg: '$totalLoad' },
        }
      },
      { $sort: { _id: 1 } },
    ]);

    const recentSessions = await TrainingSession.find({
      date: { $gte: new Date(Date.now() - 7 * 86400000) },
    }).populate('athlete', 'name email').sort({ date: -1 });

    // Flagged athletes (ACWR > 1.5 or readiness < 25%) — computed with the same
    // ACWR logic as the per-athlete summary so flags are consistent.
    const athletes = await User.find({ role: 'athlete' }).select('name email');
    const flaggedAthletes = [];
    await Promise.all(athletes.map(async (a) => {
      const sessions = await TrainingSession.find({ athlete: a._id })
        .sort({ date: 1 }).select('date totalLoad readinessPercent');
      if (!sessions.length) return;
      const { acwr } = M.loadSummary(sessions);
      const readinessPercent = sessions[sessions.length - 1]?.readinessPercent ?? 100;
      if (M.isFlagged({ acwr, readinessPercent })) {
        flaggedAthletes.push({
          _id: a._id, name: a.name, email: a.email,
          acwr, readinessPercent: M.round(readinessPercent),
          zone: M.acwrZone(acwr),
          reason: acwr > 1.5
            ? (readinessPercent < 25 ? 'High ACWR & low readiness' : 'High ACWR')
            : 'Low readiness',
        });
      }
    }));

    res.json({
      totalAthletes, totalSessions, avgLoad, sessionsPerDay,
      flaggedAthletes, recentSessions,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/admin/sessions  — all sessions, filterable by date
router.get('/sessions', async (req, res) => {
  try {
    const { date, from, to, athleteId, limit = 200 } = req.query;
    const query = {};
    if (athleteId) query.athlete = athleteId;

    if (date) {
      const d = new Date(date);
      const n = new Date(d); n.setDate(n.getDate() + 1);
      query.date = { $gte: d, $lt: n };
    } else {
      if (from || to) query.date = {};
      if (from) query.date.$gte = new Date(from);
      if (to)   query.date.$lte = new Date(to);
    }

    const sessions = await TrainingSession.find(query)
      .sort({ date: -1 })
      .limit(Number(limit))
      .populate('athlete', 'name email sport');

    res.json(sessions);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
