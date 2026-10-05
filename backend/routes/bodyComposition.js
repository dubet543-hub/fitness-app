const router          = require('express').Router();
const BodyComposition = require('../models/BodyComposition');
const { authenticate } = require('../middleware/auth');
const { requireFeature } = require('../middleware/entitlements');

router.use(authenticate);
router.use(requireFeature('body_composition'));

// POST /api/body-composition  — athlete syncs a computed estimate.
// Idempotent per measurement timestamp: the app retries unsynced readings, so a
// re-sent reading updates the stored one instead of adding a duplicate.
router.post('/', async (req, res) => {
  try {
    const { _id, athlete, ...fields } = req.body;
    const date = fields.date ? new Date(fields.date) : null;
    const entry = date && !isNaN(date)
      ? await BodyComposition.findOneAndUpdate(
          { athlete: req.user._id, date },
          { $set: { ...fields, date, athlete: req.user._id } },
          { upsert: true, new: true, runValidators: true, setDefaultsOnInsert: true },
        )
      : await BodyComposition.create({ ...fields, athlete: req.user._id });
    res.status(201).json(entry);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// GET /api/body-composition  — own history (newest first)
router.get('/', async (req, res) => {
  try {
    const { limit = 24 } = req.query;
    const history = await BodyComposition.find({ athlete: req.user._id })
      .sort({ date: -1 })
      .limit(Number(limit));
    res.json(history);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
