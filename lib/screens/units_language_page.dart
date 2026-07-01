import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';

class UnitsLanguagePage extends StatefulWidget {
  const UnitsLanguagePage({super.key});

  @override
  State<UnitsLanguagePage> createState() => _UnitsLanguagePageState();
}

class _UnitsLanguagePageState extends State<UnitsLanguagePage> {
  static const _kMetric   = 'setting_units_metric';
  static const _kIs12Hour = 'setting_time_12h';

  bool _isMetric = true;
  bool _is12Hour = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isMetric = prefs.getBool(_kMetric) ?? true;
      _is12Hour = prefs.getBool(_kIs12Hour) ?? true;
    });
  }

  Future<void> _setMetric(bool v) async {
    setState(() => _isMetric = v);
    (await SharedPreferences.getInstance()).setBool(_kMetric, v);
  }

  Future<void> _set12Hour(bool v) async {
    setState(() => _is12Hour = v);
    (await SharedPreferences.getInstance()).setBool(_kIs12Hour, v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: Text('UNITS & LANGUAGE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4)),
        iconTheme: IconThemeData(color: kTextPrimary),
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: kBorder)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          // ── Measurement Units ────────────────────────────────────
          const _SectionLabel('MEASUREMENT UNITS'),
          const SizedBox(height: 8),
          _Group(children: [
            _RadioTile(
              label: 'Metric',
              subtitle: 'km · kg · °C',
              selected: _isMetric,
              onTap: () => _setMetric(true),
            ),
            _RadioTile(
              label: 'Imperial',
              subtitle: 'mi · lb · °F',
              selected: !_isMetric,
              onTap: () => _setMetric(false),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Time Format ──────────────────────────────────────────
          const _SectionLabel('TIME FORMAT'),
          const SizedBox(height: 8),
          _Group(children: [
            _RadioTile(
              label: '12-hour',
              subtitle: '2:30 PM',
              selected: _is12Hour,
              onTap: () => _set12Hour(true),
            ),
            _RadioTile(
              label: '24-hour',
              subtitle: '14:30',
              selected: !_is12Hour,
              onTap: () => _set12Hour(false),
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
