const router = require('express').Router();
const jwt    = require('jsonwebtoken');
const User   = require('../models/User');
const { authenticate } = require('../middleware/auth');

const sign = (id) =>
  jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });

// POST /api/auth/login  — web email + password
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password)
      return res.status(400).json({ error: 'Email and password required' });

    const user = await User.findOne({ email });
    if (!user || !(await user.comparePassword(password)))
      return res.status(401).json({ error: 'Invalid credentials' });

    if (!user.active)
      return res.status(403).json({ error: 'Account deactivated. Contact admin.' });

    res.json({
      token: sign(user._id),
      user:  { id: user._id, name: user.name, email: user.email, role: user.role, photoUrl: user.photoUrl },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/auth/google  — Flutter sends Google user info after Firebase sign-in
// Backend checks if this email is pre-registered by admin, returns app JWT
router.post('/google', async (req, res) => {
  try {
    const { email, name, photoUrl } = req.body;
    if (!email) return res.status(400).json({ error: 'Email required' });

    const user = await User.findOne({ email });
    if (!user)
      return res.status(403).json({ error: 'Account not registered. Contact your admin.' });

    if (!user.active)
      return res.status(403).json({ error: 'Account deactivated. Contact admin.' });

    // Sync name/photo from Google if not already set
    if (!user.photoUrl && photoUrl) { user.photoUrl = photoUrl; await user.save(); }

    res.json({
      token: sign(user._id),
      user:  { id: user._id, name: user.name, email: user.email, role: user.role, photoUrl: user.photoUrl },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/auth/me  — return current user
router.get('/me', authenticate, (req, res) => {
  res.json(req.user);
});

module.exports = router;
