import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

const Color _kBg = Color(0xFF0D1117);
const Color _kSurface = Color(0xFF161B22);
const Color _kCard = Color(0xFF1C2333);
const Color _kAccent = Color(0xFFFF6B35);
const Color _kBorder = Color(0xFF30363D);
const Color _kTextPrimary = Color(0xFFE6EDF3);
const Color _kTextSecondary = Color(0xFF8B949E);

// ── Enums ─────────────────────────────────────────────────────────────────────

enum PrimarySessionType {
  strength('Strength Program'),
  power('Power Program'),
  endurance('Endurance Program'),
  plyometrics('Plyometrics/Agility'),
  hiit('HIIT'),
  rest('Rest Day'),
  match('Match Day');

  final String label;
  const PrimarySessionType(this.label);
}

enum SecondarySessionType {
  corrective('Corrective Prehab'),
  core('Core Program');

  final String label;
  const SecondarySessionType(this.label);
}

enum SkillSessionType {
  batting('Batting'),
  bowling('Bowling'),
  fielding('Fielding'),
  wicketkeeping('Wicket-keeping'),
  rest('Rest Day');

  final String label;
  const SkillSessionType(this.label);
}

// ── Data Model ────────────────────────────────────────────────────────────────

class TrainingSession {
  final DateTime date;
  // Readiness (1 = best, 5 = worst)
  final int sleep;
  final int wellness;
  final int soreness;
  final int fatigue;
  // Primary session
  final Set<PrimarySessionType> primaryTypes;
  final int primaryDuration;
  final int primaryRpe;
  // Secondary session (optional)
  final Set<SecondarySessionType> secondaryTypes;
  final int? secondaryDuration;
  final int? secondaryRpe;
  // Additional
  final int? distance;
  final int? sprints;
  final int? maxHR;
  final int? avgHR;
  // Skill session (optional)
  final Set<SkillSessionType> skillTypes;
  final int? skillDuration;
  final int? skillRpe;
  final int? ballsBowled;
  final int? skillMaxHR;
  final int? skillAvgHR;

  TrainingSession({
    required this.date,
    required this.sleep,
    required this.wellness,
    required this.soreness,
    required this.fatigue,
    required this.primaryTypes,
    required this.primaryDuration,
    required this.primaryRpe,
    Set<SecondarySessionType>? secondaryTypes,
    this.secondaryDuration,
    this.secondaryRpe,
    this.distance,
    this.sprints,
    this.maxHR,
    this.avgHR,
    Set<SkillSessionType>? skillTypes,
    this.skillDuration,
    this.skillRpe,
    this.ballsBowled,
    this.skillMaxHR,
    this.skillAvgHR,
  })  : secondaryTypes = secondaryTypes ?? {},
        skillTypes = skillTypes ?? {};

  double get primaryLoad => (primaryRpe * primaryDuration).toDouble();

  double get secondaryLoad {
    if (secondaryDuration != null && secondaryRpe != null) {
      return (secondaryRpe! * secondaryDuration!).toDouble();
    }
    return 0;
  }

  double get skillLoad {
    if (skillDuration != null && skillRpe != null) {
      return (skillRpe! * skillDuration!).toDouble();
    }
    return 0;
  }

  double get totalLoad => primaryLoad + secondaryLoad + skillLoad;

  double get scaledGrade {
    if (totalLoad <= 0) return 0;
    return (log(totalLoad) / log(1000)) * 10;
  }

  double get readinessPercent {
    final score = (5 - sleep) + (5 - wellness) + (5 - soreness) + (5 - fatigue);
    return (score / 16.0) * 100;
  }

  Color get readinessColor {
    final p = readinessPercent;
    if (p >= 75) return Colors.greenAccent;
    if (p >= 50) return Colors.yellowAccent;
    if (p >= 25) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class TrainingLoadScreen extends StatefulWidget {
  const TrainingLoadScreen({super.key});

  @override
  State<TrainingLoadScreen> createState() => _TrainingLoadScreenState();
}

class _TrainingLoadScreenState extends State<TrainingLoadScreen>
    with SingleTickerProviderStateMixin {
  final List<TrainingSession> _sessions = [];
  late final TabController _tabController;

  // Readiness
  int _sleep = 1;
  int _wellness = 1;
  int _soreness = 1;
  int _fatigue = 1;

  // Primary
  final Set<PrimarySessionType> _primaryTypes = {};
  final _primaryDurCtrl = TextEditingController();
  int _primaryRpe = 5;

  // Secondary
  bool _hasSecondary = false;
  final Set<SecondarySessionType> _secondaryTypes = {};
  final _secondaryDurCtrl = TextEditingController();
  int _secondaryRpe = 5;

  // Secondary distance & sprints (endurance/HIIT only)
  final _secondaryDistanceCtrl = TextEditingController();
  final _secondarySprintsCtrl = TextEditingController();

  // Additional
  final _distanceCtrl = TextEditingController();
  final _sprintsCtrl = TextEditingController();
  final _maxHRCtrl = TextEditingController();
  final _avgHRCtrl = TextEditingController();

  // Skill
  bool _hasSkill = false;
  final Set<SkillSessionType> _skillTypes = {};
  final _skillDurCtrl = TextEditingController();
  int _skillRpe = 5;
  final _ballsCtrl = TextEditingController();
  final _skillMaxHRCtrl = TextEditingController();
  final _skillAvgHRCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in [
      _primaryDurCtrl, _secondaryDurCtrl, _secondaryDistanceCtrl, _secondarySprintsCtrl, _distanceCtrl, _sprintsCtrl,
      _maxHRCtrl, _avgHRCtrl, _skillDurCtrl, _ballsCtrl,
      _skillMaxHRCtrl, _skillAvgHRCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Computed metrics ──────────────────────────────────────────────────────

  double get _acuteLoad {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _sessions
        .where((s) => s.date.isAfter(cutoff))
        .fold(0.0, (sum, s) => sum + s.totalLoad);
  }

  double get _chronicLoad {
    if (_sessions.isEmpty) return 0;
    const lambda = 2.0 / 29.0;
    final sorted = List<TrainingSession>.from(_sessions)
      ..sort((a, b) => a.date.compareTo(b.date));
    double ewma = sorted.first.totalLoad;
    for (int i = 1; i < sorted.length; i++) {
      ewma = (sorted[i].totalLoad * lambda) + (ewma * (1 - lambda));
    }
    return ewma;
  }

  double get _acwr {
    final chronic = _chronicLoad;
    if (chronic == 0) return 0;
    return _acuteLoad / chronic;
  }

  double get _zScore {
    if (_sessions.length < 2) return 0;
    final loads = _sessions.map((s) => s.totalLoad).toList();
    final mean = loads.reduce((a, b) => a + b) / loads.length;
    final variance = loads
        .map((l) => pow(l - mean, 2))
        .reduce((a, b) => a + b) / loads.length;
    final sigma = sqrt(variance);
    if (sigma == 0) return 0;
    return (_sessions.last.totalLoad - mean) / sigma;
  }

  // ── Series builder ───────────────────────────────────────────────────────

  List<Map<String, dynamic>> _buildSeries(
      double Function(TrainingSession) loadFn) {
    if (_sessions.isEmpty) return [];
    final sorted = List<TrainingSession>.from(_sessions)
      ..sort((a, b) => a.date.compareTo(b.date));
    const lambda = 2.0 / 29.0;
    double ewma = 0;
    return List.generate(sorted.length, (i) {
      final load = loadFn(sorted[i]);
      ewma = i == 0 ? load : (load * lambda) + (ewma * (1 - lambda));
      final cutoff = sorted[i].date.subtract(const Duration(days: 7));
      final acute = sorted
          .sublist(0, i + 1)
          .where((s) => s.date.isAfter(cutoff))
          .fold(0.0, (sum, s) => sum + loadFn(s));
      return {
        'date': sorted[i].date,
        'load': load,
        'ewma': ewma,
        'acwr': ewma == 0 ? 0.0 : acute / ewma,
        'strain': load <= 0 ? 0.0 : (log(load) / log(1000)) * 10,
      };
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_primaryTypes.isEmpty) {
      _snack("Select at least one Primary Session Type");
      return;
    }
    final primaryDur = int.tryParse(_primaryDurCtrl.text.trim()) ?? 0;
    if (primaryDur <= 0) {
      _snack("Enter a valid Primary Session duration");
      return;
    }
    if (_hasSecondary) {
      final secDur = int.tryParse(_secondaryDurCtrl.text.trim()) ?? 0;
      if (secDur <= 0) {
        _snack("Enter a valid Secondary Session duration");
        return;
      }
    }
    if (_hasSkill) {
      if (_skillTypes.isEmpty) {
        _snack("Select at least one Skill Session Type");
        return;
      }
      final skillDur = int.tryParse(_skillDurCtrl.text.trim()) ?? 0;
      if (skillDur <= 0) {
        _snack("Enter a valid Skill Session duration");
        return;
      }
    }

    final now = DateTime.now();

    setState(() {
      _sessions.add(TrainingSession(
        date: now,
        sleep: _sleep,
        wellness: _wellness,
        soreness: _soreness,
        fatigue: _fatigue,
        primaryTypes: Set.from(_primaryTypes),
        primaryDuration: primaryDur,
        primaryRpe: _primaryRpe,
        secondaryTypes: _hasSecondary ? Set.from(_secondaryTypes) : null,
        secondaryDuration: _hasSecondary
            ? int.tryParse(_secondaryDurCtrl.text.trim())
            : null,
        secondaryRpe: _hasSecondary ? _secondaryRpe : null,
        distance: int.tryParse(_distanceCtrl.text.trim()),
        sprints: int.tryParse(_sprintsCtrl.text.trim()),
        maxHR: int.tryParse(_maxHRCtrl.text.trim()),
        avgHR: int.tryParse(_avgHRCtrl.text.trim()),
        skillTypes: _hasSkill ? Set.from(_skillTypes) : null,
        skillDuration: _hasSkill
            ? int.tryParse(_skillDurCtrl.text.trim())
            : null,
        skillRpe: _hasSkill ? _skillRpe : null,
        ballsBowled: _hasSkill && _skillTypes.contains(SkillSessionType.bowling)
            ? int.tryParse(_ballsCtrl.text.trim())
            : null,
        skillMaxHR: _hasSkill ? int.tryParse(_skillMaxHRCtrl.text.trim()) : null,
        skillAvgHR: _hasSkill ? int.tryParse(_skillAvgHRCtrl.text.trim()) : null,
      ));
      _clearForm();
    });

    _tabController.animateTo(1);
    _snack("Session logged!");

    // Sync to backend (non-blocking — failure is silently ignored so offline
    // use still works; the local list already has the entry).
    try {
      await ApiService.submitSession({
        'date': now.toIso8601String(),
        'sleep': _sleep,
        'wellness': _wellness,
        'soreness': _soreness,
        'fatigue': _fatigue,
        'primaryTypes': _primaryTypes.map((e) => e.name).toList(),
        'primaryDuration': primaryDur,
        'primaryRpe': _primaryRpe,
        if (_hasSecondary) ...{
          'secondaryTypes': _secondaryTypes.map((e) => e.name).toList(),
          'secondaryDuration': int.tryParse(_secondaryDurCtrl.text.trim()),
          'secondaryRpe': _secondaryRpe,
        },
        if (int.tryParse(_distanceCtrl.text.trim()) != null)
          'distance': int.parse(_distanceCtrl.text.trim()),
        if (int.tryParse(_sprintsCtrl.text.trim()) != null)
          'sprints': int.parse(_sprintsCtrl.text.trim()),
        if (int.tryParse(_maxHRCtrl.text.trim()) != null)
          'maxHR': int.parse(_maxHRCtrl.text.trim()),
        if (int.tryParse(_avgHRCtrl.text.trim()) != null)
          'avgHR': int.parse(_avgHRCtrl.text.trim()),
        if (_hasSkill) ...{
          'skillTypes': _skillTypes.map((e) => e.name).toList(),
          'skillDuration': int.tryParse(_skillDurCtrl.text.trim()),
          'skillRpe': _skillRpe,
          if (_skillTypes.contains(SkillSessionType.bowling) &&
              int.tryParse(_ballsCtrl.text.trim()) != null)
            'ballsBowled': int.parse(_ballsCtrl.text.trim()),
          if (int.tryParse(_skillMaxHRCtrl.text.trim()) != null)
            'skillMaxHR': int.parse(_skillMaxHRCtrl.text.trim()),
          if (int.tryParse(_skillAvgHRCtrl.text.trim()) != null)
            'skillAvgHR': int.parse(_skillAvgHRCtrl.text.trim()),
        },
      });
    } catch (_) {
      // Backend unavailable — local session already saved above.
    }
  }

  void _clearForm() {
    _sleep = 1;
    _wellness = 1;
    _soreness = 1;
    _fatigue = 1;
    _primaryTypes.clear();
    _primaryDurCtrl.clear();
    _primaryRpe = 5;
    _hasSecondary = false;
    _secondaryTypes.clear();
    _secondaryDurCtrl.clear();
    _secondaryRpe = 5;
    _secondaryDistanceCtrl.clear();
    _secondarySprintsCtrl.clear();
    _distanceCtrl.clear();
    _sprintsCtrl.clear();
    _maxHRCtrl.clear();
    _avgHRCtrl.clear();
    _hasSkill = false;
    _skillTypes.clear();
    _skillDurCtrl.clear();
    _skillRpe = 5;
    _ballsCtrl.clear();
    _skillMaxHRCtrl.clear();
    _skillAvgHRCtrl.clear();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kSurface,
        title: const Text(
          "Training Load",
          style: TextStyle(color: _kTextPrimary, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: _kTextPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              const Divider(height: 1, color: _kBorder),
              TabBar(
                controller: _tabController,
                labelColor: _kAccent,
                unselectedLabelColor: _kTextSecondary,
                indicatorColor: _kAccent,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(icon: Icon(Icons.edit_note_rounded), text: "Log Session"),
                  Tab(icon: Icon(Icons.dashboard_rounded), text: "Dashboard"),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildLogTab(), _buildDashboardTab()],
      ),
    );
  }

  // ── Log Tab ───────────────────────────────────────────────────────────────

  Widget _buildLogTab() {
    final showExtra = _primaryTypes.contains(PrimarySessionType.endurance) ||
        _primaryTypes.contains(PrimarySessionType.hiit);
    final showBowling = _skillTypes.contains(SkillSessionType.bowling);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Readiness ──────────────────────────────────────────────────
          _SectionCard(
            title: "Readiness",
            subtitle: "Quantifying your wellness",
            child: Column(
              children: [
                _ReadinessRow(
                  label: "Sleep Score",
                  value: _sleep,
                  lowLabel: "Excellent",
                  highLabel: "Poor",
                  onChanged: (v) => setState(() => _sleep = v),
                ),
                const SizedBox(height: 10),
                _ReadinessRow(
                  label: "Wellness Score",
                  value: _wellness,
                  lowLabel: "Excellent",
                  highLabel: "Poor",
                  onChanged: (v) => setState(() => _wellness = v),
                ),
                const SizedBox(height: 10),
                _ReadinessRow(
                  label: "Soreness Score",
                  value: _soreness,
                  lowLabel: "No Soreness",
                  highLabel: "Very Severe",
                  onChanged: (v) => setState(() => _soreness = v),
                ),
                const SizedBox(height: 10),
                _ReadinessRow(
                  label: "Fatigue Score",
                  value: _fatigue,
                  lowLabel: "Fully Fresh",
                  highLabel: "Exhausted",
                  onChanged: (v) => setState(() => _fatigue = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Primary Session ────────────────────────────────────────────
          _SectionCard(
            title: "Primary Training Session",
            subtitle: "Select HIIT when doing strides and sprints",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldLabel("Session Type I (Primary)"),
                const SizedBox(height: 8),
                _ChipSelector<PrimarySessionType>(
                  values: PrimarySessionType.values,
                  selected: _primaryTypes,
                  label: (v) => v.label,
                  onToggle: (v) => setState(() => _primaryTypes.contains(v)
                      ? _primaryTypes.remove(v)
                      : _primaryTypes.add(v)),
                ),
                const SizedBox(height: 14),
                _NumField(ctrl: _primaryDurCtrl, label: "Duration (minutes)"),
                const SizedBox(height: 14),
                const _FieldLabel("RPE — Session I"),
                _RpeSlider(
                  value: _primaryRpe,
                  onChanged: (v) => setState(() => _primaryRpe = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Secondary Session ──────────────────────────────────────────
          _SectionCard(
            title: "Secondary Session",
            subtitle: "Corrective prehab or core work",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Add Secondary Session"),
                    Switch(
                      value: _hasSecondary,
                      onChanged: (v) => setState(() => _hasSecondary = v),
                    ),
                  ],
                ),
                if (_hasSecondary) ...[
                  const SizedBox(height: 10),
                  const _FieldLabel("Session Type II (Subordinate)"),
                  const SizedBox(height: 8),
                  _ChipSelector<SecondarySessionType>(
                    values: SecondarySessionType.values,
                    selected: _secondaryTypes,
                    label: (v) => v.label,
                    onToggle: (v) => setState(() =>
                        _secondaryTypes.contains(v)
                            ? _secondaryTypes.remove(v)
                            : _secondaryTypes.add(v)),
                  ),
                  const SizedBox(height: 14),
                  _NumField(
                      ctrl: _secondaryDurCtrl, label: "Duration (minutes)"),
                  const SizedBox(height: 14),
                  const _FieldLabel("RPE — Session II"),
                  _RpeSlider(
                    value: _secondaryRpe,
                    onChanged: (v) => setState(() => _secondaryRpe = v),
                  ),
                  if (showExtra) ...[
                    const SizedBox(height: 14),
                    _NumField(
                      ctrl: _secondaryDistanceCtrl,
                      label: "Distance (metres) — Endurance/HIIT only",
                    ),
                    const SizedBox(height: 10),
                    _NumField(
                      ctrl: _secondarySprintsCtrl,
                      label: "Sprints — High Intensity Running (total no.)",
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Additional Metrics ─────────────────────────────────────────
          _SectionCard(
            title: "Additional Metrics",
            subtitle: "Optional — fill what you have",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showExtra) ...[
                  _NumField(
                    ctrl: _distanceCtrl,
                    label: "Distance in Metres (Endurance/HIIT only)",
                  ),
                  const SizedBox(height: 10),
                  _NumField(
                    ctrl: _sprintsCtrl,
                    label: "Sprints — total no. of sprints",
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                        child: _NumField(
                            ctrl: _maxHRCtrl, label: "Max Heart Rate")),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _NumField(
                            ctrl: _avgHRCtrl, label: "Avg Heart Rate")),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Skill Session ──────────────────────────────────────────────
          _SectionCard(
            title: "Skill Session",
            subtitle: "Quantifying your skill session's load",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Add Skill Session"),
                    Switch(
                      value: _hasSkill,
                      onChanged: (v) => setState(() => _hasSkill = v),
                    ),
                  ],
                ),
                if (_hasSkill) ...[
                  const SizedBox(height: 10),
                  const _FieldLabel("Session Type"),
                  const SizedBox(height: 8),
                  _ChipSelector<SkillSessionType>(
                    values: SkillSessionType.values,
                    selected: _skillTypes,
                    label: (v) => v.label,
                    onToggle: (v) => setState(() =>
                        _skillTypes.contains(v)
                            ? _skillTypes.remove(v)
                            : _skillTypes.add(v)),
                  ),
                  const SizedBox(height: 14),
                  _NumField(ctrl: _skillDurCtrl, label: "Duration (minutes)"),
                  if (showBowling) ...[
                    const SizedBox(height: 10),
                    _NumField(
                      ctrl: _ballsCtrl,
                      label: "No. of balls bowled in a day (bowlers only)",
                    ),
                  ],
                  const SizedBox(height: 14),
                  const _FieldLabel("RPE (Rate of Perceived Exertion)"),
                  _RpeSlider(
                    value: _skillRpe,
                    onChanged: (v) => setState(() => _skillRpe = v),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _NumField(
                              ctrl: _skillMaxHRCtrl, label: "Max Heart Rate")),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _NumField(
                              ctrl: _skillAvgHRCtrl, label: "Avg Heart Rate")),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text("Submit Session"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Dashboard Tab ─────────────────────────────────────────────────────────

  Widget _buildDashboardTab() {
    final acwr = _acwr;
    final zScore = _zScore;
    final last = _sessions.isNotEmpty ? _sessions.last : null;

    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 52, color: _kBorder),
            const SizedBox(height: 16),
            const Text(
              "No sessions yet",
              style: TextStyle(
                color: _kTextPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Tap 'Log Session' to get started.",
              style: TextStyle(color: _kTextSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Readiness
          if (last != null)
            _SectionCard(
              title: "Latest Readiness",
              child: Row(
                children: [
                  _ReadinessDot(
                      pct: last.readinessPercent,
                      color: last.readinessColor),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${last.readinessPercent.toStringAsFixed(0)}% Ready",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: last.readinessColor),
                        ),
                        Text(
                          "Sleep ${last.sleep}  •  Wellness ${last.wellness}"
                          "  •  Soreness ${last.soreness}  •  Fatigue ${last.fatigue}",
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Load metrics
          _SectionCard(
            title: "Load Metrics",
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: "Acute Load",
                        subtitle: "Last 7 days",
                        value: _acuteLoad.toStringAsFixed(0),
                        color: Colors.lightBlueAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        label: "Chronic Load",
                        subtitle: "EWMA 28-day",
                        value: _chronicLoad.toStringAsFixed(1),
                        color: Colors.purpleAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: "ACWR",
                        subtitle: _acwrLabel(acwr),
                        value: acwr == 0 ? "—" : acwr.toStringAsFixed(2),
                        color: _acwrColor(acwr),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        label: "Scaled Grade",
                        subtitle: "Last session",
                        value: last != null
                            ? last.scaledGrade.toStringAsFixed(1)
                            : "—",
                        color: Colors.yellowAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MetricTile(
                  label: "Z-Score",
                  subtitle: "Last vs chronic baseline",
                  value: _sessions.length < 2
                      ? "—"
                      : zScore.toStringAsFixed(2),
                  color: zScore > 2
                      ? Colors.redAccent
                      : zScore < -2
                          ? Colors.blueAccent
                          : Colors.tealAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: "ACWR Zone",
            child: _AcwrGauge(acwr: acwr),
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: "Session Load History",
            child: _LoadBarChart(sessions: _sessions),
          ),
          const SizedBox(height: 12),

          // Readiness Trend
          _SectionCard(
            title: "Readiness Trend",
            subtitle: "% Readiness per session over time",
            child: _ReadinessTrendChart(sessions: _sessions),
          ),
          const SizedBox(height: 12),

          // ACWR Trend charts
          _SectionCard(
            title: "ACWR Trends",
            subtitle: "Green = Chronic Load  •  Orange dashed = ACWR",
            child: Column(
              children: [
                _AcwrTrendChart(
                  data: _buildSeries((s) => s.primaryLoad),
                  title: "Training ACWR",
                  lineColor: Colors.lightBlueAccent,
                ),
                const SizedBox(height: 14),
                _AcwrTrendChart(
                  data: _buildSeries((s) => s.skillLoad),
                  title: "Skill's ACWR",
                  lineColor: Colors.greenAccent,
                ),
                const SizedBox(height: 14),
                _AcwrTrendChart(
                  data: _buildSeries((s) => s.totalLoad),
                  title: "Daily ACWR",
                  lineColor: Colors.purpleAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Load vs Strain charts
          _SectionCard(
            title: "Load vs Strain",
            subtitle: "Bars = Session Load  •  White line = Scaled Grade",
            child: Column(
              children: [
                _LoadStrainChart(
                  data: _buildSeries((s) => s.primaryLoad),
                  title: "Training Load vs Training Strain",
                  barColor: Colors.lightBlueAccent,
                ),
                const SizedBox(height: 14),
                _LoadStrainChart(
                  data: _buildSeries((s) => s.skillLoad),
                  title: "Skill's Load vs Skill's Strain",
                  barColor: Colors.greenAccent,
                ),
                const SizedBox(height: 14),
                _LoadStrainChart(
                  data: _buildSeries((s) => s.totalLoad),
                  title: "Daily Load vs Daily Strain",
                  barColor: Colors.purpleAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: "Session Log",
            child: Column(
              children: List.generate(_sessions.length, (i) {
                final idx = _sessions.length - 1 - i;
                return _SessionTile(
                  session: _sessions[idx],
                  onDelete: () => setState(() => _sessions.removeAt(idx)),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Color _acwrColor(double v) {
    if (v == 0) return Colors.grey;
    if (v < 0.8) return Colors.blueAccent;
    if (v <= 1.3) return Colors.greenAccent;
    if (v <= 1.5) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _acwrLabel(double v) {
    if (v == 0) return "No Data";
    if (v < 0.8) return "Undertraining";
    if (v <= 1.3) return "Sweet Spot";
    if (v <= 1.5) return "Caution";
    return "Danger Zone";
  }
}

// ── Readiness Row ─────────────────────────────────────────────────────────────

class _ReadinessRow extends StatelessWidget {
  final String label;
  final int value;
  final String lowLabel;
  final String highLabel;
  final ValueChanged<int> onChanged;

  const _ReadinessRow({
    required this.label,
    required this.value,
    required this.lowLabel,
    required this.highLabel,
    required this.onChanged,
  });

  Color _color(int v) {
    if (v == 1) return Colors.greenAccent;
    if (v == 2) return Colors.lightGreenAccent;
    if (v == 3) return Colors.yellowAccent;
    if (v == 4) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _color(value).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _color(value).withValues(alpha: 0.6)),
              ),
              child: Text(
                value.toString(),
                style: TextStyle(
                    color: _color(value), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: _color(value),
          onChanged: (v) => onChanged(v.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lowLabel,
                style:
                    const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(highLabel,
                style:
                    const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

// ── RPE Slider (1-10) ─────────────────────────────────────────────────────────

class _RpeSlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _RpeSlider({required this.value, required this.onChanged});

  Color _color(int v) {
    if (v <= 3) return Colors.greenAccent;
    if (v <= 6) return Colors.yellowAccent;
    if (v <= 8) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          label: value.toString(),
          activeColor: _color(value),
          onChanged: (v) => onChanged(v.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("1 Not Intense",
                style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text("RPE $value",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: _color(value))),
            const Text("10 Very Intense",
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

// ── Chip Selector ─────────────────────────────────────────────────────────────

class _ChipSelector<T> extends StatelessWidget {
  final List<T> values;
  final Set<T> selected;
  final String Function(T) label;
  final void Function(T) onToggle;

  const _ChipSelector({
    required this.values,
    required this.selected,
    required this.label,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: values.map((v) {
        final on = selected.contains(v);
        return FilterChip(
          label: Text(
            label(v),
            style: TextStyle(
              fontSize: 12,
              color: on ? Colors.white : _kTextSecondary,
              fontWeight: on ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          selected: on,
          onSelected: (_) => onToggle(v),
          selectedColor: _kAccent,
          backgroundColor: _kBg,
          checkmarkColor: Colors.white,
          side: BorderSide(color: on ? _kAccent : _kBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        );
      }).toList(),
    );
  }
}

// ── Numeric Field ─────────────────────────────────────────────────────────────

class _NumField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;

  const _NumField({required this.ctrl, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(color: _kTextPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kTextSecondary, fontSize: 13),
        filled: true,
        fillColor: _kBg,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kAccent),
        ),
      ),
    );
  }
}

// ── Field Label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 12, color: _kTextSecondary));
  }
}

// ── Readiness Dot ─────────────────────────────────────────────────────────────

class _ReadinessDot extends StatelessWidget {
  final double pct;
  final Color color;

  const _ReadinessDot({required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: pct / 100,
            strokeWidth: 5,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text(
            "${pct.toStringAsFixed(0)}%",
            style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold),
          ),
        ],
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
    final clamped = acwr.clamp(0.0, 2.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 18,
            child: Row(
              children: [
                Expanded(
                    flex: 40,
                    child: Container(
                        color: Colors.blueAccent.withValues(alpha: 0.7))),
                Expanded(
                    flex: 50,
                    child: Container(
                        color: Colors.greenAccent.withValues(alpha: 0.85))),
                Expanded(
                    flex: 10,
                    child: Container(
                        color: Colors.orangeAccent.withValues(alpha: 0.85))),
                Expanded(
                    flex: 100,
                    child: Container(
                        color: Colors.redAccent.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text("0", style: TextStyle(fontSize: 10)),
            Text("0.8", style: TextStyle(fontSize: 10)),
            Text("1.3", style: TextStyle(fontSize: 10)),
            Text("1.5", style: TextStyle(fontSize: 10)),
            Text("2.0+", style: TextStyle(fontSize: 10)),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (context, constraints) {
          final x = (constraints.maxWidth * (clamped / 2.0))
              .clamp(0.0, constraints.maxWidth - 20.0);
          return Stack(
            children: [
              const SizedBox(height: 24),
              Positioned(
                left: x,
                child: Icon(Icons.arrow_drop_down,
                    color:
                        acwr == 0 ? Colors.grey : Colors.white,
                    size: 20),
              ),
            ],
          );
        }),
        const SizedBox(height: 4),
        Text(
          acwr == 0
              ? "Log sessions to see ACWR"
              : "ACWR: ${acwr.toStringAsFixed(2)}",
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            _ZoneLabel("Under-\ntraining", Colors.blueAccent),
            _ZoneLabel("Sweet\nSpot", Colors.greenAccent),
            _ZoneLabel("Caution", Colors.orangeAccent),
            _ZoneLabel("Danger", Colors.redAccent),
          ],
        ),
      ],
    );
  }
}

class _ZoneLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _ZoneLabel(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: color));
  }
}

// ── Bar Chart ─────────────────────────────────────────────────────────────────

class _LoadBarChart extends StatelessWidget {
  final List<TrainingSession> sessions;
  const _LoadBarChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final recent = sessions.length > 14
        ? sessions.sublist(sessions.length - 14)
        : sessions;
    final maxLoad = recent.map((s) => s.totalLoad).reduce(max);

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: recent.map((s) {
          final frac = maxLoad > 0 ? s.totalLoad / maxLoad : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(s.totalLoad.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 7)),
                  const SizedBox(height: 2),
                  Container(
                    height: 90 * frac + 4,
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text("${s.date.day}/${s.date.month}",
                      style: const TextStyle(fontSize: 7)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Session Tile ──────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final TrainingSession session;
  final VoidCallback onDelete;

  const _SessionTile(
      {required this.session, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final d = session.date;
    final primary = session.primaryTypes.map((t) => t.label).join(', ');
    final skill = session.skillTypes.isNotEmpty
        ? session.skillTypes.map((t) => t.label).join(', ')
        : null;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: session.readinessColor.withValues(alpha: 0.25),
        radius: 20,
        child: Text(
          "${session.readinessPercent.toStringAsFixed(0)}%",
          style: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        "${d.day}/${d.month}/${d.year}  •  Load: ${session.totalLoad.toStringAsFixed(0)}",
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        skill != null ? "$primary  |  $skill" : primary,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 18),
        onPressed: onDelete,
      ),
    );
  }
}

// ── Metric Tile ───────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final String value;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: _kTextSecondary)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(fontSize: 10, color: _kTextSecondary)),
        ],
      ),
    );
  }
}

// ── ACWR Trend Chart ──────────────────────────────────────────────────────────

class _AcwrTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String title;
  final Color lineColor;

  const _AcwrTrendChart(
      {required this.data, required this.title, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(title,
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SizedBox(
          height: 160,
          child: CustomPaint(
            painter: _DualLinePainter(
              ewmaValues:
                  data.map((d) => (d['ewma'] as double)).toList(),
              acwrValues:
                  data.map((d) => (d['acwr'] as double)).toList(),
              dates: data.map((d) => (d['date'] as DateTime)).toList(),
              lineColor: lineColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _DualLinePainter extends CustomPainter {
  final List<double> ewmaValues;
  final List<double> acwrValues;
  final List<DateTime> dates;
  final Color lineColor;

  _DualLinePainter({
    required this.ewmaValues,
    required this.acwrValues,
    required this.dates,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (ewmaValues.isEmpty) return;
    final n = ewmaValues.length;
    const bPad = 22.0;
    const tPad = 14.0;
    final chartH = size.height - bPad - tPad;
    final xStep = n > 1 ? size.width / (n - 1) : 0.0;
    double xAt(int i) => n == 1 ? size.width / 2 : i * xStep;

    double normY(double v, double mn, double mx) {
      if (mx == mn) return tPad + chartH / 2;
      return tPad + chartH * (1 - (v - mn) / (mx - mn));
    }

    final ewmaMin = ewmaValues.reduce(min);
    final ewmaMax = ewmaValues.reduce(max);
    final acwrMin = acwrValues.reduce(min);
    final acwrMax = acwrValues.reduce(max);

    // Green solid line — EWMA
    final greenPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final greenPath = Path();
    for (int i = 0; i < n; i++) {
      final p = Offset(xAt(i), normY(ewmaValues[i], ewmaMin, ewmaMax));
      i == 0 ? greenPath.moveTo(p.dx, p.dy) : greenPath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(greenPath, greenPaint);

    final dotPaint = Paint()..color = lineColor;
    for (int i = 0; i < n; i++) {
      final p = Offset(xAt(i), normY(ewmaValues[i], ewmaMin, ewmaMax));
      canvas.drawCircle(p, 4, dotPaint);
      // Label shows ACWR value, not raw EWMA
      _text(canvas, "ACWR:${acwrValues[i].toStringAsFixed(2)}", p.dx, p.dy - 13,
          lineColor, 7.5);
    }

    // Orange dashed line — ACWR
    final oPaint = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < n - 1; i++) {
      _dash(
        canvas,
        oPaint,
        Offset(xAt(i), normY(acwrValues[i], acwrMin, acwrMax)),
        Offset(xAt(i + 1), normY(acwrValues[i + 1], acwrMin, acwrMax)),
      );
    }
    final oDot = Paint()..color = Colors.orangeAccent;
    for (int i = 0; i < n; i++) {
      final p = Offset(xAt(i), normY(acwrValues[i], acwrMin, acwrMax));
      canvas.drawCircle(p, 3, oDot);
    }

    // Date x-axis labels
    for (int i = 0; i < n; i++) {
      final d = dates[i];
      _text(canvas, "${d.day}/${d.month}", xAt(i),
          size.height - bPad + 5, Colors.grey, 7);
    }
  }

  void _dash(Canvas c, Paint p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    const dl = 4.0, gl = 3.0;
    final nx = dx / dist, ny = dy / dist;
    double t = 0;
    while (t < dist) {
      final e = (t + dl).clamp(0.0, dist);
      c.drawLine(Offset(a.dx + nx * t, a.dy + ny * t),
          Offset(a.dx + nx * e, a.dy + ny * e), p);
      t += dl + gl;
    }
  }

  void _text(Canvas c, String s, double cx, double cy, Color col,
      double fs) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(cx - tp.width / 2, cy));
  }

  @override
  bool shouldRepaint(covariant _DualLinePainter old) =>
      old.ewmaValues != ewmaValues || old.acwrValues != acwrValues;
}

// ── Load vs Strain Chart ──────────────────────────────────────────────────────

class _LoadStrainChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String title;
  final Color barColor;

  const _LoadStrainChart(
      {required this.data, required this.title, required this.barColor});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(title,
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SizedBox(
          height: 160,
          child: CustomPaint(
            painter: _BarLinePainter(
              barValues:
                  data.map((d) => (d['load'] as double)).toList(),
              lineValues:
                  data.map((d) => (d['strain'] as double)).toList(),
              dates: data.map((d) => (d['date'] as DateTime)).toList(),
              barColor: barColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _BarLinePainter extends CustomPainter {
  final List<double> barValues;
  final List<double> lineValues;
  final List<DateTime> dates;
  final Color barColor;

  _BarLinePainter({
    required this.barValues,
    required this.lineValues,
    required this.dates,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (barValues.isEmpty) return;
    final n = barValues.length;
    const bPad = 22.0;
    const tPad = 14.0;
    final chartH = size.height - bPad - tPad;
    final slotW = size.width / n;
    // Cap bar width so single-session doesn't fill entire chart
    final barW = min(slotW * 0.6, 44.0);

    final maxBar =
        barValues.fold(0.0, (p, v) => v > p ? v : p).clamp(1.0, 1e9);
    final maxLine = lineValues.fold(0.0, (p, v) => v > p ? v : p);
    final minLine = lineValues.fold(maxLine, (p, v) => v < p ? v : p);

    // Chart background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, tPad, size.width, chartH),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.04),
    );

    // Bars — max 82% height so there's always headroom
    final barPaint = Paint()..color = barColor.withValues(alpha: 0.75);
    for (int i = 0; i < n; i++) {
      final x = i * slotW + (slotW - barW) / 2;
      final bh = (barValues[i] / maxBar) * chartH * 0.82;
      final rect =
          Rect.fromLTWH(x, size.height - bPad - bh, barW, bh);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          barPaint);
      _text(canvas, barValues[i].toStringAsFixed(0),
          i * slotW + slotW / 2, size.height - bPad - bh - 11,
          Colors.white70, 7);
    }

    // White line — Strain
    double lineY(double v) {
      if (maxLine == minLine) return tPad + chartH / 2;
      return tPad + chartH * (1 - (v - minLine) / (maxLine - minLine));
    }

    final lp = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < n; i++) {
      final x = i * slotW + slotW / 2;
      final y = lineY(lineValues[i]);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, lp);

    final dotP = Paint()..color = Colors.white;
    for (int i = 0; i < n; i++) {
      final x = i * slotW + slotW / 2;
      final y = lineY(lineValues[i]);
      canvas.drawCircle(Offset(x, y), 3, dotP);
      _text(canvas, lineValues[i].toStringAsFixed(2), x, y - 12,
          Colors.white, 7);
    }

    // Date labels
    for (int i = 0; i < n; i++) {
      final d = dates[i];
      _text(canvas, "${d.day}/${d.month}", i * slotW + slotW / 2,
          size.height - bPad + 5, Colors.grey, 7);
    }
  }

  void _text(Canvas c, String s, double cx, double cy, Color col,
      double fs) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(cx - tp.width / 2, cy));
  }

  @override
  bool shouldRepaint(covariant _BarLinePainter old) =>
      old.barValues != barValues || old.lineValues != lineValues;
}

// ── Readiness Trend Chart ─────────────────────────────────────────────────────

class _ReadinessTrendChart extends StatelessWidget {
  final List<TrainingSession> sessions;
  const _ReadinessTrendChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: Text("No sessions yet",
              style: TextStyle(color: Colors.grey, fontSize: 11)),
        ),
      );
    }
    final sorted = List<TrainingSession>.from(sessions)
      ..sort((a, b) => a.date.compareTo(b.date));
    return SizedBox(
      height: 140,
      child: CustomPaint(
        painter: _ReadinessPainter(sessions: sorted),
      ),
    );
  }
}

class _ReadinessPainter extends CustomPainter {
  final List<TrainingSession> sessions;
  _ReadinessPainter({required this.sessions});

  @override
  void paint(Canvas canvas, Size size) {
    if (sessions.isEmpty) return;
    final n = sessions.length;
    const bPad = 22.0;
    const tPad = 10.0;
    final chartH = size.height - bPad - tPad;
    final xStep = n > 1 ? size.width / (n - 1) : 0.0;
    double xAt(int i) => n == 1 ? size.width / 2 : i * xStep;

    // Chart background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, tPad, size.width, chartH),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.04),
    );

    // 75% reference line (green zone threshold)
    final refY = tPad + chartH * (1 - 0.75);
    canvas.drawLine(
      Offset(0, refY),
      Offset(size.width, refY),
      Paint()
        ..color = Colors.greenAccent.withValues(alpha: 0.3)
        ..strokeWidth = 1,
    );
    _text(canvas, "75%", 16, refY - 9, Colors.greenAccent.withValues(alpha: 0.6), 7);

    // Line
    final linePaint = Paint()
      ..color = Colors.yellowAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < n; i++) {
      final pct = sessions[i].readinessPercent;
      final x = xAt(i);
      final y = tPad + chartH * (1 - pct / 100);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, linePaint);

    // Fill under line
    final fillPath = Path()..addPath(path, Offset.zero);
    fillPath.lineTo(xAt(n - 1), size.height - bPad);
    fillPath.lineTo(xAt(0), size.height - bPad);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()..color = Colors.yellowAccent.withValues(alpha: 0.08),
    );

    // Dots + labels
    for (int i = 0; i < n; i++) {
      final pct = sessions[i].readinessPercent;
      final x = xAt(i);
      final y = tPad + chartH * (1 - pct / 100);
      final col = sessions[i].readinessColor;
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = col);
      _text(canvas, "${pct.toStringAsFixed(0)}%", x, y - 12,
          col, 7.5);
      final d = sessions[i].date;
      _text(canvas, "${d.day}/${d.month}", x,
          size.height - bPad + 5, Colors.grey, 7);
    }
  }

  void _text(Canvas c, String s, double cx, double cy, Color col, double fs) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(cx - tp.width / 2, cy));
  }

  @override
  bool shouldRepaint(covariant _ReadinessPainter old) =>
      old.sessions != sessions;
}

// ── Section Card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard(
      {required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kTextPrimary,
              letterSpacing: 0.1,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                subtitle!,
                style: const TextStyle(fontSize: 11, color: _kTextSecondary),
              ),
            ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
