const router          = require('express').Router();
const TrainingSession = require('../models/TrainingSession');
const { authenticate } = require('../middleware/auth');
const { requireFeature } = require('../middleware/entitlements');

router.use(authenticate);
// Sessions carry the workload, recovery, and load-modulation data — all part
// of the base plan, so holding any one of those features unlocks the API.
router.use(requireFeature('workload_monitoring', 'recovery', 'load_modulation'));

// POST /api/sessions  — log a new session
router.post('/', async (req, res) => {
  try {
    const session = await TrainingSession.create({
      ...req.body,
      athlete: req.user._id,
    });
    res.status(201).json(session);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// GET /api/sessions  — own sessions (with optional date filters)
router.get('/', async (req, res) => {
  try {
    const { from, to, date, limit = 100, skip = 0 } = req.query;
    const query = { athlete: req.user._id };

    if (date) {
      const d    = new Date(date);
      const next = new Date(d);
      next.setDate(next.getDate() + 1);
      query.date = { $gte: d, $lt: next };
    } else {
      if (from || to) query.date = {};
      if (from) query.date.$gte = new Date(from);
      if (to)   query.date.$lte = new Date(to);
    }

    const sessions = await TrainingSession.find(query)
      .sort({ date: -1 })
      .skip(Number(skip))
      .limit(Number(limit));

    res.json(sessions);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/sessions/:id
router.get('/:id', async (req, res) => {
  try {
    const session = await TrainingSession.findOne({
      _id: req.params.id,
      athlete: req.user._id,
    });
    if (!session) return res.status(404).json({ error: 'Not found' });
    res.json(session);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/sessions/:id — edit an existing session
router.put('/:id', async (req, res) => {
  try {
    const session = await TrainingSession.findOneAndUpdate(
      { _id: req.params.id, athlete: req.user._id },
      { $set: req.body },
      { new: true, runValidators: true }
    );
    if (!session) return res.status(404).json({ error: 'Not found' });
    res.json(session);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// DELETE /api/sessions/:id
router.delete('/:id', async (req, res) => {
  try {
    await TrainingSession.findOneAndDelete({
      _id: req.params.id,
      athlete: req.user._id,
    });
    res.json({ message: 'Deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
