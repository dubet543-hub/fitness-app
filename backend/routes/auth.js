const router = require('express').Router();
const jwt    = require('jsonwebtoken');
const User   = require('../models/User');
const { authenticate } = require('../middleware/auth');

const sign = (id) =>
  jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });

// POST /api/auth/register  — public self-signup (creates an athlete account)
router.post('/register', async (req, res) => {
  try {
    const { name, email, password, sport } = req.body;
    if (!name || !email || !password)
      return res.status(400).json({ error: 'Name, email and password are required' });
    if (String(password).length < 6)
      return res.status(400).json({ error: 'Password must be at least 6 characters' });

    const normEmail = String(email).toLowerCase().trim();
    const exists = await User.findOne({ email: normEmail });
    if (exists) return res.status(409).json({ error: 'Email already registered' });

    // Public signups are always athletes; admin role is only seeded/assigned server-side.
    const user = await User.create({
      name: String(name).trim(),
      email: normEmail,
      password,          // hashed by the User model pre-save hook
      sport: sport ? String(sport).trim() : undefined,
      role: 'athlete',
    });

    res.status(201).json({
      token: sign(user._id),
      user:  { id: user._id, name: user.name, email: user.email, role: user.role, photoUrl: user.photoUrl },
    });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
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

// PATCH /api/auth/me  — update own profile (name, sport)
router.patch('/me', authenticate, async (req, res) => {
  try {
    const { name, sport } = req.body;
    const user = await User.findById(req.user._id);
    if (!user) return res.status(404).json({ error: 'User not found' });
    if (name !== undefined)  user.name  = String(name).trim();
    if (sport !== undefined) user.sport = String(sport).trim();
    await user.save();
    res.json({ id: user._id, name: user.name, email: user.email, role: user.role, sport: user.sport, photoUrl: user.photoUrl });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// POST /api/auth/change-password
router.post('/change-password', authenticate, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword)
      return res.status(400).json({ error: 'Current and new password are required' });
    if (String(newPassword).length < 6)
      return res.status(400).json({ error: 'New password must be at least 6 characters' });

    const user = await User.findById(req.user._id); // includes password hash
    if (!user || !(await user.comparePassword(currentPassword)))
      return res.status(401).json({ error: 'Current password is incorrect' });

    user.password = newPassword; // re-hashed by the pre-save hook
    await user.save();
    res.json({ message: 'Password updated' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// DELETE /api/auth/me  — permanently delete own account + data
router.delete('/me', authenticate, async (req, res) => {
  try {
    const id = req.user._id;
    const TrainingSession = require('../models/TrainingSession');
    const BodyComposition = require('../models/BodyComposition');
    await Promise.all([
      TrainingSession.deleteMany({ athlete: id }),
      BodyComposition.deleteMany({ athlete: id }),
      User.findByIdAndDelete(id),
    ]);
    res.json({ message: 'Account deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
