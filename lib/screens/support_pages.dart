import 'package:flutter/material.dart';
import '../core/theme.dart';

// ── Help Center ───────────────────────────────────────────────────────────────

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    void snack(String msg) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

    return Scaffold(
      backgroundColor: kBg,
      appBar: _appBar('HELP CENTER'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const _SectionLabel('COMMON QUESTIONS'),
          const SizedBox(height: 8),
          _Group(children: [
            _ArrowRow(label: 'How are scores calculated?',  onTap: () => snack('Opening article…')),
            _ArrowRow(label: 'How do I connect a device?',  onTap: () => snack('Opening article…')),
            _ArrowRow(label: 'Can I sync with Apple Health?', onTap: () => snack('Opening article…')),
            _ArrowRow(label: 'How to cancel subscription?', onTap: () => snack('Opening article…')),
          ]),
          const SizedBox(height: 20),

          const _SectionLabel('CONTACT'),
          const SizedBox(height: 8),
          _Group(children: [
            _ContactRow(
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: kAccent,
              label: 'Live chat support',
              badge: 'Online',
              badgeColor: kAccent,
              onTap: () => snack('Opening chat…'),
            ),
            _ContactRow(
              icon: Icons.email_outlined,
              iconColor: const Color(0xFF38BDF8),
              label: 'Email support',
              onTap: () => snack('Opening email…'),
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

  void _submit() {
    if (_msgCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message'), duration: Duration(seconds: 2)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Feedback submitted — thanks!'), duration: Duration(seconds: 2)));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: _appBar('SEND FEEDBACK'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const _SectionLabel('TYPE'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.2,
            children: List.generate(_types.length, (i) {
              final sel = _selectedType == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedType = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? kAccent.withValues(alpha: 0.12) : kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? kAccent : kBorder),
                  ),
                  child: Text(
                    _types[i],
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: sel ? kAccent : kTextSecondary,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          const _SectionLabel('MESSAGE'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: TextField(
              controller: _msgCtrl,
              maxLines: 6,
              style: const TextStyle(color: kTextPrimary, fontSize: 14),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Describe your feedback…',
                hintStyle: TextStyle(color: kTextMuted, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('Submit Feedback', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
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
      appBar: _appBar('ABOUT'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
        children: [
          // ── Logo & version ───────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: kAccent.withValues(alpha: 0.30)),
                    boxShadow: [BoxShadow(color: kAccent.withValues(alpha: 0.12), blurRadius: 30, spreadRadius: 2)],
                  ),
                  child: const Icon(Icons.bolt_rounded, size: 38, color: kAccent),
                ),
                const SizedBox(height: 16),
                const Text('SolidCore', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                const Text('Version 1.0.0 (build 1042)', style: TextStyle(fontSize: 13, color: kTextSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Legal ────────────────────────────────────────────────
          _Group(children: [
            _ArrowRow(label: 'Terms of service',      onTap: () => snack('Opening terms…')),
            _ArrowRow(label: 'Privacy policy',         onTap: () => snack('Opening policy…')),
            _ArrowRow(label: 'Open source licenses',  onTap: () => snack('Opening licenses…')),
          ]),
          const SizedBox(height: 28),

          const Center(
            child: Text(
              '© 2026 SolidCore Performance Inc.\nAll rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

AppBar _appBar(String title) => AppBar(
  backgroundColor: kBg,
  elevation: 0,
  iconTheme: const IconThemeData(color: kTextPrimary),
  title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4)),
  bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: kBorder)),
);

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: kTextSecondary),
  );
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(children.length, (i) => Column(children: [
          children[i],
          if (i < children.length - 1) const Divider(height: 1, indent: 16, color: kBorder),
        ])),
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
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextPrimary))),
            const Icon(Icons.chevron_right_rounded, size: 18, color: kTextMuted),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData   icon;
  final Color      iconColor;
  final String     label;
  final String?    badge;
  final Color?     badgeColor;
  final VoidCallback onTap;
  const _ContactRow({required this.icon, required this.iconColor, required this.label, this.badge, this.badgeColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextPrimary))),
            if (badge != null && badgeColor != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor!.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge!, style: TextStyle(fontSize: 11, color: badgeColor, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right_rounded, size: 18, color: kTextMuted),
          ],
        ),
      ),
    );
  }
}
