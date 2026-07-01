// Sets (or resets) the admin account's password on the connected database.
// Usage:
//   NEW_ADMIN_PASSWORD='YourStrongPass' node scripts/set-admin-password.js
// Optionally target a specific admin email with ADMIN_EMAIL (defaults to the
// seeded admin@solidcore.com).
require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');

(async () => {
  const email = process.env.ADMIN_EMAIL || 'admin@solidcore.com';
  const pass = process.env.NEW_ADMIN_PASSWORD;
  if (!pass || pass.length < 8) {
    console.error('✗ Set NEW_ADMIN_PASSWORD (min 8 chars).');
    process.exit(1);
  }
  await mongoose.connect(process.env.MONGODB_URI);
  const admin = await User.findOne({ email, role: 'admin' });
  if (!admin) {
    console.error(`✗ No admin found for ${email}`);
    process.exit(1);
  }
  admin.password = pass; // hashed by the pre-save hook
  await admin.save();
  console.log(`✓ Admin password updated for ${email}`);
  await mongoose.disconnect();
})().catch((e) => { console.error('✗', e.message); process.exit(1); });
