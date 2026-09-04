import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../api_service.dart';
import '../services/dashboard_metrics.dart';
import '../services/entitlements.dart';
import '../widgets/feature_gate.dart';

// ── Screen ─────────────────────────────────────────────────────────────────────

class WorkloadMonitorScreen extends StatefulWidget {
  final String initialRange;
  const WorkloadMonitorScreen({super.key, this.initialRange = '28d'});

  @override
  State<WorkloadMonitorScreen> createState() => _WMState();
}

class _WMState extends State<WorkloadMonitorScreen>
    with SingleTickerProviderStateMixin {

  String _athleteLabel = '';
  late String _range;
  late final TabController _tabs;

  AthleteMetrics? _metrics;
  bool _loading = true;

  List<WorkPoint> _applyRange(List<WorkPoint> all) {
    if (all.isEmpty) return all;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    if (_range == 'today') {
      return all.where((p) => sameDay(p.date, today)).toList();
    }
    if (_range == 'yesterday') {
      final yest = today.subtract(const Duration(days: 1));
      return all.where((p) => sameDay(p.date, yest)).toList();
    }
    final days = _range == '1w' ? 6 : (_range == '2w' ? 13 : 27);
    final cutoff = today.subtract(Duration(days: days));
    return all
        .where((p) =>
            !DateTime(p.date.year, p.date.month, p.date.day).isBefore(cutoff))
        .toList();
  }

  List<WorkPoint> get _train => _applyRange(_metrics?.train ?? const []);
  List<WorkPoint> get _skill => _applyRange(_metrics?.skill ?? const []);
  List<WorkPoint> get _total => _applyRange(_metrics?.total ?? const []);

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
    _tabs = TabController(length: 3, vsync: this);
    // The signed-in athlete's data comes from the JWT-authenticated API; the
    // cached user is only used for the name badge in the app bar.
    ApiService.getCachedUser().then((u) {
      if (u == null || !mounted) return;
      setState(() => _athleteLabel = u.name);
    });
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      final m = await AthleteMetricsService.load();
      if (!mounted) return;
      setState(() {
        _metrics = m;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FeatureGuard(
      feature: FeatureKeys.workloadMonitoring, child: _gatedBody(context));

  Widget _gatedBody(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        title: Text('WORKLOAD',
            style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1.4)),
        centerTitle: false,
        iconTheme: IconThemeData(color: kTextPrimary),
        actions: [
          if (_athleteLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_rounded, size: 14, color: kAccent),
                const SizedBox(width: 6),
                Text(_athleteLabel,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: kAccent)),
              ]),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(children: [
            Divider(height: 1, color: kBorder),
            TabBar(
              controller: _tabs,
              labelColor: kAccent,
              unselectedLabelColor: kTextSecondary,
              indicatorColor: kAccent,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(icon: Icon(Icons.fitness_center_rounded, size: 16), text: 'Training'),
                Tab(icon: Icon(Icons.sports_cricket_rounded, size: 16), text: 'Skill'),
                Tab(icon: Icon(Icons.stacked_bar_chart_rounded, size: 16), text: 'Daily Total'),
              ],
            ),
          ]),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: kAccent))
          : (_metrics == null || !_metrics!.hasLoadData)
              ? const _WorkloadEmpty()
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _SectionView(
                      data:           _train,
                      accentColor:    kSky,
                      sectionTitle:   'Training Session Exertion',
                      barColor:       kSky,
                      range:          _range,
                      onRangeChanged: (r) => setState(() => _range = r),
                    ),
                    _SectionView(
                      data:           _skill,
                      accentColor:    kSuccess,
                      sectionTitle:   'Skill Session Exertion',
                      barColor:       kSuccess,
                      range:          _range,
                      onRangeChanged: (r) => setState(() => _range = r),
                    ),
                    _SectionView(
                      data:           _total,
                      accentColor:    kViolet,
                      sectionTitle:   'Daily Total Load & Exertion',
                      barColor:       kViolet,
                      range:          _range,
                      onRangeChanged: (r) => setState(() => _range = r),
                    ),
                  ],
                ),
    );
  }
}

// ── Filter Bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _FilterBar({required this.selected, required this.onChanged});

  static const _keys   = ['today', 'yesterday', '1w', '2w', '28d'];
  static const _labels = ['Today', 'Yesterday', '1 Week', '2 Weeks', '28 Days'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_keys.length, (i) {
          final active = selected == _keys[i];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(_keys[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? kAccent.withValues(alpha: 0.15) : kCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active ? kAccent : kBorder,
                  ),
                ),
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active ? kAccent : kTextSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Section View ──────────────────────────────────────────────────────────────

class _SectionView extends StatelessWidget {
  final List<WorkPoint> data;
  final Color accentColor, barColor;
  final String sectionTitle;
  final String range;
  final ValueChanged<String> onRangeChanged;

  const _SectionView({
    required this.data,
    required this.accentColor,
    required this.sectionTitle,
    required this.barColor,
    required this.range,
    required this.onRangeChanged,
  });

  WorkPoint get _last => data.last;

  double get _exertion {
    final l = _last.load;
    if (l <= 0) return 2.0;
    return min(10.0, 2.087 * log(l / 50.0 + 1.0) + 2.0);
  }

  int get _targetLow  => (_last.chronic * 0.8).round();
  int get _targetHigh => (_last.chronic * 1.3).round();

  Color _acwrColor(double v) {
    if (v <= 0)   return kTextSecondary;
    if (v < 0.8)  return kInfo;
    if (v <= 1.3) return kSuccess;
    if (v <= 1.5) return kWarn;
    return kDanger;
  }

  String _acwrLabel(double v) {
    if (v <= 0)   return 'No Data';
    if (v < 0.8)  return 'Undertraining';
    if (v <= 1.3) return 'Sweet Spot';
    if (v <= 1.5) return 'Caution';
    return 'Danger Zone';
  }

  Color _loadGuidanceColor(double load, int low, int high) {
    if (load <= 0) return kTextSecondary;
    if (load < low) return kInfo;
    if (load <= high) return kSuccess;
    return kWarn;
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded, size: 30, color: kTextSecondary),
            const SizedBox(height: 10),
            Text('No load recorded for this period',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5, color: kTextSecondary, height: 1.4)),
          ],
        ),
      );
    }
    final acwr  = _last.acwr;
    final acCol = _acwrColor(acwr);
    final tLow  = _targetLow;
    final tHigh = _targetHigh;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Section label ──────────────────────────────────────────────────
          Row(children: [
            Container(width: 3, height: 18,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.4), blurRadius: 6)],
                )),
            Text(sectionTitle,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
          ]),
          const SizedBox(height: 14),

          // ── Key Metrics Row 1: Load, Exertion, Acute ──────────────────────
          Row(children: [
            Expanded(child: _MetricCard(
              label: 'Session Load',
              value: _last.load.toStringAsFixed(0),
              color: accentColor,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(
              label: 'Exertion',
              value: _exertion.toStringAsFixed(1),
              color: Colors.pinkAccent,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(
              label: '7-day Acute',
              value: _last.acute.toStringAsFixed(0),
              color: kSky,
            )),
          ]),
          const SizedBox(height: 10),

          // ── Key Metrics Row 2: Chronic, ACWR, Z-Score ─────────────────────
          Row(children: [
            Expanded(child: _MetricCard(
              label: 'Chronic (EWMA)',
              value: _last.chronic.toStringAsFixed(0),
              color: Colors.amberAccent,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(
              label: 'ACWR',
              value: _last.acwr <= 0 ? '—' : _last.acwr.toStringAsFixed(2),
              sub: _acwrLabel(acwr),
              color: acCol,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(
              label: 'Z-Score',
              value: _last.z.toStringAsFixed(2),
              sub: _last.z.abs() > 2 ? 'Flagged' : 'Normal',
              color: _last.z.abs() > 2 ? kDanger : kSuccess,
            )),
          ]),
          const SizedBox(height: 12),

          // ── Load Guidance (Target Range) ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: _loadGuidanceColor(_last.load, tLow, tHigh).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _loadGuidanceColor(_last.load, tLow, tHigh).withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _loadGuidanceColor(_last.load, tLow, tHigh).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.track_changes_rounded,
                      size: 16, color: _loadGuidanceColor(_last.load, tLow, tHigh)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Tomorrow's Load Target",
                          style: TextStyle(fontSize: 10, color: kTextSecondary)),
                      const SizedBox(height: 3),
                      Text('$tLow – $tHigh',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: _loadGuidanceColor(_last.load, tLow, tHigh),
                          )),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('80% – 130%',
                        style: TextStyle(fontSize: 9, color: kTextSecondary)),
                    Text('of Chronic ${_last.chronic.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 9, color: kTextSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Date range filter (moved here, right after Tomorrow's Load
          // Target, instead of pinned above the tabs) ───────────────────────
          _FilterBar(selected: range, onChanged: onRangeChanged),
          const SizedBox(height: 14),

          // ── ACWR Gauge ─────────────────────────────────────────────────────
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelHeader('ACWR Zone', Icons.speed_rounded),
                const SizedBox(height: 12),
                _AcwrGauge(acwr: acwr),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Load Chart ─────────────────────────────────────────────────────
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelHeader('Load History', Icons.bar_chart_rounded),
                const SizedBox(height: 8),
                _legend(barColor),
                const SizedBox(height: 10),
                SizedBox(
                  height: 240,
                  child: _InteractiveLoadChart(data: data, barColor: barColor, accentColor: accentColor),
                ),
                const SizedBox(height: 4),
                Text('Tap a bar to inspect · Scroll to pan',
                    style: TextStyle(fontSize: 9, color: kTextSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── ACWR Trend Line ────────────────────────────────────────────────
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelHeader('ACWR Trend', Icons.show_chart_rounded),
                const SizedBox(height: 4),
                Text('Zones: Under <0.8 · Sweet 0.8–1.3 · Caution 1.3–1.5 · Danger >1.5',
                    style: TextStyle(fontSize: 9, color: kTextSecondary)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 210,
                  child: _InteractiveAcwrChart(data: data, lineColor: accentColor),
                ),
                const SizedBox(height: 4),
                Text('Tap a point to inspect · Scroll to pan',
                    style: TextStyle(fontSize: 9, color: kTextSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Z-Score Trend ──────────────────────────────────────────────────
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelHeader('Z-Score Trend', Icons.insights_rounded),
                const SizedBox(height: 4),
                Text('Tap a point · |Z| > 2 = flagged',
                    style: TextStyle(fontSize: 9, color: kTextSecondary)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 190,
                  child: _InteractiveZChart(data: data, lineColor: accentColor),
                ),
                const SizedBox(height: 4),
                Text('Tap a point to inspect · Scroll to pan',
                    style: TextStyle(fontSize: 9, color: kTextSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Session Log ────────────────────────────────────────────────────
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelHeader('Session Log', Icons.list_alt_rounded),
                const SizedBox(height: 2),
                Text('Latest ${data.length.clamp(0, 10)} entries',
                    style: TextStyle(fontSize: 10, color: kTextSecondary)),
                const SizedBox(height: 10),
                ...List.generate(
                  data.length.clamp(0, 10),
                  (i) {
                    final idx = data.length - 1 - i;
                    return _SessionRow(pt: data[idx], color: barColor);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _panelHeader(String title, IconData icon) => Row(children: [
    Icon(icon, size: 14, color: kTextSecondary),
    const SizedBox(width: 6),
    Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
  ]);

  Widget _legend(Color bar) {
    return Wrap(spacing: 14, runSpacing: 6, children: [
      _legendBar(bar, 'Session Load'),
      _legendLine(Colors.pinkAccent, 'Exertion'),
    ]);
  }

  Widget _legendBar(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: c.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 5),
    Text(label, style: TextStyle(fontSize: 10, color: kTextSecondary)),
  ]);

  Widget _legendLine(Color c, String label, {bool dashed = false}) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 20, height: 10,
          child: CustomPaint(painter: _LegendLinePainter(color: c, dashed: dashed)),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10, color: kTextSecondary)),
      ]);

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kBorder),
    ),
    child: child,
  );
}

// ── Legend Line Painter ───────────────────────────────────────────────────────

class _LegendLinePainter extends CustomPainter {
  final Color color;
  final bool dashed;
  const _LegendLinePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.8..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    } else {
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset(min(x + 4, size.width), y), paint);
        x += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_LegendLinePainter old) => old.color != color || old.dashed != dashed;
}

// ── Metric Card ───────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label, value;
  final String sub;
  final Color color;
  const _MetricCard({required this.label, required this.value, this.sub = '', required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 2, color: color),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: kTextSecondary, letterSpacing: 0.2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Container(width: 20, height: 2, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              sub,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ACWR Gauge ────────────────────────────────────────────────────────────────

class _AcwrGauge extends StatelessWidget {
  final double acwr;
  const _AcwrGauge({required this.acwr});

  @override
  Widget build(BuildContext context) {
    // Clamp to 0-2.0 for display; proportions match the 0-2.0 scale exactly
    final clamped = acwr.clamp(0.0, 2.0);
    Color zoneColor(double v) {
      if (v <= 0)   return kTextSecondary;
      if (v < 0.8)  return kInfo;
      if (v <= 1.3) return kSuccess;
      if (v <= 1.5) return kWarn;
      return kDanger;
    }
    final col = zoneColor(acwr);

    return Column(children: [
      // Gauge bar — flex proportional to each zone's share of 0.0–2.0
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 20,
          child: Row(children: [
            // 0.0–0.8 = 40%
            Expanded(flex: 40, child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
              ),
            )),
            // 0.8–1.3 = 25%
            Expanded(flex: 25, child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)]),
              ),
            )),
            // 1.3–1.5 = 10%
            Expanded(flex: 10, child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFE65100), kWarn]),
              ),
            )),
            // 1.5–2.0 = 25%
            Expanded(flex: 25, child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFB71C1C), kDanger]),
              ),
            )),
          ]),
        ),
      ),
      const SizedBox(height: 4),
      // Scale labels — left edge of each Expanded aligns with zone boundary
      Row(children: [
        Expanded(flex: 40, child: const _GaugeTick('0')),
        Expanded(flex: 25, child: const _GaugeTick('0.8')),
        Expanded(flex: 10, child: const _GaugeTick('1.3')),
        Expanded(flex: 25, child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [_GaugeTick('1.5'), _GaugeTick('2.0+')],
        )),
      ]),
      // Arrow indicator
      LayoutBuilder(builder: (ctx, c) {
        final x = (c.maxWidth * (clamped / 2.0) - 10).clamp(0.0, c.maxWidth - 20.0);
        return Stack(children: [
          const SizedBox(height: 20),
          Positioned(
            left: x,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_drop_down, color: acwr <= 0 ? kTextSecondary : kTextPrimary, size: 20),
            ]),
          ),
        ]);
      }),
      const SizedBox(height: 4),
      // ACWR value badge
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: col.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: col.withValues(alpha: 0.45)),
          ),
          child: Text(
            acwr <= 0 ? 'No sessions logged yet' : 'ACWR  ${acwr.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.w700, color: col, fontSize: 13, letterSpacing: 0.3),
          ),
        ),
      ),
      const SizedBox(height: 10),
      // Zone labels — same flex proportions as gauge bar
      Row(children: [
        Expanded(flex: 40, child: _ZL('Under\nTraining${acwr > 0 && acwr < 0.8 ? ' ✓' : ''}', kInfo)),
        Expanded(flex: 25, child: _ZL('Sweet\nSpot${acwr >= 0.8 && acwr <= 1.3 ? ' ✓' : ''}', kSuccess)),
        Expanded(flex: 10, child: _ZL('Caution${acwr > 1.3 && acwr <= 1.5 ? ' ✓' : ''}', kWarn)),
        Expanded(flex: 25, child: _ZL('Danger\nZone${acwr > 1.5 ? ' ✓' : ''}', kDanger)),
      ]),
    ]);
  }
}

class _GaugeTick extends StatelessWidget {
  final String label;
  const _GaugeTick(this.label);

  @override
  Widget build(BuildContext context) =>
      Text(label, style: TextStyle(fontSize: 8.5, color: kTextSecondary));
}

class _ZL extends StatelessWidget {
  final String t;
  final Color  c;
  const _ZL(this.t, this.c);
  @override
  Widget build(BuildContext ctx) =>
      Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: c));
}

// ── Interactive Load Chart ────────────────────────────────────────────────────

class _InteractiveLoadChart extends StatefulWidget {
  final List<WorkPoint> data;
  final Color barColor, accentColor;
  const _InteractiveLoadChart({required this.data, required this.barColor, required this.accentColor});

  @override
  State<_InteractiveLoadChart> createState() => _InteractiveLoadChartState();
}

class _InteractiveLoadChartState extends State<_InteractiveLoadChart> {
  int? _sel;

  @override
  Widget build(BuildContext context) {
    const lPad = 40.0, slotW = 30.0;
    final minW = MediaQuery.of(context).size.width - 56.0;
    final contentW = max(slotW * widget.data.length, minW - lPad);
    final chartW = contentW + lPad;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: GestureDetector(
        onTapDown: (d) {
          final lx = d.localPosition.dx - lPad;
          if (lx < 0) return;
          final sl = contentW / widget.data.length;
          final idx = (lx / sl).round().clamp(0, widget.data.length - 1);
          setState(() => _sel = _sel == idx ? null : idx);
        },
        child: SizedBox(
          width: chartW,
          child: CustomPaint(
            painter: _LoadChartPainter(
              data: widget.data,
              barColor: widget.barColor,
              selectedIdx: _sel,
              contentW: contentW,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadChartPainter extends CustomPainter {
  final List<WorkPoint> data;
  final Color barColor;
  final int? selectedIdx;
  final double contentW;
  static const _lPad = 40.0;

  _LoadChartPainter({required this.data, required this.barColor, required this.contentW, this.selectedIdx});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const bPad = 28.0, tPad = 10.0, lp = _lPad;
    final chartH = size.height - bPad - tPad;
    final n = data.length;
    final slotW = contentW / n;
    double xAt(int i) => lp + slotW * i + slotW / 2;

    final loads    = data.map((d) => d.load).toList();
    final acutes   = data.map((d) => d.acute).toList();
    final chronics = data.map((d) => d.chronic).toList();
    final vMax     = [...loads, ...acutes, ...chronics].reduce(max).clamp(1.0, double.infinity);

    // Y-axis line
    canvas.drawLine(Offset(lp, tPad - 4), Offset(lp, tPad + chartH),
        Paint()..color = const Color(0xFF3A3F52)..strokeWidth = 0.8);

    // Grid lines + Y-axis labels
    for (final frac in [0.25, 0.5, 0.75, 1.0]) {
      final y = tPad + chartH * (1 - frac);
      canvas.drawLine(Offset(lp, y), Offset(size.width, y),
          Paint()..color = kTextPrimary.withValues(alpha: 0.09)..strokeWidth = 0.5);
      final tp = TextPainter(
        text: TextSpan(
            text: (vMax * frac).toStringAsFixed(0),
            style: TextStyle(color: kGrid, fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lp - 4 - tp.width, y - tp.height / 2));
    }

    // Bars with gradient fill
    final barW = (slotW * 0.55).clamp(5.0, 22.0);
    for (int i = 0; i < n; i++) {
      final h = data[i].load > 0 ? (chartH * data[i].load / vMax).clamp(2.0, chartH) : 0.0;
      if (h <= 0) continue;
      final rect = Rect.fromLTWH(xAt(i) - barW / 2, tPad + chartH - h, barW, h);
      final isSelected = selectedIdx == i;
      if (isSelected) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect.inflate(1.5),
              topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
          Paint()..color = kTextPrimary.withValues(alpha: 0.08),
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect,
            topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
        Paint()..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [barColor.withValues(alpha: isSelected ? 1.0 : 0.85),
                   barColor.withValues(alpha: isSelected ? 0.65 : 0.4)],
        ).createShader(rect),
      );
    }

    // Exertion line: 0-10 scale, only drawn for session days (load > 0)
    double yAtExert(double v) => tPad + chartH * (1.0 - v / 10.0);
    final exertPts = <Offset>[];
    for (int i = 0; i < n; i++) {
      if (data[i].load > 0) {
        final score = min(10.0, 2.087 * log(data[i].load / 50.0 + 1.0) + 2.0);
        exertPts.add(Offset(xAt(i), yAtExert(score)));
      }
    }
    if (exertPts.length >= 2) {
      final exertPaint = Paint()
        ..color = Colors.pinkAccent
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final ePath = Path()..moveTo(exertPts[0].dx, exertPts[0].dy);
      for (int i = 0; i < exertPts.length - 1; i++) {
        final p0 = i > 0 ? exertPts[i - 1] : exertPts[0];
        final p1 = exertPts[i], p2 = exertPts[i + 1];
        final p3 = i < exertPts.length - 2 ? exertPts[i + 2] : exertPts.last;
        final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
        final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
        ePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      }
      canvas.drawPath(ePath, exertPaint);
      for (final p in exertPts) {
        canvas.drawCircle(p, 2.5, Paint()..color = Colors.pinkAccent);
        canvas.drawCircle(p, 2.5, Paint()
          ..color = kTextPrimary.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);
      }
    }

    // Selection vertical line + tooltip
    if (selectedIdx != null && selectedIdx! < n) {
      final si = selectedIdx!;
      final x = xAt(si);
      canvas.drawLine(Offset(x, tPad), Offset(x, tPad + chartH),
          Paint()..color = kTextPrimary.withValues(alpha: 0.13)..strokeWidth = 1);
      final exert = data[si].load > 0
          ? (min(10.0, 2.087 * log(data[si].load / 50.0 + 1.0) + 2.0)).toStringAsFixed(1)
          : '—';
      _drawTooltip(canvas, size, x, tPad, lp, [
        data[si].d,
        'Load     ${data[si].load.toStringAsFixed(0)}',
        'Exertion $exert / 10',
        'Acute    ${data[si].acute.toStringAsFixed(0)}',
        'Chronic  ${data[si].chronic.toStringAsFixed(0)}',
        'ACWR     ${data[si].acwr <= 0 ? '—' : data[si].acwr.toStringAsFixed(2)}',
      ], barColor);
    }

    // Date labels
    final step = n > 20 ? 5 : (n > 10 ? 3 : 2);
    for (int i = 0; i < n; i += step) {
      _lbl(canvas, data[i].d, xAt(i), size.height - bPad + 5);
    }
    if ((n - 1) % step != 0) {
      _lbl(canvas, data[n - 1].d, xAt(n - 1), size.height - bPad + 5);
    }
  }

  void _drawTooltip(Canvas canvas, Size size, double x, double top, double lp,
      List<String> lines, Color accent) {
    const tw = 126.0, lh = 13.5, pad = 8.0, fs = 9.0;
    final h = pad * 2 + lines.length * lh;
    double tx = x + 8;
    if (tx + tw > size.width) tx = x - tw - 8;
    if (tx < lp) tx = lp;
    final ty = top + 2;
    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(tx, ty, tw, h), const Radius.circular(7));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xF0191C22));
    canvas.drawRRect(rrect, Paint()
      ..color = accent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);
    for (int i = 0; i < lines.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: lines[i],
          style: TextStyle(
            color: i == 0 ? kTextPrimary : const Color(0xFF878CA8),
            fontSize: fs,
            fontWeight: i == 0 ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: tw - pad * 2);
      tp.paint(canvas, Offset(tx + pad, ty + pad + i * lh));
    }
  }


  void _lbl(Canvas c, String s, double cx, double cy) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: kGrid, fontSize: 8.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(cx - tp.width / 2, cy));
  }

  @override
  bool shouldRepaint(covariant _LoadChartPainter old) =>
      old.data != data || old.barColor != barColor || old.selectedIdx != selectedIdx;
}

// ── Interactive ACWR Trend Chart ──────────────────────────────────────────────

class _InteractiveAcwrChart extends StatefulWidget {
  final List<WorkPoint> data;
  final Color lineColor;
  const _InteractiveAcwrChart({required this.data, required this.lineColor});

  @override
  State<_InteractiveAcwrChart> createState() => _InteractiveAcwrChartState();
}

class _InteractiveAcwrChartState extends State<_InteractiveAcwrChart> {
  int? _sel;

  @override
  Widget build(BuildContext context) {
    const lPad = 40.0, slotW = 30.0;
    final minW = MediaQuery.of(context).size.width - 56.0;
    final contentW = max(slotW * widget.data.length, minW - lPad);
    final chartW = contentW + lPad;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: GestureDetector(
        onTapDown: (d) {
          final lx = d.localPosition.dx - lPad;
          if (lx < 0) return;
          final sl = contentW / widget.data.length;
          final idx = (lx / sl).round().clamp(0, widget.data.length - 1);
          setState(() => _sel = _sel == idx ? null : idx);
        },
        child: SizedBox(
          width: chartW,
          child: CustomPaint(
            painter: _AcwrPainter(
              data: widget.data,
              lineColor: widget.lineColor,
              selectedIdx: _sel,
              contentW: contentW,
            ),
          ),
        ),
      ),
    );
  }
}

class _AcwrPainter extends CustomPainter {
  final List<WorkPoint> data;
  final Color lineColor;
  final int? selectedIdx;
  final double contentW;
  static const _lPad = 40.0;

  _AcwrPainter({required this.data, required this.lineColor, required this.contentW, this.selectedIdx});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const bPad = 28.0, tPad = 10.0, lp = _lPad;
    final chartH = size.height - bPad - tPad;
    final n = data.length;
    final slotW = contentW / n;
    double xAt(int i) => lp + slotW * i + slotW / 2;

    const vMax = 2.5, vMin = 0.0;
    double yAt(double v) => tPad + chartH * (1.0 - (v - vMin) / (vMax - vMin));

    // Zone bands
    void band(double lo, double hi, Color c) {
      canvas.drawRect(Rect.fromLTRB(lp, yAt(hi), size.width, yAt(lo)),
          Paint()..color = c.withValues(alpha: 0.09));
    }
    band(0.0, 0.8, kInfo);
    band(0.8, 1.3, kSuccess);
    band(1.3, 1.5, kWarn);
    band(1.5, 2.5, kDanger);

    // Y-axis line
    canvas.drawLine(Offset(lp, tPad - 4), Offset(lp, tPad + chartH),
        Paint()..color = const Color(0xFF3A3F52)..strokeWidth = 0.8);

    // Y-axis labels + subtle grid
    for (final v in [0.5, 0.8, 1.0, 1.3, 1.5, 2.0]) {
      final y = yAt(v);
      if (y < tPad || y > tPad + chartH) continue;
      canvas.drawLine(Offset(lp, y), Offset(size.width, y),
          Paint()..color = kTextPrimary.withValues(alpha: 0.08)..strokeWidth = 0.5);
      final tp = TextPainter(
        text: TextSpan(
            text: v.toStringAsFixed(1),
            style: TextStyle(color: kGrid, fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lp - 4 - tp.width, y - tp.height / 2));
    }

    // Zone threshold dashed lines
    for (final thresh in [0.8, 1.3, 1.5]) {
      _dashH(canvas, lp, size.width, yAt(thresh.toDouble()), const Color(0x28FFFFFF));
    }

    final vals = data.map((d) => d.acwr.clamp(vMin, vMax)).toList();
    final pts  = List.generate(n, (i) => Offset(xAt(i), yAt(vals[i])));

    Color segColor(double v) {
      if (v < 0.8)  return kInfo;
      if (v <= 1.3) return kSuccess;
      if (v <= 1.5) return kWarn;
      return kDanger;
    }

    // Gradient area fill under the line
    final fillPath = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < n - 1; i++) {
      final p0 = i > 0 ? pts[i - 1] : pts[0];
      final p1 = pts[i], p2 = pts[i + 1];
      final p3 = i < n - 2 ? pts[i + 2] : pts[n - 1];
      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    fillPath
      ..lineTo(pts.last.dx, tPad + chartH)
      ..lineTo(pts.first.dx, tPad + chartH)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withValues(alpha: 0.22), lineColor.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(lp, tPad, contentW, chartH)),
    );

    // Smooth color-coded ACWR line segments
    for (int i = 0; i < n - 1; i++) {
      final p0 = i > 0 ? pts[i - 1] : pts[0];
      final p1 = pts[i], p2 = pts[i + 1];
      final p3 = i < n - 2 ? pts[i + 2] : pts[n - 1];
      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      final path = Path()..moveTo(p1.dx, p1.dy)
          ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      canvas.drawPath(path, Paint()
        ..color = segColor((vals[i] + vals[i + 1]) / 2)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round);
    }

    // Data dots
    for (int i = 0; i < n; i++) {
      final isSelected = selectedIdx == i;
      if (isSelected) {
        canvas.drawCircle(pts[i], 6.0, Paint()..color = segColor(vals[i]).withValues(alpha: 0.25));
        canvas.drawCircle(pts[i], 4.5, Paint()..color = kTextPrimary);
        canvas.drawCircle(pts[i], 4.5, Paint()
          ..color = segColor(vals[i])
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      } else {
        canvas.drawCircle(pts[i], 3.0, Paint()..color = segColor(vals[i]));
      }
    }

    // Selection line + tooltip
    if (selectedIdx != null && selectedIdx! < n) {
      final si = selectedIdx!;
      final x = xAt(si);
      canvas.drawLine(Offset(x, tPad), Offset(x, tPad + chartH),
          Paint()..color = kTextPrimary.withValues(alpha: 0.13)..strokeWidth = 1);
      final col = segColor(vals[si]);
      _drawTooltip(canvas, size, x, tPad, lp, data[si].d, vals[si], col);
    }

    // Date labels
    final step = n > 20 ? 5 : (n > 10 ? 3 : 2);
    for (int i = 0; i < n; i += step) {
      _lbl(canvas, data[i].d, xAt(i), size.height - bPad + 5);
    }
    if ((n - 1) % step != 0) {
      _lbl(canvas, data[n - 1].d, xAt(n - 1), size.height - bPad + 5);
    }
  }

  void _drawTooltip(Canvas canvas, Size size, double x, double top, double lp,
      String date, double acwr, Color col) {
    const tw = 102.0, lh = 13.5, pad = 8.0, fs = 9.0;
    final h = pad * 2 + 2 * lh;
    double tx = x + 8;
    if (tx + tw > size.width) tx = x - tw - 8;
    if (tx < lp) tx = lp;
    final ty = top + 2;
    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(tx, ty, tw, h), const Radius.circular(7));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xF0191C22));
    canvas.drawRRect(rrect, Paint()
      ..color = col.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);
    // Date line
    final tp0 = TextPainter(
      text: TextSpan(text: date,
          style: TextStyle(color: kTextPrimary, fontSize: fs, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: tw - pad * 2);
    tp0.paint(canvas, Offset(tx + pad, ty + pad));
    // ACWR line
    final tp1 = TextPainter(
      text: TextSpan(text: 'ACWR  ${acwr.toStringAsFixed(2)}',
          style: TextStyle(color: col, fontSize: fs)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: tw - pad * 2);
    tp1.paint(canvas, Offset(tx + pad, ty + pad + lh));
  }

  void _dashH(Canvas c, double x0, double x1, double y, Color col) {
    final p = Paint()..color = col..strokeWidth = 0.8;
    double x = x0;
    while (x < x1) {
      c.drawLine(Offset(x, y), Offset(min(x + 5, x1), y), p);
      x += 9;
    }
  }

  void _lbl(Canvas c, String s, double cx, double cy) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: kGrid, fontSize: 8.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(cx - tp.width / 2, cy));
  }

  @override
  bool shouldRepaint(covariant _AcwrPainter old) =>
      old.data != data || old.selectedIdx != selectedIdx;
}

// ── Interactive Z-Score Chart ─────────────────────────────────────────────────

class _InteractiveZChart extends StatefulWidget {
  final List<WorkPoint> data;
  final Color lineColor;
  const _InteractiveZChart({required this.data, required this.lineColor});

  @override
  State<_InteractiveZChart> createState() => _InteractiveZChartState();
}

class _InteractiveZChartState extends State<_InteractiveZChart> {
  int? _sel;

  @override
  Widget build(BuildContext context) {
    const lPad = 40.0, slotW = 30.0;
    final minW = MediaQuery.of(context).size.width - 56.0;
    final contentW = max(slotW * widget.data.length, minW - lPad);
    final chartW = contentW + lPad;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: GestureDetector(
        onTapDown: (d) {
          final lx = d.localPosition.dx - lPad;
          if (lx < 0) return;
          final sl = contentW / widget.data.length;
          final idx = (lx / sl).round().clamp(0, widget.data.length - 1);
          setState(() => _sel = _sel == idx ? null : idx);
        },
        child: SizedBox(
          width: chartW,
          child: CustomPaint(
            painter: _ZScorePainter(
              data: widget.data,
              lineColor: widget.lineColor,
              selectedIdx: _sel,
              contentW: contentW,
            ),
          ),
        ),
      ),
    );
  }
}

class _ZScorePainter extends CustomPainter {
  final List<WorkPoint> data;
  final Color lineColor;
  final int? selectedIdx;
  final double contentW;
  static const _lPad = 40.0;

  _ZScorePainter({required this.data, required this.lineColor, required this.contentW, this.selectedIdx});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const bPad = 28.0, tPad = 10.0, lp = _lPad;
    final chartH = size.height - bPad - tPad;
    final n = data.length;
    final slotW = contentW / n;
    double xAt(int i) => lp + slotW * i + slotW / 2;

    // Fixed Z-score range -3.5 to +3.5 centred at 0
    const vMin = -3.5, vMax = 3.5;
    double yAt(double v) => tPad + chartH * (1.0 - (v - vMin) / (vMax - vMin));

    // Flagged zone bands (|z| > 2)
    canvas.drawRect(Rect.fromLTRB(lp, yAt(vMax), size.width, yAt(2.0)),
        Paint()..color = kDanger.withValues(alpha: 0.08));
    canvas.drawRect(Rect.fromLTRB(lp, yAt(-2.0), size.width, yAt(vMin)),
        Paint()..color = kDanger.withValues(alpha: 0.08));
    // Normal band
    canvas.drawRect(Rect.fromLTRB(lp, yAt(2.0), size.width, yAt(-2.0)),
        Paint()..color = kSuccess.withValues(alpha: 0.05));

    // Y-axis line
    canvas.drawLine(Offset(lp, tPad - 4), Offset(lp, tPad + chartH),
        Paint()..color = const Color(0xFF3A3F52)..strokeWidth = 0.8);

    // Y-axis labels + grid
    for (final v in [-3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0]) {
      final y = yAt(v);
      if (y < tPad || y > tPad + chartH) continue;
      final isThreshold = v == 2.0 || v == -2.0;
      canvas.drawLine(Offset(lp, y), Offset(size.width, y),
          Paint()
            ..color = isThreshold
                ? kDanger.withValues(alpha: 0.35)
                : kTextPrimary.withValues(alpha: 0.08)
            ..strokeWidth = isThreshold ? 0.8 : 0.5
            ..strokeJoin = StrokeJoin.round);
      final tp = TextPainter(
        text: TextSpan(
            text: v == 0.0 ? '0' : v.toStringAsFixed(0),
            style: TextStyle(
              color: isThreshold ? kDanger.withValues(alpha: 0.7) : kGrid,
              fontSize: 8,
              fontWeight: isThreshold ? FontWeight.w700 : FontWeight.normal,
            )),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lp - 4 - tp.width, y - tp.height / 2));
    }

    // Zero line
    canvas.drawLine(Offset(lp, yAt(0)), Offset(size.width, yAt(0)),
        Paint()..color = kTextPrimary.withValues(alpha: 0.2)..strokeWidth = 0.8);

    final vals = data.map((d) => d.z.clamp(vMin, vMax)).toList();
    final pts  = List.generate(n, (i) => Offset(xAt(i), yAt(vals[i])));

    Color ptColor(double z) => z.abs() > 2 ? kDanger : kSuccess;

    // Build Catmull-Rom spline path
    final linePath = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < n - 1; i++) {
      final p0 = i > 0 ? pts[i - 1] : pts[0];
      final p1 = pts[i], p2 = pts[i + 1];
      final p3 = i < n - 2 ? pts[i + 2] : pts[n - 1];
      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    // Area fill above/below zero
    final zeroY = yAt(0);
    final fillAbove = Path.from(linePath)
      ..lineTo(pts.last.dx, zeroY)
      ..lineTo(pts.first.dx, zeroY)
      ..close();
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(lp, tPad, size.width, zeroY));
    canvas.drawPath(fillAbove, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [lineColor.withValues(alpha: 0.30), lineColor.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(lp, tPad, contentW, zeroY - tPad)));
    canvas.restore();

    final fillBelow = Path.from(linePath)
      ..lineTo(pts.last.dx, zeroY)
      ..lineTo(pts.first.dx, zeroY)
      ..close();
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(lp, zeroY, size.width, tPad + chartH));
    canvas.drawPath(fillBelow, Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter, end: Alignment.topCenter,
        colors: [kDanger.withValues(alpha: 0.20), kDanger.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(lp, zeroY, contentW, tPad + chartH - zeroY)));
    canvas.restore();

    // Draw the line, colour-coded per segment
    for (int i = 0; i < n - 1; i++) {
      final p0 = i > 0 ? pts[i - 1] : pts[0];
      final p1 = pts[i], p2 = pts[i + 1];
      final p3 = i < n - 2 ? pts[i + 2] : pts[n - 1];
      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      final seg = Path()..moveTo(p1.dx, p1.dy)
          ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      final midZ = (vals[i] + vals[i + 1]) / 2;
      canvas.drawPath(seg, Paint()
        ..color = ptColor(midZ)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round);
    }

    // Dots
    for (int i = 0; i < n; i++) {
      final isSelected = selectedIdx == i;
      final col = ptColor(vals[i]);
      if (isSelected) {
        canvas.drawCircle(pts[i], 6.0, Paint()..color = col.withValues(alpha: 0.2));
        canvas.drawCircle(pts[i], 4.0, Paint()..color = kTextPrimary);
        canvas.drawCircle(pts[i], 4.0, Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 1.5);
      } else {
        canvas.drawCircle(pts[i], 2.5, Paint()..color = col);
        canvas.drawCircle(pts[i], 2.5, Paint()
          ..color = kTextPrimary.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);
      }
    }

    // Selection line + tooltip
    if (selectedIdx != null && selectedIdx! < n) {
      final si = selectedIdx!;
      final x = xAt(si);
      canvas.drawLine(Offset(x, tPad), Offset(x, tPad + chartH),
          Paint()..color = kTextPrimary.withValues(alpha: 0.13)..strokeWidth = 1);
      final col = ptColor(vals[si]);
      _drawTooltip(canvas, size, x, tPad, lp, data[si].d, data[si].z, col);
    }

    // Date labels
    final step = n > 20 ? 5 : (n > 10 ? 3 : 2);
    for (int i = 0; i < n; i += step) {
      _lbl(canvas, data[i].d, xAt(i), size.height - bPad + 5);
    }
    if ((n - 1) % step != 0) {
      _lbl(canvas, data[n - 1].d, xAt(n - 1), size.height - bPad + 5);
    }
  }

  void _drawTooltip(Canvas canvas, Size size, double x, double top, double lp,
      String date, double z, Color col) {
    const tw = 110.0, lh = 13.5, pad = 8.0, fs = 9.0;
    final h = pad * 2 + 3 * lh;
    double tx = x + 8;
    if (tx + tw > size.width) tx = x - tw - 8;
    if (tx < lp) tx = lp;
    final ty = top + 2;
    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(tx, ty, tw, h), const Radius.circular(7));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xF0191C22));
    canvas.drawRRect(rrect, Paint()
      ..color = col.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);
    for (final (i, text, bold) in [
      (0, date, true),
      (1, 'Z-Score  ${z.toStringAsFixed(2)}', false),
      (2, z.abs() > 2 ? '⚠ Flagged' : '✓ Normal', false),
    ]) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: bold ? kTextPrimary : (i == 2 ? col : const Color(0xFF878CA8)),
            fontSize: fs,
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: tw - pad * 2);
      tp.paint(canvas, Offset(tx + pad, ty + pad + i * lh));
    }
  }

  void _lbl(Canvas c, String s, double cx, double cy) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: kGrid, fontSize: 8.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(cx - tp.width / 2, cy));
  }

  @override
  bool shouldRepaint(covariant _ZScorePainter old) =>
      old.data != data || old.selectedIdx != selectedIdx;
}

// ── Session Log Row ───────────────────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  final WorkPoint pt;
  final Color color;
  const _SessionRow({required this.pt, required this.color});

  @override
  Widget build(BuildContext context) {
    Color acwrCol(double v) {
      if (v <= 0)   return kTextSecondary;
      if (v < 0.8)  return kInfo;
      if (v <= 1.3) return kSuccess;
      if (v <= 1.5) return kWarn;
      return kDanger;
    }
    final acCol = acwrCol(pt.acwr);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 46, alignment: Alignment.center,
              child: Text(pt.d,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: kTextSecondary)),
            ),
            Container(width: 1, height: 30, color: kBorder,
                margin: const EdgeInsets.symmetric(horizontal: 10)),
            Expanded(
              child: Row(children: [
                _stat('Load', pt.load.toStringAsFixed(0), color),
                _stat('Exertion',
                    pt.load > 0
                        ? (min(10.0, 2.087 * log(pt.load / 50.0 + 1.0) + 2.0)).toStringAsFixed(1)
                        : '—',
                    Colors.pinkAccent),
                _stat('Acute', pt.acute.toStringAsFixed(0), kSky),
                _stat('Chronic', pt.chronic.toStringAsFixed(0), Colors.amberAccent),
                _stat('ACWR', pt.acwr <= 0 ? '—' : pt.acwr.toStringAsFixed(2), acCol),
                _stat('Z', pt.z.toStringAsFixed(2),
                    pt.z.abs() > 2 ? kDanger : kSuccess),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color c) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 8.5, color: kTextSecondary)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c)),
      ],
    ),
  );
}

// ── Screen-level empty state ──────────────────────────────────────────────────────

class _WorkloadEmpty extends StatelessWidget {
  const _WorkloadEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.monitor_heart_rounded, size: 30, color: kAccent),
            ),
            const SizedBox(height: 16),
            Text('No training data yet',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 8),
            Text('Log sessions to see your workload stats here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: kTextSecondary, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
