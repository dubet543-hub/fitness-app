const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  name:      { type: String, required: true, trim: true },
  email:     { type: String, required: true, unique: true, lowercase: true, trim: true },
  password:  { type: String },
  role:      { type: String, enum: ['admin', 'athlete'], default: 'athlete' },
  sport:     { type: String, trim: true },
  photoUrl:  { type: String },

  // Federated identities. Keyed on the provider's stable subject rather than
  // the email: Apple's "Hide My Email" hands out a per-app relay address, and a
  // user can change the address on their Google account at any time.
  googleId:  { type: String, index: { unique: true, sparse: true } },
  appleId:   { type: String, index: { unique: true, sparse: true } },
  active:    { type: Boolean, default: true },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  createdAt: { type: Date, default: Date.now },
});

userSchema.pre('save', async function (next) {
  if (this.isModified('password') && this.password) {
    this.password = await bcrypt.hash(this.password, 12);
  }
  next();
});

userSchema.methods.comparePassword = function (candidate) {
  return bcrypt.compare(candidate, this.password || '');
};

userSchema.set('toJSON', {
  transform(_, obj) {
    delete obj.password;
    return obj;
  },
});

module.exports = mongoose.model('User', userSchema);
