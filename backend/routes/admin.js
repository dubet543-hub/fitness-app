const router          = require('express').Router();
const User            = require('../models/User');
const TrainingSession = require('../models/TrainingSession');
const BodyComposition = require('../models/BodyComposition');
const { authenticate, requireAdmin } = require('../middleware/auth');
const M                = require('../utils/metrics');

router.use(authenticate, requireAdmin);

// ── Athletes ───────────────────────────────────────────────────────────────────

// GET /api/admin/athletes
router.get('/athletes', async (req, res) => {
  try {
    const athletes = await User.find({ role: 'athlete' })
      .select('-password')
      .sort({ createdAt: -1 });

    // Attach last session info + app-consistent metrics
    const withStats = await Promise.all(athletes.map(async (a) => {
      const last = await TrainingSession.findOne({ athlete: a._id }).sort({ date: -1 });
      const readinessPct = last?.readinessPercent ?? null;
      return {
        ...a.toJSON(),
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

// DELETE /api/admin/athletes/:id  — soft delete
router.delete('/athletes/:id', async (req, res) => {
  try {
    await User.findByIdAndUpdate(req.params.id, { active: false });
    res.json({ message: 'Athlete deactivated' });
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
    const history = await BodyComposition.find({ athlete: req.params.id })
      .sort({ date: -1 })
      .limit(Number(limit));
    res.json({
      latest:  history[0] || null,
      history, // newest → oldest
      synced:  history.length > 0,
    });
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
      .select('date totalLoad trainingLoad skillLoad readinessPercent scaledGrade');

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
