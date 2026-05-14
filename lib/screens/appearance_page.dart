import 'package:flutter/material.dart';
import '../core/theme.dart';

class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: const Text('APPEARANCE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4)),
        iconTheme: const IconThemeData(color: kTextPrimary),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: kBorder)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const _SectionLabel('THEME'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: kCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _ThemeOption(
                  label: 'Dark',
                  icon: Icons.dark_mode_outlined,
                  selected: _themeMode == ThemeMode.dark,
                  onTap: () => setState(() => _themeMode = ThemeMode.dark),
                ),
                const Divider(height: 1, color: kBorder),
                _ThemeOption(
                  label: 'Light',
                  icon: Icons.light_mode_outlined,
                  selected: _themeMode == ThemeMode.light,
                  onTap: () => setState(() => _themeMode = ThemeMode.light),
                ),
                const Divider(height: 1, color: kBorder),
                _ThemeOption(
                  label: 'System default',
                  icon: Icons.brightness_auto_outlined,
                  selected: _themeMode == ThemeMode.system,
                  onTap: () => setState(() => _themeMode = ThemeMode.system),
                ),
              ],
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
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: kTextSecondary),
  );
}

class _ThemeOption extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final bool       selected;
  final VoidCallback onTap;
  const _ThemeOption({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? kAccent : kTextSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? kTextPrimary : kTextSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? kAccent : kTextMuted,
            ),
          ],
        ),
      ),
    );
  }
}
