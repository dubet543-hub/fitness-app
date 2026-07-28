const nodemailer = require('nodemailer');

/// Raised when SMTP isn't configured, as opposed to a delivery failure.
/// Kept distinct so the route can answer 503 and log the detail rather than
/// reflecting internals back to the client.
class MailerConfigError extends Error {}

let cachedTransport = null;

function transport() {
  if (cachedTransport) return cachedTransport;

  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS } = process.env;
  if (!SMTP_HOST || !SMTP_PORT || !SMTP_USER || !SMTP_PASS) {
    throw new MailerConfigError('SMTP_HOST/SMTP_PORT/SMTP_USER/SMTP_PASS are not configured — refusing to send email');
  }

  cachedTransport = nodemailer.createTransport({
    host: SMTP_HOST,
    port: Number(SMTP_PORT),
    secure: Number(SMTP_PORT) === 465,
    auth: { user: SMTP_USER, pass: SMTP_PASS },
  });
  return cachedTransport;
}

async function sendOtpEmail(email, code) {
  await transport().sendMail({
    from: process.env.MAIL_FROM || process.env.SMTP_USER,
    to: email,
    subject: 'Your sign-in code',
    text: `Your sign-in code is ${code}. It expires in 10 minutes.`,
    html: `<p>Your sign-in code is <strong style="font-size:20px;letter-spacing:2px">${code}</strong>.</p><p>It expires in 10 minutes. If you didn't request this, you can ignore this email.</p>`,
  });
}

module.exports = { sendOtpEmail, MailerConfigError };
