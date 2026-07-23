const mongoose = require('mongoose');

// One row per Razorpay checkout attempt. Activation only ever happens through
// the signature-verified /verify endpoint against a 'created' order belonging
// to the same user — the client saying "payment succeeded" proves nothing.
const paymentOrderSchema = new mongoose.Schema({
  user:      { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  plan:      { type: String, required: true },           // Plan.key at purchase time
  planName:  { type: String },
  amountInr: { type: Number, required: true },           // rupees, as charged
  orderId:   { type: String, required: true, unique: true }, // Razorpay order_id
  status:    { type: String, enum: ['created', 'paid', 'failed'], default: 'created' },
  paymentId: { type: String },                           // Razorpay payment_id once paid
  createdAt: { type: Date, default: Date.now },
  paidAt:    { type: Date },
});

module.exports = mongoose.model('PaymentOrder', paymentOrderSchema);
