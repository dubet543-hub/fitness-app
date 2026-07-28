// Sends over Resend's HTTPS API rather than SMTP: some hosts (Render among
// them) block outbound SMTP ports, but HTTPS is never blocked.

/// Raised when RESEND_API_KEY isn't configured, as opposed to a delivery
/// failure. Kept distinct so the route can answer 503 and log the detail
/// rather than reflecting internals back to the client.
class MailerConfigError extends Error {}

async function sendOtpEmail(email, code) {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) throw new MailerConfigError('RESEND_API_KEY is not configured — refusing to send email');

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: process.env.MAIL_FROM || 'onboarding@resend.dev',
      to: email,
      subject: 'Your sign-in code',
      text: `Your sign-in code is ${code}. It expires in 10 minutes.`,
      html: `<p>Your sign-in code is <strong style="font-size:20px;letter-spacing:2px">${code}</strong>.</p><p>It expires in 10 minutes. If you didn't request this, you can ignore this email.</p>`,
    }),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`Resend API error (${res.status}): ${body}`);
  }
}

module.exports = { sendOtpEmail, MailerConfigError };
