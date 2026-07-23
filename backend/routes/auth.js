const router = require('express').Router();
const jwt    = require('jsonwebtoken');
const User   = require('../models/User');
const { authenticate } = require('../middleware/auth');
const { verifyIdentityToken, SocialAuthConfigError } = require('../utils/socialAuth');
const { startTrial } = require('../utils/entitlements');

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
    await startTrial(user._id); // every new user gets the free month

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

// ── Federated sign-in (Google / Apple) ──────────────────────────────────────
//
// The app sends the provider's signed identity token; the signature, issuer,
// audience, and expiry are all checked in utils/socialAuth before any claim is
// trusted. Accounts are created on first sign-in, matching the public
// self-signup at /register.

/// Links a verified provider identity to a user, creating one if this is their
/// first sign-in.
///
/// Matched *only* on the provider subject — never on the email. Registration is
/// public and addresses are never verified, so adopting an existing account
/// because the addresses happen to match would let anyone take over an account
/// by registering under someone else's address first (or vice versa). An email
/// already in use therefore fails rather than silently merging.
async function upsertFederatedUser({ provider, subject, email, name, photoUrl }) {
  const idField = provider === 'apple' ? 'appleId' : 'googleId';

  let user = await User.findOne({ [idField]: subject });

  if (!user) {
    if (email && await User.exists({ email: email.toLowerCase() })) {
      const err = new Error('EMAIL_IN_USE');
      err.emailInUse = true;
      throw err;
    }
    // Apple only returns the display name on the very first authorisation, and
    // omits it entirely for Hide My Email users who edited it away.
    user = new User({
      name:  name || email?.split('@')[0] || 'Athlete',
      email: email?.toLowerCase(),
      [idField]: subject,
      photoUrl,
    });
  } else if (!user.photoUrl && photoUrl) {
    user.photoUrl = photoUrl;
  }
  const isNew = user.isNew;
  await user.save();
  if (isNew) await startTrial(user._id); // first social sign-in gets the free month too
  return user;
}

function federatedRoute(provider) {
  return async (req, res) => {
    try {
      const token = req.body.idToken || req.body.identityToken;
      const payload = await verifyIdentityToken(provider, token);

      // Apple sends no email once the user has authorised before, so fall back
      // to whatever is already stored against this Apple ID.
      const user = await upsertFederatedUser({
        provider,
        subject:  payload.sub,
        email:    payload.email,
        name:     req.body.name || payload.name,
        photoUrl: payload.picture,
      });

      if (!user.active)
        return res.status(403).json({ error: 'Account deactivated. Contact admin.' });
      if (!user.email)
        return res.status(400).json({ error: 'No email address available for this account.' });

      res.json({
        token: sign(user._id),
        user:  { id: user._id, name: user.name, email: user.email, role: user.role, photoUrl: user.photoUrl },
      });
    } catch (err) {
      // A missing client-ID list is our problem, not the caller's. Log which
      // variable is unset; tell the client only that it is unavailable.
      if (err instanceof SocialAuthConfigError) {
        console.error(`[auth] ${err.message}`);
        return res.status(503).json({
          error: `${provider === 'apple' ? 'Apple' : 'Google'} sign-in is not available right now.`,
        });
      }
      // A token that fails verification is a rejected sign-in, not a server
      // fault — never leak the reason back to the caller.
      if (/token|key|audience|issuer|jwt|verified|subject/i.test(err.message)) {
        console.warn(`[auth] rejected ${provider} sign-in: ${err.message}`);
        return res.status(401).json({ error: 'Sign-in could not be verified. Please try again.' });
      }
      // Deliberately not merged into the existing account — see
      // upsertFederatedUser. The user signs in with their password instead.
      if (err.emailInUse || err.code === 11000) {
        const label = provider === 'apple' ? 'Apple' : 'Google';
        return res.status(409).json({
          error: `An account already exists with this email address. `
               + `Sign in with your email and password, or use a different ${label} account.`,
        });
      }
      res.status(500).json({ error: err.message });
    }
  };
}

// POST /api/auth/google  — body: { idToken }
router.post('/google', federatedRoute('google'));

// POST /api/auth/apple   — body: { identityToken, name? }
router.post('/apple', federatedRoute('apple'));

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

// DELETE /api/auth/me/data — erase recorded training data, keep the account.
router.delete('/me/data', authenticate, async (req, res) => {
  try {
    const id = req.user._id;
    const TrainingSession = require('../models/TrainingSession');
    const BodyComposition = require('../models/BodyComposition');
    await Promise.all([
      TrainingSession.deleteMany({ athlete: id }),
      BodyComposition.deleteMany({ athlete: id }),
    ]);
    res.json({ message: 'Data deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
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
