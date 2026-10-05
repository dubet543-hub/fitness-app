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
        title: const Text('Workload'),
        actions: [
          if (_athleteLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: _AthleteChip(name: _athleteLabel)),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: kBorder, width: 0.6)),
            ),
            child: TabBar(
              controller: _tabs,
              onTap: (_) => hapticSelect(),
              tabs: const [
                Tab(text: 'Training'),
                Tab(text: 'Skill'),
                Tab(text: 'Daily total'),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : (_metrics == null || !_metrics!.hasLoadData)
              ? const _WorkloadEmpty()
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _SectionView(
                      data:           _train,
                      accentColor:    kSky,
                      sectionTitle:   'Training session exertion',
                      barColor:       kSky,
                      range:          _range,
                      onRangeChanged: (r) => setState(() => _range = r),
                    ),
                    _SectionView(
                      data:           _skill,
                      accentColor:    kSuccess,
                      sectionTitle:   'Skill session exertion',
                      barColor:       kSuccess,
                      range:          _range,
                      onRangeChanged: (r) => setState(() => _range = r),
                    ),
                    _SectionView(
                      data:           _total,
                      accentColor:    kViolet,
                      sectionTitle:   'Daily total load & exertion',
                      barColor:       kViolet,
                      range:          _range,
                      onRangeChanged: (r) => setState(() => _range = r),
                    ),
                  ],
                ),
    );
  }
}

// ── Shared bits ───────────────────────────────────────────────────────────────

/// Chart axis / tick text.
const TextStyle _kAxis = TextStyle(color: kTextMuted, fontSize: 11);

/// Tabular figures so numbers in columns line up.
const List<FontFeature> _kTabular = [FontFeature.tabularFigures()];

/// A small filled circle — a series key or a status marker.
class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  const _Dot(this.color, {this.size = 7});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Status = a dot in the status colour + the word in neutral text.
class _StatusDot extends StatelessWidget {
  final Color color;
  final String label;
  const _StatusDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _Dot(color),
      const SizedBox(width: 6),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextPrimary),
      ),
    ],
  );
}

/// Read-only identity pill for the signed-in athlete.
class _AthleteChip extends StatelessWidget {
  final String name;
  const _AthleteChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Signed in as $name',
      excludeSemantics: true,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: kBorder, width: 0.6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_outline_rounded, size: 15, color: kTextSecondary),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextSecondary),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Centred empty state: plain icon, title, optional one-line hint.
class _EmptyMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;
  const _EmptyMessage({required this.icon, required this.title, this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: kTextMuted),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextPrimary),
        ),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: kTextSecondary, height: 1.4),
          ),
        ],
      ],
    );
  }
}

// ── Filter Bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _FilterBar({required this.selected, required this.onChanged});

  // Longest range first, so the default (28 days) is visible without scrolling.
  static const _keys   = ['28d', '2w', '1w', 'yesterday', 'today'];
  static const _labels = ['28 days', '2 weeks', '1 week', 'Yesterday', 'Today'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_keys.length, (i) {
          final active = selected == _keys[i];
          return Padding(
            padding: EdgeInsets.only(right: i < _keys.length - 1 ? 8 : 0),
            child: ChoiceChip(
              label: Text(_labels[i]),
              selected: active,
              showCheckmark: false,
              onSelected: (_) {
                if (!active) hapticSelect();
                onChanged(_keys[i]);
              },
              backgroundColor: kCard,
              selectedColor: kTextPrimary,
              elevation: 0,
              pressElevation: 0,
              side: BorderSide(color: active ? kTextPrimary : kBorder, width: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              labelStyle: TextStyle(
                fontSize: 14,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? kBg : kTextSecondary,
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
    if (v <= 0)   return kTextMuted;
    if (v < 0.8)  return kInfo;
    if (v <= 1.3) return kSuccess;
    if (v <= 1.5) return kWarn;
    return kDanger;
  }

  String _acwrLabel(double v) {
    if (v <= 0)   return 'No data';
    if (v < 0.8)  return 'Undertraining';
    if (v <= 1.3) return 'Sweet spot';
    if (v <= 1.5) return 'Caution';
    return 'Danger zone';
  }

  /// Where the latest load sits against the target range — the colour the
  /// target card used to be tinted with, now a dot + words. Null = no load.
  (Color, String)? _loadGuidance(double load, int low, int high) {
    if (load <= 0) return null;
    if (load < low) return (kInfo, 'Latest load below range');
    if (load <= high) return (kSuccess, 'Latest load within range');
    return (kWarn, 'Latest load above range');
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      // The range filter stays reachable here, so an empty range (e.g.
      // "Today" before anything is logged) is not a dead end.
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 32),
        children: [
          _FilterBar(selected: range, onChanged: onRangeChanged),
          const SizedBox(height: 72),
          const _EmptyMessage(
            icon: Icons.event_busy_outlined,
            title: 'No load recorded for this period',
          ),
        ],
      );
    }
    final acwr  = _last.acwr;
    final tLow  = _targetLow;
    final tHigh = _targetHigh;
    final guide = _loadGuidance(_last.load, tLow, tHigh);
    final zFlag = _last.z.abs() > 2;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(kGutter, 20, kGutter, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Section title ──────────────────────────────────────────────────
          Semantics(
            header: true,
            child: Text(
              sectionTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.4),
            ),
          ),
          const SizedBox(height: 14),

          // ── Key metrics, in pairs ──────────────────────────────────────────
          _pair(
            _MetricCard(label: 'Session load', value: _last.load.toStringAsFixed(0)),
            _MetricCard(label: 'Exertion', value: _exertion.toStringAsFixed(1)),
          ),
          const SizedBox(height: 10),
          _pair(
            _MetricCard(label: '7-day acute', value: _last.acute.toStringAsFixed(0)),
            _MetricCard(label: 'Chronic (EWMA)', value: _last.chronic.toStringAsFixed(0)),
          ),
          const SizedBox(height: 10),
          _pair(
            _MetricCard(
              label: 'ACWR',
              value: _last.acwr <= 0 ? '—' : _last.acwr.toStringAsFixed(2),
              status: _acwrLabel(acwr),
              statusColor: _acwrColor(acwr),
            ),
            _MetricCard(
              label: 'Z-score',
              value: _last.z.toStringAsFixed(2),
              status: zFlag ? 'Flagged' : 'Normal',
              statusColor: zFlag ? kDanger : kSuccess,
            ),
          ),
          const SizedBox(height: 12),

          // ── Load Guidance (Target Range) ──────────────────────────────────
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Tomorrow's load target",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextSecondary)),
                const SizedBox(height: 6),
                Text(
                  '$tLow–$tHigh',
                  style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8,
                    color: kTextPrimary, height: 1.1, fontFeatures: _kTabular,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '80–130% of chronic ${_last.chronic.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13, color: kTextSecondary),
                ),
                if (guide != null) ...[
                  const SizedBox(height: 12),
                  _StatusDot(color: guide.$1, label: guide.$2),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Date range filter (kept here, right after Tomorrow's Load
          // Target, instead of pinned above the tabs) ────────────────────────
          _FilterBar(selected: range, onChanged: onRangeChanged),
          const SizedBox(height: 16),

          // ── ACWR Gauge ─────────────────────────────────────────────────────
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelTitle('ACWR zone'),
                const SizedBox(height: 12),
                _AcwrGauge(acwr: acwr),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Load Chart ─────────────────────────────────────────────────────
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelTitle('Load history'),
                const SizedBox(height: 8),
                _legend(barColor),
                const SizedBox(height: 12),
                SizedBox(
                  height: 240,
                  child: _InteractiveLoadChart(data: data, barColor: barColor, accentColor: accentColor),
                ),
                const SizedBox(height: 8),
                _hint('Tap a bar to inspect · Scroll to pan'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── ACWR Trend Line ────────────────────────────────────────────────
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelTitle('ACWR trend'),
                const SizedBox(height: 8),
                Wrap(spacing: 14, runSpacing: 6, children: [
                  _legendDot(kInfo,    'Under <0.8'),
                  _legendDot(kSuccess, 'Sweet 0.8–1.3'),
                  _legendDot(kWarn,    'Caution 1.3–1.5'),
                  _legendDot(kDanger,  'Danger >1.5'),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: _InteractiveAcwrChart(data: data, lineColor: accentColor),
                ),
                const SizedBox(height: 8),
                _hint('Tap a point to inspect · Scroll to pan'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Z-Score Trend ──────────────────────────────────────────────────
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelTitle('Z-score trend'),
                const SizedBox(height: 8),
                Wrap(spacing: 14, runSpacing: 6, children: [
                  _legendDot(kSuccess, 'Normal'),
                  _legendDot(kDanger,  '|Z| > 2 = flagged'),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  height: 190,
                  child: _InteractiveZChart(data: data, lineColor: accentColor),
                ),
                const SizedBox(height: 8),
                _hint('Tap a point to inspect · Scroll to pan'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Session Log ────────────────────────────────────────────────────
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _panelTitle('Session log'),
                const SizedBox(height: 2),
                Text('Latest ${data.length.clamp(0, 10)} entries',
                    style: const TextStyle(fontSize: 13, color: kTextSecondary)),
                const SizedBox(height: 14),
                const _SessionHeader(),
                ...List.generate(
                  data.length.clamp(0, 10),
                  (i) {
                    final idx = data.length - 1 - i;
                    return _SessionRow(pt: data[idx]);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pair(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 10),
      Expanded(child: b),
    ],
  );

  Widget _panelTitle(String title) => Text(
    title,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextPrimary, letterSpacing: -0.2),
  );

  Widget _hint(String text) => Text(text, style: const TextStyle(fontSize: 12, color: kTextMuted));

  Widget _legend(Color bar) {
    return Wrap(spacing: 16, runSpacing: 6, children: [
      _legendBar(bar, 'Session load'),
      _legendLine(Colors.pinkAccent, 'Exertion'),
    ]);
  }

  Widget _legendBar(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
  ]);

  Widget _legendLine(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 14, height: 2,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(1))),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
  ]);

  Widget _legendDot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    _Dot(c),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
  ]);

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(kRadius),
      border: Border.all(color: kBorder, width: 0.6),
    ),
    child: child,
  );
}

// ── Metric Card ───────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label, value;
  final String? status;
  final Color? statusColor;
  const _MetricCard({required this.label, required this.value, this.status, this.statusColor});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(kRadiusSm),
          border: Border.all(color: kBorder, width: 0.6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w700, color: kTextPrimary,
                letterSpacing: -0.8, height: 1.1, fontFeatures: _kTabular,
              ),
            ),
            if (status != null) ...[
              const SizedBox(height: 8),
              _StatusDot(color: statusColor ?? kTextMuted, label: status!),
            ],
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
      if (v <= 0)   return kTextMuted;
      if (v < 0.8)  return kInfo;
      if (v <= 1.3) return kSuccess;
      if (v <= 1.5) return kWarn;
      return kDanger;
    }
    // Current zone: 0 under, 1 sweet spot, 2 caution, 3 danger, -1 no data.
    final zone = acwr <= 0
        ? -1
        : acwr < 0.8 ? 0 : acwr <= 1.3 ? 1 : acwr <= 1.5 ? 2 : 3;
    const zoneNames = ['Under training', 'Sweet spot', 'Caution', 'Danger zone'];
    // Each zone's share of the 0.0–2.0 scale.
    const zones = [(40, kInfo), (25, kSuccess), (10, kWarn), (25, kDanger)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Value + zone
        if (zone < 0)
          const Text('No sessions logged yet',
              style: TextStyle(fontSize: 15, color: kTextSecondary))
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                acwr.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w700, color: kTextPrimary,
                  letterSpacing: -0.8, height: 1.1, fontFeatures: _kTabular,
                ),
              ),
              const SizedBox(width: 12),
              _StatusDot(color: zoneColor(acwr), label: zoneNames[zone]),
            ],
          ),
        const SizedBox(height: 16),

        // Gauge bar — flex proportional to each zone's share of 0.0–2.0. The
        // current zone is full strength, the rest recede.
        LayoutBuilder(builder: (ctx, c) {
          final w = c.maxWidth;
          const markerH = 20.0, barH = 8.0, labelTop = markerH + 6;
          final markerX = (w * (clamped / 2.0) - 1.5).clamp(0.0, w - 3.0);
          Widget tickAt(double frac, String label) => Positioned(
            left: w * frac,
            top: labelTop,
            child: FractionalTranslation(
              translation: const Offset(-0.5, 0),
              child: _GaugeTick(label),
            ),
          );
          return SizedBox(
            height: labelTop + 14,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0, right: 0, top: (markerH - barH) / 2, height: barH,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(barH / 2),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (int i = 0; i < zones.length; i++)
                        Expanded(
                          flex: zones[i].$1,
                          child: ColoredBox(
                            color: zones[i].$2.withValues(alpha: zone == i ? 1.0 : 0.28),
                          ),
                        ),
                    ]),
                  ),
                ),
                if (zone >= 0)
                  Positioned(
                    left: markerX, top: 0,
                    child: Container(
                      width: 3, height: markerH,
                      decoration: BoxDecoration(
                        color: kTextPrimary,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                // Scale labels at each zone boundary
                const Positioned(left: 0, top: labelTop, child: _GaugeTick('0')),
                tickAt(0.40, '0.8'),
                tickAt(0.65, '1.3'),
                tickAt(0.75, '1.5'),
                const Positioned(right: 0, top: labelTop, child: _GaugeTick('2.0+')),
              ],
            ),
          );
        }),
        const SizedBox(height: 14),

        // Zone key — the current zone reads brighter.
        Wrap(spacing: 14, runSpacing: 6, children: [
          for (int i = 0; i < zones.length; i++)
            _ZL(zoneNames[i], zones[i].$2, active: zone == i),
        ]),
      ],
    );
  }
}

class _GaugeTick extends StatelessWidget {
  final String label;
  const _GaugeTick(this.label);

  @override
  Widget build(BuildContext context) => Text(label, style: _kAxis);
}

class _ZL extends StatelessWidget {
  final String t;
  final Color  c;
  final bool   active;
  const _ZL(this.t, this.c, {required this.active});
  @override
  Widget build(BuildContext ctx) => Row(mainAxisSize: MainAxisSize.min, children: [
    _Dot(c),
    const SizedBox(width: 6),
    Text(t, style: TextStyle(
      fontSize: 12,
      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
      color: active ? kTextPrimary : kTextSecondary,
    )),
  ]);
}

// ── Chart helpers ─────────────────────────────────────────────────────────────

TextPainter _layoutText(String s, TextStyle style, {double maxWidth = double.infinity}) =>
    TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)
      ..layout(maxWidth: maxWidth);

/// Hairline horizontal gridline.
final Paint _kGridPaint = Paint()..color = kBorder..strokeWidth = 0.6;

/// One tooltip row: label on the left, value on the right, optional status
/// dot. An empty label draws just the dot and the value.
typedef _TipRow = (String label, String value, Color? dot);

/// Flat dark tooltip with a hairline edge, shared by the three charts.
void _paintTooltip(Canvas canvas, Size size, double x, double top, double minX,
    String header, List<_TipRow> rows) {
  const tw = 148.0, lh = 18.0, pad = 10.0;
  final h = pad * 2 + (rows.length + 1) * lh - 4;
  double tx = x + 10;
  if (tx + tw > size.width) tx = x - tw - 10;
  if (tx < minX) tx = minX;
  final ty = top + 2;
  final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(tx, ty, tw, h), const Radius.circular(10));
  canvas.drawRRect(rrect, Paint()..color = kSurface);
  canvas.drawRRect(rrect, Paint()
    ..color = kBorderBright
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6);

  _layoutText(header,
      const TextStyle(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w600),
      maxWidth: tw - pad * 2)
    .paint(canvas, Offset(tx + pad, ty + pad));

  for (int i = 0; i < rows.length; i++) {
    final (label, value, dot) = rows[i];
    final y = ty + pad + (i + 1) * lh;
    final valTp = _layoutText(value,
        const TextStyle(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w600, fontFeatures: _kTabular));
    var lx = tx + pad;
    if (dot != null) {
      canvas.drawCircle(Offset(lx + 3, y + valTp.height / 2), 3, Paint()..color = dot);
      lx += 11;
    }
    if (label.isEmpty) {
      valTp.paint(canvas, Offset(lx, y));
    } else {
      _layoutText(label, const TextStyle(color: kTextSecondary, fontSize: 12))
          .paint(canvas, Offset(lx, y));
      valTp.paint(canvas, Offset(tx + tw - pad - valTp.width, y));
    }
  }
}

/// Date label centred under [cx].
void _paintDateLabel(Canvas c, String s, double cx, double cy) {
  final tp = _layoutText(s, _kAxis);
  tp.paint(c, Offset(cx - tp.width / 2, cy));
}

/// Draws a date label at every [step]-th slot, plus the last one.
void _paintDateLabels(Canvas canvas, List<WorkPoint> data, double Function(int) xAt, double y) {
  final n = data.length;
  final step = n > 20 ? 5 : (n > 10 ? 3 : 2);
  for (int i = 0; i < n; i += step) {
    _paintDateLabel(canvas, data[i].d, xAt(i), y);
  }
  if ((n - 1) % step != 0) {
    _paintDateLabel(canvas, data[n - 1].d, xAt(n - 1), y);
  }
}

/// Selected point: white fill with a ring in the series/zone colour.
void _paintSelectedDot(Canvas canvas, Offset p, Color c) {
  canvas.drawCircle(p, 4.5, Paint()..color = kTextPrimary);
  canvas.drawCircle(p, 4.5, Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2);
}

/// Catmull-Rom → cubic Bézier segment from pts[i] to pts[i+1].
Path _smoothSegment(List<Offset> pts, int i) {
  final n = pts.length;
  final p0 = i > 0 ? pts[i - 1] : pts[0];
  final p1 = pts[i], p2 = pts[i + 1];
  final p3 = i < n - 2 ? pts[i + 2] : pts[n - 1];
  final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
  final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
  return Path()
    ..moveTo(p1.dx, p1.dy)
    ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
}

/// The whole smoothed polyline through [pts] (needs at least one point).
Path _smoothPath(List<Offset> pts) {
  final n = pts.length;
  final path = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (int i = 0; i < n - 1; i++) {
    final p0 = i > 0 ? pts[i - 1] : pts[0];
    final p1 = pts[i], p2 = pts[i + 1];
    final p3 = i < n - 2 ? pts[i + 2] : pts[n - 1];
    final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
    final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
  }
  return path;
}

/// Horizontal scroller + tap-to-select wrapper shared by the three charts.
class _ScrollableChart extends StatelessWidget {
  final int count;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final CustomPainter Function(double contentW) painter;
  const _ScrollableChart({
    required this.count,
    required this.selected,
    required this.onSelect,
    required this.painter,
  });

  static const lPad = 40.0, slotW = 30.0;

  @override
  Widget build(BuildContext context) {
    // Fill the panel exactly when the points fit; scroll when they don't.
    return LayoutBuilder(builder: (context, constraints) {
      final minW = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : MediaQuery.of(context).size.width - 72.0;
      final contentW = max(slotW * count, minW - lPad);
      final chartW = contentW + lPad;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: GestureDetector(
          onTapDown: (d) {
            final lx = d.localPosition.dx - lPad;
            if (lx < 0) return;
            final sl = contentW / count;
            final idx = (lx / sl).round().clamp(0, count - 1);
            hapticSelect();
            onSelect(selected == idx ? null : idx);
          },
          child: SizedBox(
            width: chartW,
            child: CustomPaint(painter: painter(contentW)),
          ),
        ),
      );
    });
  }
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
    return _ScrollableChart(
      count: widget.data.length,
      selected: _sel,
      onSelect: (i) => setState(() => _sel = i),
      painter: (contentW) => _LoadChartPainter(
        data: widget.data,
        barColor: widget.barColor,
        selectedIdx: _sel,
        contentW: contentW,
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

    // Baseline, gridlines + Y-axis labels
    canvas.drawLine(Offset(lp, tPad + chartH), Offset(size.width, tPad + chartH), _kGridPaint);
    for (final frac in [0.25, 0.5, 0.75, 1.0]) {
      final y = tPad + chartH * (1 - frac);
      canvas.drawLine(Offset(lp, y), Offset(size.width, y), _kGridPaint);
      final tp = _layoutText((vMax * frac).toStringAsFixed(0), _kAxis);
      tp.paint(canvas, Offset(lp - 6 - tp.width, y - tp.height / 2));
    }

    // Bars — flat fill; when one is selected the rest recede.
    final barW = (slotW * 0.55).clamp(5.0, 22.0);
    for (int i = 0; i < n; i++) {
      final h = data[i].load > 0 ? (chartH * data[i].load / vMax).clamp(2.0, chartH) : 0.0;
      if (h <= 0) continue;
      final rect = Rect.fromLTWH(xAt(i) - barW / 2, tPad + chartH - h, barW, h);
      final dimmed = selectedIdx != null && selectedIdx != i;
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect,
            topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
        Paint()..color = barColor.withValues(alpha: dimmed ? 0.35 : 0.85),
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
      canvas.drawPath(_smoothPath(exertPts), Paint()
        ..color = Colors.pinkAccent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round);
    }
    for (final p in exertPts) {
      canvas.drawCircle(p, 2.5, Paint()..color = Colors.pinkAccent);
    }

    // Selection vertical line + tooltip
    if (selectedIdx != null && selectedIdx! < n) {
      final si = selectedIdx!;
      final x = xAt(si);
      canvas.drawLine(Offset(x, tPad), Offset(x, tPad + chartH),
          Paint()..color = kBorderBright..strokeWidth = 1);
      final exert = data[si].load > 0
          ? (min(10.0, 2.087 * log(data[si].load / 50.0 + 1.0) + 2.0)).toStringAsFixed(1)
          : '—';
      _paintTooltip(canvas, size, x, tPad, lp, data[si].d, [
        ('Load',     data[si].load.toStringAsFixed(0), null),
        ('Exertion', '$exert / 10', null),
        ('Acute',    data[si].acute.toStringAsFixed(0), null),
        ('Chronic',  data[si].chronic.toStringAsFixed(0), null),
        ('ACWR',     data[si].acwr <= 0 ? '—' : data[si].acwr.toStringAsFixed(2), null),
      ]);
    }

    // Date labels
    _paintDateLabels(canvas, data, xAt, size.height - bPad + 7);
  }

  @override
  bool shouldRepaint(covariant _LoadChartPainter old) =>
      old.data != data || old.barColor != barColor || old.selectedIdx != selectedIdx ||
      old.contentW != contentW;
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
    return _ScrollableChart(
      count: widget.data.length,
      selected: _sel,
      onSelect: (i) => setState(() => _sel = i),
      painter: (contentW) => _AcwrPainter(
        data: widget.data,
        lineColor: widget.lineColor,
        selectedIdx: _sel,
        contentW: contentW,
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

    // Zone bands — a faint flat wash per zone
    void band(double lo, double hi, Color c) {
      canvas.drawRect(Rect.fromLTRB(lp, yAt(hi), size.width, yAt(lo)),
          Paint()..color = c.withValues(alpha: 0.06));
    }
    band(0.0, 0.8, kInfo);
    band(0.8, 1.3, kSuccess);
    band(1.3, 1.5, kWarn);
    band(1.5, 2.5, kDanger);

    // Baseline, gridlines (zone thresholds dashed) + Y-axis labels
    canvas.drawLine(Offset(lp, yAt(0)), Offset(size.width, yAt(0)), _kGridPaint);
    for (final v in [0.5, 0.8, 1.0, 1.3, 1.5, 2.0]) {
      final y = yAt(v);
      if (y < tPad || y > tPad + chartH) continue;
      if (v == 0.8 || v == 1.3 || v == 1.5) {
        _dashH(canvas, lp, size.width, y, kBorderBright);
      } else {
        canvas.drawLine(Offset(lp, y), Offset(size.width, y), _kGridPaint);
      }
      final tp = _layoutText(v.toStringAsFixed(1), _kAxis);
      tp.paint(canvas, Offset(lp - 6 - tp.width, y - tp.height / 2));
    }

    final vals = data.map((d) => d.acwr.clamp(vMin, vMax)).toList();
    final pts  = List.generate(n, (i) => Offset(xAt(i), yAt(vals[i])));

    Color segColor(double v) {
      if (v < 0.8)  return kInfo;
      if (v <= 1.3) return kSuccess;
      if (v <= 1.5) return kWarn;
      return kDanger;
    }

    // Flat wash under the line
    final fillPath = _smoothPath(pts)
      ..lineTo(pts.last.dx, tPad + chartH)
      ..lineTo(pts.first.dx, tPad + chartH)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = lineColor.withValues(alpha: 0.10));

    // Smooth colour-coded ACWR line segments
    for (int i = 0; i < n - 1; i++) {
      canvas.drawPath(_smoothSegment(pts, i), Paint()
        ..color = segColor((vals[i] + vals[i + 1]) / 2)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round);
    }

    // Data dots
    for (int i = 0; i < n; i++) {
      if (selectedIdx == i) {
        _paintSelectedDot(canvas, pts[i], segColor(vals[i]));
      } else {
        canvas.drawCircle(pts[i], 2.5, Paint()..color = segColor(vals[i]));
      }
    }

    // Selection line + tooltip
    if (selectedIdx != null && selectedIdx! < n) {
      final si = selectedIdx!;
      final x = xAt(si);
      canvas.drawLine(Offset(x, tPad), Offset(x, tPad + chartH),
          Paint()..color = kBorderBright..strokeWidth = 1);
      _paintTooltip(canvas, size, x, tPad, lp, data[si].d, [
        ('ACWR', vals[si].toStringAsFixed(2), segColor(vals[si])),
      ]);
    }

    // Date labels
    _paintDateLabels(canvas, data, xAt, size.height - bPad + 7);
  }

  void _dashH(Canvas c, double x0, double x1, double y, Color col) {
    final p = Paint()..color = col..strokeWidth = 0.8;
    double x = x0;
    while (x < x1) {
      c.drawLine(Offset(x, y), Offset(min(x + 5, x1), y), p);
      x += 9;
    }
  }

  @override
  bool shouldRepaint(covariant _AcwrPainter old) =>
      old.data != data || old.selectedIdx != selectedIdx ||
      old.lineColor != lineColor || old.contentW != contentW;
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
    return _ScrollableChart(
      count: widget.data.length,
      selected: _sel,
      onSelect: (i) => setState(() => _sel = i),
      painter: (contentW) => _ZScorePainter(
        data: widget.data,
        lineColor: widget.lineColor,
        selectedIdx: _sel,
        contentW: contentW,
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
        Paint()..color = kDanger.withValues(alpha: 0.06));
    canvas.drawRect(Rect.fromLTRB(lp, yAt(-2.0), size.width, yAt(vMin)),
        Paint()..color = kDanger.withValues(alpha: 0.06));
    // Normal band
    canvas.drawRect(Rect.fromLTRB(lp, yAt(2.0), size.width, yAt(-2.0)),
        Paint()..color = kSuccess.withValues(alpha: 0.04));

    // Gridlines + Y-axis labels; the ±2 flag thresholds in the danger colour
    for (final v in [-3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0]) {
      final y = yAt(v);
      if (y < tPad || y > tPad + chartH) continue;
      final isThreshold = v == 2.0 || v == -2.0;
      canvas.drawLine(Offset(lp, y), Offset(size.width, y),
          isThreshold
              ? (Paint()..color = kDanger.withValues(alpha: 0.45)..strokeWidth = 0.8)
              : _kGridPaint);
      final tp = _layoutText(v == 0.0 ? '0' : v.toStringAsFixed(0), _kAxis);
      tp.paint(canvas, Offset(lp - 6 - tp.width, y - tp.height / 2));
    }

    // Zero line
    canvas.drawLine(Offset(lp, yAt(0)), Offset(size.width, yAt(0)),
        Paint()..color = kBorderBright..strokeWidth = 0.8);

    final vals = data.map((d) => d.z.clamp(vMin, vMax)).toList();
    final pts  = List.generate(n, (i) => Offset(xAt(i), yAt(vals[i])));

    Color ptColor(double z) => z.abs() > 2 ? kDanger : kSuccess;

    // Catmull-Rom spline path
    final linePath = _smoothPath(pts);

    // Flat washes above / below zero
    final zeroY = yAt(0);
    final fillAbove = Path.from(linePath)
      ..lineTo(pts.last.dx, zeroY)
      ..lineTo(pts.first.dx, zeroY)
      ..close();
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(lp, tPad, size.width, zeroY));
    canvas.drawPath(fillAbove, Paint()..color = lineColor.withValues(alpha: 0.10));
    canvas.restore();

    final fillBelow = Path.from(linePath)
      ..lineTo(pts.last.dx, zeroY)
      ..lineTo(pts.first.dx, zeroY)
      ..close();
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(lp, zeroY, size.width, tPad + chartH));
    canvas.drawPath(fillBelow, Paint()..color = kDanger.withValues(alpha: 0.08));
    canvas.restore();

    // The line, colour-coded per segment
    for (int i = 0; i < n - 1; i++) {
      final midZ = (vals[i] + vals[i + 1]) / 2;
      canvas.drawPath(_smoothSegment(pts, i), Paint()
        ..color = ptColor(midZ)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round);
    }

    // Dots
    for (int i = 0; i < n; i++) {
      final col = ptColor(vals[i]);
      if (selectedIdx == i) {
        _paintSelectedDot(canvas, pts[i], col);
      } else {
        canvas.drawCircle(pts[i], 2.5, Paint()..color = col);
      }
    }

    // Selection line + tooltip
    if (selectedIdx != null && selectedIdx! < n) {
      final si = selectedIdx!;
      final x = xAt(si);
      canvas.drawLine(Offset(x, tPad), Offset(x, tPad + chartH),
          Paint()..color = kBorderBright..strokeWidth = 1);
      final z = data[si].z;
      final col = ptColor(vals[si]);
      _paintTooltip(canvas, size, x, tPad, lp, data[si].d, [
        ('Z-score', z.toStringAsFixed(2), null),
        ('', z.abs() > 2 ? 'Flagged' : 'Normal', col),
      ]);
    }

    // Date labels
    _paintDateLabels(canvas, data, xAt, size.height - bPad + 7);
  }

  @override
  bool shouldRepaint(covariant _ZScorePainter old) =>
      old.data != data || old.selectedIdx != selectedIdx ||
      old.lineColor != lineColor || old.contentW != contentW;
}

// ── Session Log ───────────────────────────────────────────────────────────────
// A compact table: one header row, then one hairline-separated row per day.

const _kLogFlex = [4, 4, 5, 4, 5, 5, 5]; // Date, Load, Exertion, Acute, Chronic, ACWR, Z

class _SessionHeader extends StatelessWidget {
  const _SessionHeader();

  static const _labels = ['Date', 'Load', 'Exertion', 'Acute', 'Chronic', 'ACWR', 'Z'];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          for (int i = 0; i < _labels.length; i++)
            Expanded(
              flex: _kLogFlex[i],
              child: Align(
                alignment: i == 0 ? Alignment.centerLeft : Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_labels[i],
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kTextMuted)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final WorkPoint pt;
  const _SessionRow({required this.pt});

  @override
  Widget build(BuildContext context) {
    Color acwrCol(double v) {
      if (v <= 0)   return kTextMuted;
      if (v < 0.8)  return kInfo;
      if (v <= 1.3) return kSuccess;
      if (v <= 1.5) return kWarn;
      return kDanger;
    }
    final exert = pt.load > 0
        ? (min(10.0, 2.087 * log(pt.load / 50.0 + 1.0) + 2.0)).toStringAsFixed(1)
        : '—';
    final acwr  = pt.acwr <= 0 ? '—' : pt.acwr.toStringAsFixed(2);
    final flagged = pt.z.abs() > 2;

    return Semantics(
      label: '${pt.d}: load ${pt.load.toStringAsFixed(0)}, exertion $exert, '
          'acute ${pt.acute.toStringAsFixed(0)}, chronic ${pt.chronic.toStringAsFixed(0)}, '
          'ACWR $acwr, Z ${pt.z.toStringAsFixed(2)}${flagged ? ', flagged' : ''}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kBorder, width: 0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            _cell(0, Text(pt.d,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary))),
            _cell(1, _num(pt.load.toStringAsFixed(0))),
            _cell(2, _num(exert)),
            _cell(3, _num(pt.acute.toStringAsFixed(0))),
            _cell(4, _num(pt.chronic.toStringAsFixed(0))),
            _cell(5, _num(acwr, dot: pt.acwr <= 0 ? null : acwrCol(pt.acwr))),
            _cell(6, _num(pt.z.toStringAsFixed(2), dot: flagged ? kDanger : null)),
          ]),
        ),
      ),
    );
  }

  Widget _cell(int col, Widget child) => Expanded(
    flex: _kLogFlex[col],
    child: Align(
      alignment: col == 0 ? Alignment.centerLeft : Alignment.centerRight,
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    ),
  );

  Widget _num(String value, {Color? dot}) => Row(mainAxisSize: MainAxisSize.min, children: [
    if (dot != null) ...[_Dot(dot, size: 6), const SizedBox(width: 4)],
    Text(value,
        style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500, color: kTextPrimary, fontFeatures: _kTabular)),
  ]);
}

// ── Screen-level empty state ──────────────────────────────────────────────────────

class _WorkloadEmpty extends StatelessWidget {
  const _WorkloadEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: _EmptyMessage(
          icon: Icons.monitor_heart_outlined,
          title: 'No training data yet',
          hint: 'Log sessions to see your workload stats here.',
        ),
      ),
    );
  }
}
