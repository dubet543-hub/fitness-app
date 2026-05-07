import 'package:flutter/material.dart';

class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  ThemeMode _themeMode = ThemeMode.system;
  int _accentIndex = 0;

  final _accents = [
    ('Blue',   const Color(0xFF378ADD)),
    ('Teal',   const Color(0xFF1D9E75)),
    ('Coral',  const Color(0xFFD85A30)),
    ('Purple', const Color(0xFF7F77DD)),
    ('Amber',  const Color(0xFFBA7517)),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(title: const Text('Appearance'), scrolledUnderElevation: 0),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          _SectionLabel('Theme'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant)),
            child: Column(
              children: [
                _ThemeOption(label: 'Light', icon: Icons.light_mode_outlined,
                  selected: _themeMode == ThemeMode.light,
                  onTap: () => setState(() => _themeMode = ThemeMode.light)),
                Divider(height: 1, color: cs.outlineVariant),
                _ThemeOption(label: 'Dark', icon: Icons.dark_mode_outlined,
                  selected: _themeMode == ThemeMode.dark,
                  onTap: () => setState(() => _themeMode = ThemeMode.dark)),
                Divider(height: 1, color: cs.outlineVariant),
                _ThemeOption(label: 'System default', icon: Icons.brightness_auto_outlined,
                  selected: _themeMode == ThemeMode.system,
                  onTap: () => setState(() => _themeMode = ThemeMode.system)),
              ],
            ),
          ),
          _SectionLabel('Accent color'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_accents.length, (i) {
                final selected = _accentIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _accentIndex = i),
                  child: Column(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _accents[i].$2,
                        shape: BoxShape.circle,
                        border: selected ? Border.all(color: _accents[i].$2, width: 3) : null,
                        boxShadow: selected ? [BoxShadow(color: _accents[i].$2.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2)] : [],
                      ),
                      child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                    ),
                    const SizedBox(height: 6),
                    Text(_accents[i].$1, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ]),
                );
              }),
            ),
          ),
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

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeOption({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
      title: Text(label, style: TextStyle(fontSize: 14, color: selected ? cs.primary : cs.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
      trailing: selected
          ? Icon(Icons.radio_button_checked_rounded, color: cs.primary)
          : Icon(Icons.radio_button_off_rounded, color: cs.outlineVariant),
      onTap: onTap,
    );
  }
}