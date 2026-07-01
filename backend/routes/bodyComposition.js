const router          = require('express').Router();
const BodyComposition = require('../models/BodyComposition');
const { authenticate } = require('../middleware/auth');

router.use(authenticate);

// POST /api/body-composition  — athlete syncs a computed estimate
router.post('/', async (req, res) => {
  try {
    const entry = await BodyComposition.create({
      ...req.body,
      athlete: req.user._id,
    });
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
