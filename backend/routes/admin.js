const router          = require('express').Router();
const User            = require('../models/User');
const TrainingSession = require('../models/TrainingSession');
const { authenticate, requireAdmin } = require('../middleware/auth');

router.use(authenticate, requireAdmin);

// ── Athletes ───────────────────────────────────────────────────────────────────

// GET /api/admin/athletes
router.get('/athletes', async (req, res) => {
  try {
    const athletes = await User.find({ role: 'athlete' })
      .select('-password')
      .sort({ createdAt: -1 });

    // Attach last session info
    const withStats = await Promise.all(athletes.map(async (a) => {
      const last = await TrainingSession.findOne({ athlete: a._id }).sort({ date: -1 });
      return {
        ...a.toJSON(),
        lastSession:       last?.date      || null,
        lastTotalLoad:     last?.totalLoad || null,
        lastReadiness:     last?.readinessPercent || null,
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

// GET /api/admin/athletes/:id/summary  — computed ACWR, acute/chronic load
router.get('/athletes/:id/summary', async (req, res) => {
  try {
    const sessions = await TrainingSession.find({ athlete: req.params.id })
      .sort({ date: 1 })
      .select('date totalLoad readinessPercent');

    if (!sessions.length) return res.json({ acuteLoad: 0, chronicLoad: 0, acwr: 0 });

    const now    = new Date();
    const cutoff = new Date(now); cutoff.setDate(cutoff.getDate() - 7);
    const acuteLoad = sessions
      .filter(s => new Date(s.date) >= cutoff)
      .reduce((sum, s) => sum + (s.totalLoad || 0), 0);

    const lambda = 2 / 29;
    let ewma = sessions[0].totalLoad || 0;
    for (let i = 1; i < sessions.length; i++) {
      ewma = (sessions[i].totalLoad || 0) * lambda + ewma * (1 - lambda);
    }
    const chronicLoad = ewma;
    const acwr        = chronicLoad > 0 ? acuteLoad / chronicLoad : 0;

    res.json({
      acuteLoad:    Math.round(acuteLoad),
      chronicLoad:  Math.round(chronicLoad * 10) / 10,
      acwr:         Math.round(acwr * 100) / 100,
      totalSessions: sessions.length,
      lastReadiness: sessions[sessions.length - 1]?.readinessPercent || null,
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

    // Flagged athletes (ACWR > 1.5 or readiness < 25%)
    const recentSessions = await TrainingSession.find({
      date: { $gte: new Date(Date.now() - 7 * 86400000) },
    }).populate('athlete', 'name email').sort({ date: -1 });

    res.json({ totalAthletes, totalSessions, avgLoad, sessionsPerDay, recentSessions });
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
