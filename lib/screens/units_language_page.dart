import 'package:flutter/material.dart';

class UnitsLanguagePage extends StatefulWidget {
  const UnitsLanguagePage({super.key});

  @override
  State<UnitsLanguagePage> createState() => _UnitsLanguagePageState();
}

class _UnitsLanguagePageState extends State<UnitsLanguagePage> {
  bool _isMetric = true;
  bool _is12Hour = true;
  String _language = 'English';

  final _languages = ['English', 'Spanish', 'French', 'German', 'Portuguese', 'Japanese'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(title: const Text('Units & language'), scrolledUnderElevation: 0),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          _SectionLabel('Measurement units'),
          _GroupCard(children: [
            _RadioTile(
              label: 'Metric',
              subtitle: 'km · kg · °C',
              selected: _isMetric,
              onTap: () => setState(() => _isMetric = true),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            _RadioTile(
              label: 'Imperial',
              subtitle: 'mi · lb · °F',
              selected: !_isMetric,
              onTap: () => setState(() => _isMetric = false),
            ),
          ]),
          _SectionLabel('Language'),
          _GroupCard(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Display language', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500, letterSpacing: 0.4)),
                const SizedBox(height: 4),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _language,
                    isExpanded: true,
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                    items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setState(() => _language = v!),
                  ),
                ),
              ]),
            ),
          ]),
          _SectionLabel('Time format'),
          _GroupCard(children: [
            _RadioTile(
              label: '12-hour',
              subtitle: '2:30 PM',
              selected: _is12Hour,
              onTap: () => setState(() => _is12Hour = true),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            _RadioTile(
              label: '24-hour',
              subtitle: '14:30',
              selected: !_is12Hour,
              onTap: () => setState(() => _is12Hour = false),
            ),
          ]),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
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
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Column(children: children)),
    );
  }
}

class _RadioTile extends StatelessWidget {
  final String label, subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _RadioTile({required this.label, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      trailing: selected
          ? Icon(Icons.radio_button_checked_rounded, color: cs.primary)
          : Icon(Icons.radio_button_off_rounded, color: cs.outlineVariant),
      onTap: onTap,
    );
  }
}