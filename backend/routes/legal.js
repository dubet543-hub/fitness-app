const router = require('express').Router();

// Public legal pages — required as hosted URLs for the App Store / Play Store
// listing. Content mirrors the in-app legal pages (legal_pages.dart).

const EFFECTIVE = '1 July 2026';

function page(title, sections) {
  const body = sections
    .map((s) => `<h2>${s.h}</h2><p>${s.b}</p>`)
    .join('\n');
  return `<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>SolidCore AMS — ${title}</title>
<style>
  :root { color-scheme: dark; }
  body { margin:0; background:#0b0e13; color:#c8cdd8; font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif; }
  .wrap { max-width:760px; margin:0 auto; padding:48px 22px 80px; }
  h1 { color:#fff; font-size:26px; letter-spacing:-0.3px; margin:0 0 4px; }
  .eff { color:#7b8494; font-size:13px; margin-bottom:32px; }
  h2 { color:#fff; font-size:17px; margin:28px 0 6px; }
  p { margin:0 0 4px; }
  a { color:#4aadff; }
  .foot { margin-top:48px; color:#7b8494; font-size:13px; text-align:center; }
</style></head>
<body><div class="wrap">
  <h1>${title}</h1>
  <div class="eff">Effective ${EFFECTIVE}</div>
  ${body}
  <div class="foot">© 2026 SolidCore AMS</div>
</div></body></html>`;
}

const TERMS = [
  { h: '1. Acceptance of Terms', b: 'By downloading, accessing, or using the SolidCore application ("the App") you agree to be bound by these Terms &amp; Conditions. If you do not agree, please discontinue use of the App.' },
  { h: '2. Use of the App', b: 'SolidCore is provided for general fitness, training, and informational purposes. You agree to use the App only for lawful purposes and not to misuse, reverse-engineer, or interfere with its normal operation.' },
  { h: '3. Health &amp; Fitness Disclaimer', b: 'The App provides estimates, scores, and insights — including body-composition estimates — that are informational only and are not medical advice, diagnosis, or treatment. Always consult a qualified health professional before starting or changing any training or nutrition programme. You use the App at your own risk.' },
  { h: '4. Accounts', b: 'You are responsible for maintaining the confidentiality of your account credentials and for all activity that occurs under your account.' },
  { h: '5. Intellectual Property', b: 'All content, trademarks, and software in the App are owned by or licensed to SolidCore AMS and may not be copied or redistributed without permission.' },
  { h: '6. Limitation of Liability', b: 'To the maximum extent permitted by law, SolidCore AMS shall not be liable for any indirect, incidental, or consequential damages arising from your use of the App.' },
  { h: '7. Changes to These Terms', b: 'We may update these Terms from time to time. Continued use of the App after changes take effect constitutes acceptance of the revised Terms.' },
  { h: '8. Contact', b: 'Questions about these Terms can be sent to <a href="mailto:legal@solidcore.app">legal@solidcore.app</a>.' },
];

const PRIVACY = [
  { h: '1. Overview', b: 'This Privacy Policy explains how SolidCore AMS collects, uses, and protects your information when you use the App.' },
  { h: '2. Information We Collect', b: 'We collect the information you provide directly — such as your profile details and the measurements you enter — as well as the training, recovery, and body-composition data generated as you use the App.' },
  { h: '3. On-Device Processing', b: 'Wherever possible, analyses such as body composition and camera-based movement assessments are processed on your device. Data stored on your device stays under your control.' },
  { h: '4. How We Use Your Information', b: 'Your information is used to calculate your scores, personalise insights, and improve the App. We do not sell your personal data.' },
  { h: '5. Consent', b: 'You can control data-collecting features through the consent settings in Privacy &amp; Security. Withdrawing consent disables the related feature going forward.' },
  { h: '6. Data Retention &amp; Deletion', b: 'You may delete your logs and account data at any time from within the App. Deleting your account permanently removes your data from our servers.' },
  { h: '7. Security', b: 'We use reasonable technical and organisational measures to protect your information, though no method of storage or transmission is completely secure.' },
  { h: '8. Contact', b: 'For privacy questions or requests, contact <a href="mailto:privacy@solidcore.app">privacy@solidcore.app</a>.' },
];

router.get('/terms', (_req, res) => res.type('html').send(page('Terms & Conditions', TERMS)));
router.get('/privacy', (_req, res) => res.type('html').send(page('Privacy Policy', PRIVACY)));

module.exports = router;
