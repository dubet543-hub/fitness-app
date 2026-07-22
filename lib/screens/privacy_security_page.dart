import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Row, Border;
import 'package:syncfusion_officechart/officechart.dart';
import '../api_service.dart';
import '../core/theme.dart';
import '../services/local_log_store.dart';

class PrivacySecurityPage extends StatefulWidget {
  /// Called after the account is deleted so the app can return to sign-in.
  final VoidCallback? onLoggedOut;
  const PrivacySecurityPage({super.key, this.onLoggedOut});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  bool analyticsShare = true;
  bool dailyLogsConsent = true;
  bool cameraConsent    = true;

  static const _kAnalytics = 'setting_analytics_share';

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final daily  = await LocalLogStore.dailyLogsConsent();
    final camera = await LocalLogStore.cameraConsent();
    final prefs  = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      dailyLogsConsent = daily;
      cameraConsent    = camera;
      analyticsShare   = prefs.getBool(_kAnalytics) ?? true;
    });
  }

  Future<void> _setPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
  );

  // ── Change password ────────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;
    bool busy = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: kCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Change password', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (error != null) ...[
              Text(error!, style: TextStyle(color: kDanger, fontSize: 12.5)),
              const SizedBox(height: 10),
            ],
            _pwField(currentCtrl, 'Current password'),
            const SizedBox(height: 10),
            _pwField(newCtrl, 'New password'),
            const SizedBox(height: 10),
            _pwField(confirmCtrl, 'Confirm new password'),
          ]),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: kTextSecondary)),
            ),
            TextButton(
              onPressed: busy ? null : () async {
                if (newCtrl.text.length < 6) { setLocal(() => error = 'New password must be at least 6 characters'); return; }
                if (newCtrl.text != confirmCtrl.text) { setLocal(() => error = 'Passwords do not match'); return; }
                setLocal(() { busy = true; error = null; });
                try {
                  await ApiService.changePassword(currentPassword: currentCtrl.text, newPassword: newCtrl.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _snack('Password updated');
                } catch (e) {
                  setLocal(() { busy = false; error = e.toString().replaceFirst('Exception: ', ''); });
                }
              },
              child: Text(busy ? 'Saving…' : 'Update', style: TextStyle(color: kAccent, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pwField(TextEditingController ctrl, String label) => TextField(
    controller: ctrl,
    obscureText: true,
    style: TextStyle(color: kTextPrimary, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: kTextSecondary, fontSize: 13),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kAccent)),
    ),
  );

  // ── Download my data ─────────────────────────────────────────────────────────
  static const _exportRanges = [
    ('Last 24 hours', 1),
    ('Last 7 days',   7),
    ('Last 15 days',  15),
    ('Last 30 days',  30),
    ('All time',      -1), // sentinel, mapped to `null` (no date filter) below
  ];

  Future<void> _pickRangeAndDownload() async {
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Export data', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, days) in _exportRanges)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label, style: TextStyle(color: kTextPrimary, fontSize: 14)),
                onTap: () => Navigator.pop(ctx, days),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: kTextSecondary))),
        ],
      ),
    );
    if (days == null) return;
    await _downloadData(days == -1 ? null : days);
  }

  Future<void> _downloadData(int? days) async {
    // "All time" fetches can take a while, so keep the message up for the
    // duration instead of the usual fixed 2s (which would vanish long before
    // a big export finishes and make it look like nothing is happening).
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Preparing your data…'), duration: Duration(seconds: 60)),
    );
    try {
      final from     = days == null ? null : DateTime.now().subtract(Duration(days: days));
      final sessions = await ApiService.fetchSessions(from: from, limit: from == null ? 10000 : 1000);
      final allBca   = await ApiService.fetchBodyComposition();
      final bca      = from == null
          ? allBca
          : allBca.where((e) {
              final d = DateTime.tryParse(e['date']?.toString() ?? '');
              return d != null && !d.isBefore(from);
            }).toList();

      final excelBytes = _buildExcel(sessions: sessions, bodyComposition: bca);

      final dir   = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final xlsxFile = File('${dir.path}/solidcore_export_$stamp.xlsx')..writeAsBytesSync(excelBytes);

      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      // iOS (esp. iPad) requires an anchor rect for the share sheet popover,
      // or it throws PlatformException("sharePositionOrigin ... must be set").
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(xlsxFile.path)],
        subject: 'My SolidCore data export',
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (mounted) _snack('Could not export your data: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  static double _numOrZero(dynamic v) => v is num ? v.toDouble() : 0.0;

  static String _fmtDate(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Performance sheet (workload/training-load fields, chart of Total Load),
  /// Recovery sheet (sleep/wellness/soreness/fatigue inputs, chart of the
  /// cumulative Recovery Score used on Player Stats), and a Body Composition
  /// sheet — each with its own native Excel chart — for the selected range.
  List<int> _buildExcel({
    required List<Map<String, dynamic>> sessions,
    required List<Map<String, dynamic>> bodyComposition,
  }) {
    // Both endpoints return newest-first; charts read left-to-right as a
    // timeline, so put both in chronological order before writing rows.
    int byDateAsc(Map<String, dynamic> a, Map<String, dynamic> b) {
      final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(0);
      final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(0);
      return da.compareTo(db);
    }

    sessions = List.of(sessions)..sort(byDateAsc);
    bodyComposition = List.of(bodyComposition)..sort(byDateAsc);

    final workbook = Workbook();

    // ── Performance ──────────────────────────────────────────────────────
    final perfSheet = workbook.worksheets[0];
    perfSheet.name = 'Performance';

    const perfHeaders = [
      'Date', 'Session Type',
      'Primary Type(s)', 'Primary Duration (min)', 'Primary RPE',
      'Secondary Type(s)', 'Secondary Duration (min)', 'Secondary RPE',
      'Skill Type(s)', 'Skill Duration (min)', 'Skill RPE',
      'Total Load', 'Scaled Load (0-10)',
    ];
    for (var c = 0; c < perfHeaders.length; c++) {
      perfSheet.getRangeByIndex(1, c + 1)
        ..setText(perfHeaders[c])
        ..cellStyle.bold = true;
    }
    for (var r = 0; r < sessions.length; r++) {
      final s = sessions[r];
      final row = r + 2;
      perfSheet.getRangeByIndex(row, 1).setText(_fmtDate(s['date']));
      perfSheet.getRangeByIndex(row, 2).setText((s['sessionType'] ?? '').toString());
      perfSheet.getRangeByIndex(row, 3).setText(((s['primaryTypes'] as List?) ?? const []).join(', '));
      perfSheet.getRangeByIndex(row, 4).setNumber(_numOrZero(s['primaryDuration']));
      perfSheet.getRangeByIndex(row, 5).setNumber(_numOrZero(s['primaryRpe']));
      perfSheet.getRangeByIndex(row, 6).setText(((s['secondaryTypes'] as List?) ?? const []).join(', '));
      perfSheet.getRangeByIndex(row, 7).setNumber(_numOrZero(s['secondaryDuration']));
      perfSheet.getRangeByIndex(row, 8).setNumber(_numOrZero(s['secondaryRpe']));
      perfSheet.getRangeByIndex(row, 9).setText(((s['skillTypes'] as List?) ?? const []).join(', '));
      perfSheet.getRangeByIndex(row, 10).setNumber(_numOrZero(s['skillDuration']));
      perfSheet.getRangeByIndex(row, 11).setNumber(_numOrZero(s['skillRpe']));
      perfSheet.getRangeByIndex(row, 12).setNumber(_numOrZero(s['totalLoad']));
      perfSheet.getRangeByIndex(row, 13).setNumber(_numOrZero(s['scaledGrade']));
    }

    // Native Excel chart bound to the Date/Total Load columns, positioned
    // below the data — mirrors the training-load bar chart on Player Stats.
    // Built manually (Date and Total Load aren't adjacent columns, so the
    // `dataRange`/`isSeriesInRows` auto-series path doesn't fit) — the series
    // added this way needs its `index` set explicitly, or the library's own
    // serializer throws a LateInitializationError on the uninitialized field.
    if (sessions.isNotEmpty) {
      final charts = ChartCollection(perfSheet);
      final chart = charts.add();
      chart.chartType = ExcelChartType.column;
      final loadSerie = chart.series.add();
      loadSerie.index = 0;
      loadSerie.categoryLabels = perfSheet.getRangeByIndex(2, 1, sessions.length + 1, 1);
      loadSerie.values = perfSheet.getRangeByIndex(2, 12, sessions.length + 1, 12);
      loadSerie.name = 'Total Load';
      chart.chartTitle = 'Training Load';
      chart.topRow = sessions.length + 3;
      chart.leftColumn = 1;
      chart.bottomRow = chart.topRow + 20;
      chart.rightColumn = 10;
      perfSheet.charts = charts;
    }

    // ── Recovery ─────────────────────────────────────────────────────────
    final recSheet = workbook.worksheets.addWithName('Recovery');
    const recHeaders = [
      'Date', 'Sleep (1-5)', 'Wellness (1-5)', 'Soreness (1-5)', 'Fatigue (1-5)',
      'Sleep Duration (hrs)', 'Readiness %', 'Recovery Score',
    ];
    for (var c = 0; c < recHeaders.length; c++) {
      recSheet.getRangeByIndex(1, c + 1)
        ..setText(recHeaders[c])
        ..cellStyle.bold = true;
    }
    for (var r = 0; r < sessions.length; r++) {
      final s = sessions[r];
      final row = r + 2;
      final sleep = _numOrZero(s['sleep']);
      final wellness = _numOrZero(s['wellness']);
      final soreness = _numOrZero(s['soreness']);
      final fatigue = _numOrZero(s['fatigue']);
      recSheet.getRangeByIndex(row, 1).setText(_fmtDate(s['date']));
      recSheet.getRangeByIndex(row, 2).setNumber(sleep);
      recSheet.getRangeByIndex(row, 3).setNumber(wellness);
      recSheet.getRangeByIndex(row, 4).setNumber(soreness);
      recSheet.getRangeByIndex(row, 5).setNumber(fatigue);
      recSheet.getRangeByIndex(row, 6).setNumber(_numOrZero(s['sleepDuration']));
      recSheet.getRangeByIndex(row, 7).setNumber(_numOrZero(s['readinessPercent']));
      recSheet.getRangeByIndex(row, 8).setNumber(sleep + wellness + soreness + fatigue);
    }

    // Recovery Score chart — same cumulative-of-4 metric as the Player
    // Stats "Cumulative Recovery Score" panel (optimal <= 8, monitor <= 13).
    if (sessions.isNotEmpty) {
      final recCharts = ChartCollection(recSheet);
      final recChart = recCharts.add();
      recChart.chartType = ExcelChartType.line;
      final recSerie = recChart.series.add();
      recSerie.index = 0;
      recSerie.categoryLabels = recSheet.getRangeByIndex(2, 1, sessions.length + 1, 1);
      recSerie.values = recSheet.getRangeByIndex(2, 8, sessions.length + 1, 8);
      recSerie.name = 'Recovery Score';
      recChart.chartTitle = 'Recovery Score';
      recChart.topRow = sessions.length + 3;
      recChart.leftColumn = 1;
      recChart.bottomRow = recChart.topRow + 20;
      recChart.rightColumn = 10;
      recSheet.charts = recCharts;
    }

    final bcaSheet = workbook.worksheets.addWithName('Body Composition');
    const bcaHeaders = ['Date', 'Weight (kg)', 'Body Fat %', 'Lean Body Mass (kg)', 'Skeletal Muscle %'];
    for (var c = 0; c < bcaHeaders.length; c++) {
      bcaSheet.getRangeByIndex(1, c + 1)
        ..setText(bcaHeaders[c])
        ..cellStyle.bold = true;
    }
    for (var r = 0; r < bodyComposition.length; r++) {
      final b = bodyComposition[r];
      final row = r + 2;
      bcaSheet.getRangeByIndex(row, 1).setText(_fmtDate(b['date']));
      bcaSheet.getRangeByIndex(row, 2).setNumber(_numOrZero(b['weightKg']));
      bcaSheet.getRangeByIndex(row, 3).setNumber(_numOrZero(b['bfPercent']));
      bcaSheet.getRangeByIndex(row, 4).setNumber(_numOrZero(b['lbm']));
      bcaSheet.getRangeByIndex(row, 5).setNumber(_numOrZero(b['smmPercent']));
    }

    // Native Excel line chart trending all four body-composition metrics,
    // matching the Metric Trends cards on the Body Composition screen —
    // each metric its own series sharing the Date category axis.
    if (bodyComposition.isNotEmpty) {
      final bcaCharts = ChartCollection(bcaSheet);
      final bcaChart = bcaCharts.add();
      bcaChart.chartType = ExcelChartType.line;
      const metricColumns = [2, 3, 4, 5]; // Weight, Body Fat %, LBM, Skeletal Muscle %
      for (var i = 0; i < metricColumns.length; i++) {
        final col = metricColumns[i];
        final serie = bcaChart.series.add();
        serie.index = i;
        serie.categoryLabels = bcaSheet.getRangeByIndex(2, 1, bodyComposition.length + 1, 1);
        serie.values = bcaSheet.getRangeByIndex(2, col, bodyComposition.length + 1, col);
        serie.name = bcaHeaders[col - 1];
      }
      bcaChart.chartTitle = 'Body Composition Trends';
      bcaChart.topRow = bodyComposition.length + 3;
      bcaChart.leftColumn = 1;
      bcaChart.bottomRow = bcaChart.topRow + 20;
      bcaChart.rightColumn = 10;
      bcaSheet.charts = bcaCharts;
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();
    return bytes;
  }

  // ── Delete my data ───────────────────────────────────────────────────────────
  // Erases recorded training/body-composition history but keeps the account
  // and session — distinct from "Delete account" below, which erases both.
  void _confirmDeleteData() {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete my data?', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'This permanently erases your training sessions and body-composition history. Your account stays active.',
          style: TextStyle(color: kTextSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text('Cancel', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dctx);
              try {
                await ApiService.deleteMyData();
                await LocalLogStore.clearBcaHistory();
                if (mounted) _snack('Your data has been deleted');
              } catch (e) {
                if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
              }
            },
            child: Text('Delete', style: TextStyle(color: kDanger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Delete account ───────────────────────────────────────────────────────────
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete account?', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'This is permanent and cannot be undone. All your data will be erased.',
          style: TextStyle(color: kTextSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text('Cancel', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dctx);
              try {
                await ApiService.deleteAccount();
                if (!mounted) return;
                // Return to the root before signing out so no settings route lingers.
                Navigator.of(context).popUntil((route) => route.isFirst);
                widget.onLoggedOut?.call(); // AuthScreen swaps to sign-in
              } catch (e) {
                if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
              }
            },
            child: Text('Delete', style: TextStyle(color: kDanger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: Text('PRIVACY & SECURITY', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4)),
        iconTheme: IconThemeData(color: kTextPrimary),
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: kBorder)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const _SectionLabel('SECURITY'),
          const SizedBox(height: 8),
          _Group(children: [
            _RowItem(
              icon: Icons.lock_outline_rounded,
              iconColor: kSky,
              label: 'Change password',
              onTap: _changePassword,
            ),
          ]),
          const SizedBox(height: 20),

          const _SectionLabel('DATA'),
          const SizedBox(height: 8),
          _Group(children: [
            _ToggleItem(
              icon: Icons.event_note_outlined,
              iconColor: const Color(0xFF34D399),
              label: 'Daily logs',
              subtitle: 'Allow saving wellness & recovery logs',
              value: dailyLogsConsent,
              onChanged: (v) {
                setState(() => dailyLogsConsent = v);
                LocalLogStore.setDailyLogsConsent(v);
                _snack(v ? 'Daily logs enabled' : 'Daily logs turned off');
              },
            ),
            _ToggleItem(
              icon: Icons.camera_alt_outlined,
              iconColor: kSky,
              label: 'Camera-based features',
              subtitle: 'On-device posture, running & bowling analysis',
              value: cameraConsent,
              onChanged: (v) {
                setState(() => cameraConsent = v);
                LocalLogStore.setCameraConsent(v);
                _snack(v ? 'Camera features enabled' : 'Camera features turned off');
              },
            ),
            _ToggleItem(
              icon: Icons.analytics_outlined,
              iconColor: kWarn,
              label: 'Analytics sharing',
              subtitle: 'Help improve SolidCore',
              value: analyticsShare,
              onChanged: (v) { setState(() => analyticsShare = v); _setPref(_kAnalytics, v); },
            ),
            _RowItem(
              icon: Icons.download_outlined,
              iconColor: kTextSecondary,
              label: 'Download my data',
              onTap: _pickRangeAndDownload,
            ),
          ]),
          const SizedBox(height: 20),

          const _SectionLabel('DANGER ZONE'),
          const SizedBox(height: 8),
          _DangerButton(
            icon: Icons.person_off_outlined,
            label: 'Deactivate account',
            onTap: () => _snack('Deactivation requires confirmation'),
          ),
          const SizedBox(height: 8),
          _DangerButton(
            icon: Icons.delete_sweep_outlined,
            label: 'Delete my data',
            onTap: _confirmDeleteData,
          ),
          const SizedBox(height: 8),
          _DangerButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete account',
            onTap: _confirmDelete,
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

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
          if (i < children.length - 1) Divider(height: 1, indent: 54, color: kBorder),
        ])),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final VoidCallback? onTap;
  const _RowItem({required this.icon, required this.iconColor, required this.label, this.onTap});

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
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextPrimary))),
            Icon(Icons.chevron_right_rounded, size: 18, color: kTextMuted),
          ],
        ),
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String?  subtitle;
  final bool     value;
  final ValueChanged<bool> onChanged;
  const _ToggleItem({required this.icon, required this.iconColor, required this.label, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 12, color: kTextSecondary)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: kAccent,
            activeTrackColor: kAccent.withValues(alpha: 0.25),
            inactiveThumbColor: kTextMuted,
            inactiveTrackColor: kBorderBright,
          ),
        ],
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  const _DangerButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: kDanger),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kDanger)),
          ],
        ),
      ),
    );
  }
}
