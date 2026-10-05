import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';

class UnitsLanguagePage extends StatefulWidget {
  const UnitsLanguagePage({super.key});

  @override
  State<UnitsLanguagePage> createState() => _UnitsLanguagePageState();
}

class _UnitsLanguagePageState extends State<UnitsLanguagePage> {
  static const _kLanguage = 'setting_language';

  static const _languages = [
    ('en', 'English'),
    ('es', 'Español'),
    ('fr', 'Français'),
    ('de', 'Deutsch'),
    ('it', 'Italiano'),
    ('pt', 'Português'),
    ('nl', 'Nederlands'),
    ('sv', 'Svenska'),
    ('no', 'Norsk'),
    ('da', 'Dansk'),
    ('fi', 'Suomi'),
    ('pl', 'Polski'),
    ('cs', 'Čeština'),
    ('sk', 'Slovenčina'),
    ('hu', 'Magyar'),
    ('ro', 'Română'),
    ('bg', 'Български'),
    ('el', 'Ελληνικά'),
    ('tr', 'Türkçe'),
    ('ru', 'Русский'),
    ('uk', 'Українська'),
    ('ar', 'العربية'),
    ('he', 'עברית'),
    ('hi', 'हिन्दी'),
    ('bn', 'বাংলা'),
    ('ur', 'اردو'),
    ('fa', 'فارسی'),
    ('th', 'ไทย'),
    ('vi', 'Tiếng Việt'),
    ('id', 'Bahasa Indonesia'),
    ('ms', 'Bahasa Melayu'),
    ('tl', 'Filipino'),
    ('sw', 'Kiswahili'),
    ('zh', '中文'),
    ('ja', '日本語'),
    ('ko', '한국어'),
  ];

  String _language = 'en';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _language = prefs.getString(_kLanguage) ?? 'en';
    });
  }

  Future<void> _setLanguage(String code) async {
    setState(() => _language = code);
    (await SharedPreferences.getInstance()).setString(_kLanguage, code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('Language')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 32),
        children: [
          // ── Language ─────────────────────────────────────────────
          _Group(children: [
            for (final (code, label) in _languages)
              _RadioTile(
                label: label,
                subtitle: code == 'en' ? 'Default' : '',
                selected: _language == code,
                onTap: () => _setLanguage(code),
              ),
          ]),
        ],
      ),
    );
  }
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

class _RadioTile extends StatelessWidget {
  final String label, subtitle;
  final bool   selected;
  final VoidCallback onTap;
  const _RadioTile({required this.label, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () { if (!selected) hapticSelect(); onTap(); },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: kTextPrimary)),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 22,
                  child: selected
                      ? const Icon(Icons.check_rounded, size: 22, color: kAccent)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
