import 'package:flutter/material.dart';

// ─── Help Center ─────────────────────────────────────────────────────────────

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    void showSnack(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(title: const Text('Help center'), scrolledUnderElevation: 0),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          _SectionLabel('Common questions'),
          _GroupCard(children: [
            _ArrowTile(label: 'How are scores calculated?', onTap: () => showSnack('Opening article...')),
            _ArrowTile(label: 'How do I connect a device?', onTap: () => showSnack('Opening article...')),
            _ArrowTile(label: 'Can I sync with Apple Health?', onTap: () => showSnack('Opening article...')),
            _ArrowTile(label: 'How to cancel subscription?', onTap: () => showSnack('Opening article...')),
          ]),
          _SectionLabel('Contact'),
          _GroupCard(children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('Live chat support', style: TextStyle(fontSize: 14)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text('Online', style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_ios_rounded, size: 13),
              ]),
              onTap: () => showSnack('Opening chat...'),
            ),
            Divider(height: 1, color: cs.outlineVariant, indent: 56),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email support', style: TextStyle(fontSize: 14)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
              onTap: () => showSnack('Opening email...'),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Feedback ────────────────────────────────────────────────────────────────

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  int _selectedType = 0;
  final _msgCtrl = TextEditingController();
  final _types = ['Bug report', 'Feature request', 'General', 'Other'];

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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(title: const Text('Send feedback'), scrolledUnderElevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionLabel('What kind of feedback?'),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 3.2,
            children: List.generate(_types.length, (i) {
              final selected = _selectedType == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedType = i),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? cs.primaryContainer : cs.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selected ? cs.primary.withValues(alpha: 0.4) : cs.outlineVariant),
                  ),
                  child: Text(_types[i],
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                      color: selected ? cs.primary : cs.onSurface)),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant)),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your message', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500, letterSpacing: 0.4)),
              const SizedBox(height: 6),
              TextField(
                controller: _msgCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                  hintText: 'Describe your feedback...',
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: const Text('Submit feedback'),
          ),
        ],
      ),
    );
  }
}

// ─── About ───────────────────────────────────────────────────────────────────

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    void showSnack(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(title: const Text('About SolidCore'), scrolledUnderElevation: 0),
      body: ListView(
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        children: [
          Center(
            child: Column(children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(18)),
                child: Icon(Icons.bolt_rounded, size: 36, color: cs.primary),
              ),
              const SizedBox(height: 12),
              Text('SolidCore', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Version 1.0.0 (build 1042)',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(height: 24),
          _GroupCard(children: [
            _ArrowTile(label: 'Terms of service',       onTap: () => showSnack('Opening terms...')),
            _ArrowTile(label: 'Privacy policy',         onTap: () => showSnack('Opening policy...')),
            _ArrowTile(label: 'Open source licenses',   onTap: () => showSnack('Opening licenses...')),
          ]),
          const SizedBox(height: 24),
          Center(
            child: Text('© 2026 SolidCore Performance Inc.\nAll rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.6), height: 1.6)),
          ),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
    child: Text(text.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6,
        color: Theme.of(context).colorScheme.onSurfaceVariant)),
  );
}

class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: List.generate(children.length, (i) => Column(children: [
            children[i],
            if (i < children.length - 1) Divider(height: 1, color: cs.outlineVariant, indent: 16),
          ])),
        ),
      ),
    );
  }
}

class _ArrowTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ArrowTile({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label, style: const TextStyle(fontSize: 14)),
    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
    onTap: onTap,
  );
}