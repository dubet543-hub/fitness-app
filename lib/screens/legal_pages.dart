import 'package:flutter/material.dart';
import '../core/theme.dart';

// ── Legal document scaffold ─────────────────────────────────────────────────
//
// Renders a titled legal document from a list of (heading, body) sections.
// Shared by the Terms & Conditions and Privacy Policy pages so both stay
// visually consistent with the rest of the app.

class LegalDocPage extends StatelessWidget {
  final String title;
  final String effective;
  final List<({String heading, String body})> sections;

  const LegalDocPage({
    super.key,
    required this.title,
    required this.effective,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        iconTheme: IconThemeData(color: kTextPrimary),
        title: Text(title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: kTextSecondary, letterSpacing: 1.4)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text('Effective $effective',
              style: TextStyle(fontSize: 12, color: kTextMuted)),
          const SizedBox(height: 20),
          for (final s in sections) ...[
            Text(s.heading,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 8),
            Text(s.body,
                style: TextStyle(fontSize: 13.5, color: kTextSecondary, height: 1.6)),
            const SizedBox(height: 22),
          ],
          const SizedBox(height: 4),
          Center(
            child: Text('© 2026 SolidCore AMS',
                style: TextStyle(fontSize: 12, color: kTextMuted)),
          ),
        ],
      ),
    );
  }
}

// ── Terms & Conditions ──────────────────────────────────────────────────────

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) => const LegalDocPage(
    title: 'TERMS & CONDITIONS',
    effective: '1 July 2026',
    sections: [
      (
        heading: '1. Acceptance of Terms',
        body: 'By downloading, accessing, or using the SolidCore application '
            '("the App") you agree to be bound by these Terms & Conditions. If '
            'you do not agree, please discontinue use of the App.',
      ),
      (
        heading: '2. Use of the App',
        body: 'SolidCore is provided for general fitness, training, and '
            'informational purposes. You agree to use the App only for lawful '
            'purposes and not to misuse, reverse-engineer, or interfere with '
            'its normal operation.',
      ),
      (
        heading: '3. Health & Fitness Disclaimer',
        body: 'The App provides estimates, scores, and insights — including body '
            'composition estimates — that are informational only and are not '
            'medical advice, diagnosis, or treatment. Always consult a qualified '
            'health professional before starting or changing any training or '
            'nutrition programme. You use the App at your own risk.',
      ),
      (
        heading: '4. Accounts',
        body: 'You are responsible for maintaining the confidentiality of your '
            'account credentials and for all activity that occurs under your '
            'account.',
      ),
      (
        heading: '5. Intellectual Property',
        body: 'All content, trademarks, and software in the App are owned by or '
            'licensed to SolidCore AMS and may not be copied or '
            'redistributed without permission.',
      ),
      (
        heading: '6. Limitation of Liability',
        body: 'To the maximum extent permitted by law, SolidCore AMS '
            'shall not be liable for any indirect, incidental, or consequential '
            'damages arising from your use of the App.',
      ),
      (
        heading: '7. Changes to These Terms',
        body: 'We may update these Terms from time to time. Continued use of the '
            'App after changes take effect constitutes acceptance of the revised '
            'Terms.',
      ),
      (
        heading: '8. Contact',
        body: 'Questions about these Terms can be sent to legal@solidcore.app.',
      ),
    ],
  );
}

// ── Privacy Policy ──────────────────────────────────────────────────────────

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) => const LegalDocPage(
    title: 'PRIVACY POLICY',
    effective: '1 July 2026',
    sections: [
      (
        heading: '1. Overview',
        body: 'This Privacy Policy explains how SolidCore AMS '
            'collects, uses, and protects your information when you use the App.',
      ),
      (
        heading: '2. Information We Collect',
        body: 'We collect the information you provide directly — such as your '
            'profile details and the measurements you enter — as well as the '
            'training, recovery, and body-composition data generated as you use '
            'the App.',
      ),
      (
        heading: '3. On-Device Processing',
        body: 'Wherever possible, analyses such as body composition and '
            'camera-based movement assessments are processed on your device. '
            'Data stored on your device stays under your control.',
      ),
      (
        heading: '4. How We Use Your Information',
        body: 'Your information is used to calculate your scores, personalise '
            'insights, and improve the App. We do not sell your personal data.',
      ),
      (
        heading: '5. Consent',
        body: 'You can control data-collecting features through the consent '
            'settings in Privacy & Security. Withdrawing consent disables the '
            'related feature going forward.',
      ),
      (
        heading: '6. Data Retention & Deletion',
        body: 'You may delete your logs and account data at any time from within '
            'the App. Deleted data is removed from your device.',
      ),
      (
        heading: '7. Security',
        body: 'We use reasonable technical and organisational measures to protect '
            'your information, though no method of storage or transmission is '
            'completely secure.',
      ),
      (
        heading: '8. Contact',
        body: 'For privacy questions or requests, contact privacy@solidcore.app.',
      ),
    ],
  );
}
