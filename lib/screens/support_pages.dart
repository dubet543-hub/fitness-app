import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart' show BrandLogo, SectionHeader;
import 'legal_pages.dart';

const _supportEmail = 'support@solidcoreats.com';

Future<void> _openEmail(BuildContext context, {String subject = '', String body = ''}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: _supportEmail,
    query: [
      if (subject.isNotEmpty) 'subject=${Uri.encodeComponent(subject)}',
      if (body.isNotEmpty) 'body=${Uri.encodeComponent(body)}',
    ].join('&'),
  );
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No mail app found. Email us at $_supportEmail'),
          duration: const Duration(seconds: 3)),
    );
  }
}

// ── Help Center ───────────────────────────────────────────────────────────────

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: _appBar('Help center'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 32),
        children: [
          const _SectionLabel('Contact'),
          _Group(children: [
            _ContactRow(
              icon: Icons.mail_outline_rounded,
              label: 'Email support',
              onTap: () => _openEmail(context, subject: 'SolidCore support request'),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Feedback ──────────────────────────────────────────────────────────────────

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  int _selectedType = 0;
  final _msgCtrl = TextEditingController();
  static const _types = ['Bug report', 'Feature request', 'General', 'Other'];

  @override
  void dispose() { _msgCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_msgCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message'), duration: Duration(seconds: 2)));
      return;
    }
    await _openEmail(
      context,
      subject: 'SolidCore feedback — ${_types[_selectedType]}',
      body: _msgCtrl.text.trim(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: _appBar('Send feedback'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 32),
        children: [
          const _SectionLabel('Type'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.2,
            children: List.generate(_types.length, (i) {
              final sel = _selectedType == i;
              return Semantics(
                button: true,
                selected: sel,
                child: Material(
                  color: kCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kRadiusSm),
                    side: BorderSide(color: sel ? kTextPrimary : kBorder, width: sel ? 1 : 0.6),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      if (!sel) hapticSelect();
                      setState(() => _selectedType = i);
                    },
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                          color: sel ? kTextPrimary : kTextSecondary,
                        ),
                        child: Text(_types[i]),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          const _SectionLabel('Message'),
          TextField(
            controller: _msgCtrl,
            maxLines: 6,
            style: const TextStyle(color: kTextPrimary, fontSize: 16, height: 1.4),
            decoration: const InputDecoration(hintText: 'Describe your feedback…'),
          ),
          const SizedBox(height: 28),

          ElevatedButton(
            onPressed: () { hapticConfirm(); _submit(); },
            child: const Text('Submit feedback'),
          ),
        ],
      ),
    );
  }
}

// ── About ─────────────────────────────────────────────────────────────────────

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    void snack(String msg) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

    return Scaffold(
      backgroundColor: kBg,
      appBar: _appBar('About'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(kGutter, 24, kGutter, 32),
        children: [
          // ── Logo & version ───────────────────────────────────────
          const Center(
            child: Column(
              children: [
                BrandLogo(width: 128),
                SizedBox(height: 12),
                Text('SolidCore', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.4)),
                SizedBox(height: 4),
                Text('Version 1.0.0 (build 1042)', style: TextStyle(fontSize: 14, color: kTextSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Legal ────────────────────────────────────────────────
          _Group(children: [
            _ArrowRow(label: 'Terms & conditions',    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsPage()))),
            _ArrowRow(label: 'Privacy policy',        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()))),
            _ArrowRow(label: 'Open source licenses',  onTap: () => snack('Opening licenses…')),
          ]),
          const SizedBox(height: 32),

          const Center(
            child: Text(
              '© 2026 Tushar Dube.\nAll rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

AppBar _appBar(String title) => AppBar(title: Text(title));

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: SectionHeader(text),
  );
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: const BorderSide(color: kBorder, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 0.6, thickness: 0.6, indent: 16, color: kBorder),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _ArrowRow extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _ArrowRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () { hapticSelect(); onTap(); },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: kTextPrimary))),
              const Icon(Icons.chevron_right_rounded, size: 20, color: kTextMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final VoidCallback onTap;
  const _ContactRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () { hapticSelect(); onTap(); },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: kTextSecondary),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: kTextPrimary))),
              const Icon(Icons.chevron_right_rounded, size: 20, color: kTextMuted),
            ],
          ),
        ),
      ),
    );
  }
}
