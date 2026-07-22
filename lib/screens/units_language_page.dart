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
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: Text('LANGUAGE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4)),
        iconTheme: IconThemeData(color: kTextPrimary),
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: kBorder)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          // ── Language ─────────────────────────────────────────────
          const _SectionLabel('LANGUAGE'),
          const SizedBox(height: 8),
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: kTextSecondary),
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
          if (i < children.length - 1) Divider(height: 1, color: kBorder),
        ])),
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 14, color: selected ? kTextPrimary : kTextSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: kTextSecondary)),
                ],
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
