const mongoose = require('mongoose');

// One row per Razorpay checkout attempt. Activation only ever happens through
// the signature-verified /verify endpoint against a 'created' order belonging
// to the same user — the client saying "payment succeeded" proves nothing.
const paymentOrderSchema = new mongoose.Schema({
  user:      { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  plan:      { type: String, required: true },           // Plan.key at purchase time
  planName:  { type: String },
  amountInr: { type: Number, required: true },           // rupees, as charged
  provider:  { type: String, enum: ['razorpay', 'apple'], default: 'razorpay' },
  // Razorpay order_id, or Apple's (stable) transaction_id — either way, the
  // unique index is what makes a purchase impossible to replay/double-apply.
  orderId:   { type: String, required: true, unique: true },
  status:    { type: String, enum: ['created', 'paid', 'failed'], default: 'created' },
  paymentId: { type: String },                           // Razorpay payment_id once paid
  createdAt: { type: Date, default: Date.now },
  paidAt:    { type: Date },
});

module.exports = mongoose.model('PaymentOrder', paymentOrderSchema);
