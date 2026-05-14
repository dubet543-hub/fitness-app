import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'core/theme.dart';
import 'screens/workload_monitor_screen.dart';

// Aliases so the rest of the file compiles without change.
const Color _kBg            = kBg;
const Color _kSurface       = kSurface;
const Color _kCard          = kCard;
const Color _kAccent        = kAccent;
const Color _kBorder        = kBorder;
const Color _kTextPrimary   = kTextPrimary;
const Color _kTextSecondary = kTextSecondary;

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

// ── Data Models ───────────────────────────────────────────────────────────────

class WellnessLog {
  final String? id;
  final DateTime date;
  final int sleep, wellness, soreness, fatigue;

  const WellnessLog({
    this.id,
    required this.date,
    required this.sleep,
    required this.wellness,
    required this.soreness,
    required this.fatigue,
  });

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

class TrainingLog {
  final String? id;
  final DateTime timestamp;
  final String? sessionType; // "Match day", "Strength Program", etc.
  final Set<PrimarySessionType> primaryTypes;
  final int primaryDuration;
  final int primaryRpe;
  final Set<SecondarySessionType> subTypes;
  final int? subDuration;
  final int? subRpe;
  final int? distance;
  final int? sprints;
  final int? maxHR;
  final int? avgHR;
  final double? zScore;
  final double? standardDeviation;

  TrainingLog({
    this.id,
    required this.timestamp,
    this.sessionType,
    required this.primaryTypes,
    required this.primaryDuration,
    required this.primaryRpe,
    Set<SecondarySessionType>? subTypes,
    this.subDuration,
    this.subRpe,
    this.distance,
    this.sprints,
    this.maxHR,
    this.avgHR,
    this.zScore,
    this.standardDeviation,
  }) : subTypes = subTypes ?? {};

  double get primaryLoad => (primaryRpe * primaryDuration).toDouble();
  double get subLoad =>
      (subDuration != null && subRpe != null) ? (subRpe! * subDuration!).toDouble() : 0;
  double get totalLoad => primaryLoad + subLoad;
}

class SkillLog {
  final String? id;
  final DateTime timestamp;
  final Set<SkillSessionType> types;
  final int duration;
  final int rpe;
  final Set<SkillSessionType> subTypes;
  final int? subDuration;
  final int? subRpe;
  final int? ballsBowled;
  final int? subBallsBowled;
  final int? maxHR;
  final int? avgHR;

  SkillLog({
    this.id,
    required this.timestamp,
    required this.types,
    required this.duration,
    required this.rpe,
    Set<SkillSessionType>? subTypes,
    this.subDuration,
    this.subRpe,
    this.ballsBowled,
    this.subBallsBowled,
    this.maxHR,
    this.avgHR,
  }) : subTypes = subTypes ?? {};

  double get mainLoad => (rpe * duration).toDouble();
  double get subLoad =>
      (subDuration != null && subRpe != null) ? (subRpe! * subDuration!).toDouble() : 0;
  double get totalLoad => mainLoad + subLoad;
}

// Aggregates one day's worth of entries for analytics.
class DailyRecord {
  final DateTime date;
  final WellnessLog? wellness;
  final List<TrainingLog> training;
  final List<SkillLog> skills;

  const DailyRecord({
    required this.date,
    required this.wellness,
    required this.training,
    required this.skills,
  });

  double get trainingLoad => training.fold(0.0, (s, t) => s + t.totalLoad);
  double get skillLoad    => skills.fold(0.0, (s, k) => s + k.totalLoad);
  double get totalLoad    => trainingLoad + skillLoad;

  double get readinessPercent => wellness?.readinessPercent ?? 0;
  Color  get readinessColor   => wellness?.readinessColor   ?? Colors.grey;

  double get scaledGrade {
    if (totalLoad <= 0) return 0;
    return (log(totalLoad) / log(1000)) * 10;
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

  final List<WellnessLog> _wellnessLogs = [];
  final List<TrainingLog> _trainingLogs = [];
  final List<SkillLog>    _skillLogs    = [];

  late final TabController _tabController;

  // ── Wellness form ──────────────────────────────────────────────────────────
  int _wSleep = 1, _wWellness = 1, _wSoreness = 1, _wFatigue = 1;

  // ── Training form ──────────────────────────────────────────────────────────
  bool _showTrainingForm = false;
  final Set<PrimarySessionType>   _tPrimaryTypes = {};
  final _tPrimaryDurCtrl = TextEditingController();
  int  _tPrimaryRpe = 5;
  String? _tSessionType; // "Match day", "Strength Program", etc.
  bool _tHasSub     = false;
  final Set<SecondarySessionType> _tSubTypes = {};
  final _tSubDurCtrl     = TextEditingController();
  int  _tSubRpe          = 5;
  final _tDistCtrl       = TextEditingController();
  final _tSprintsCtrl    = TextEditingController();
  final _tMaxHRCtrl      = TextEditingController();
  final _tAvgHRCtrl      = TextEditingController();

  // ── Skill form ─────────────────────────────────────────────────────────────
  bool _showSkillForm = false;
  final Set<SkillSessionType> _sTypes    = {};
  final _sDurCtrl        = TextEditingController();
  int  _sRpe             = 5;
  bool _sHasSub          = false;
  final Set<SkillSessionType> _sSubTypes = {};
  final _sSubDurCtrl     = TextEditingController();
  int  _sSubRpe          = 5;
  final _sBallsCtrl      = TextEditingController();
  final _sSubBallsCtrl   = TextEditingController();
  final _sMaxHRCtrl      = TextEditingController();
  final _sAvgHRCtrl      = TextEditingController();

  bool _loadingSessions = true;
  String? _sessionError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSessions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in [
      _tPrimaryDurCtrl, _tSubDurCtrl, _tDistCtrl, _tSprintsCtrl, _tMaxHRCtrl, _tAvgHRCtrl,
      _sDurCtrl, _sSubDurCtrl, _sBallsCtrl, _sSubBallsCtrl, _sMaxHRCtrl, _sAvgHRCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadSessions() async {
    if (!mounted) return;
    setState(() {
      _loadingSessions = true;
      _sessionError = null;
    });
    try {
      final sessions = await ApiService.fetchSessions(limit: 500);
      if (!mounted) return;
      final wellness = <WellnessLog>[];
      final training = <TrainingLog>[];
      final skill = <SkillLog>[];

      for (final raw in sessions) {
        final session = _sessionFromJson(raw);
        if (session is WellnessLog) {
          wellness.add(session);
        } else if (session is TrainingLog) {
          training.add(session);
        } else if (session is SkillLog) {
          skill.add(session);
        }
      }

      wellness.sort((a, b) => a.date.compareTo(b.date));
      training.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      skill.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      setState(() {
        _wellnessLogs
          ..clear()
          ..addAll(wellness);
        _trainingLogs
          ..clear()
          ..addAll(training);
        _skillLogs
          ..clear()
          ..addAll(skill);
        _loadingSessions = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loadingSessions = false;
        _sessionError = err.toString();
      });
    }
  }

  dynamic _sessionFromJson(Map<String, dynamic> raw) {
    final id = raw['_id']?.toString();
    final date = DateTime.tryParse(raw['date']?.toString() ?? '') ?? DateTime.now();
    final hasWellness = [raw['sleep'], raw['wellness'], raw['soreness'], raw['fatigue']].any((v) => v != null);
    final hasTraining = [raw['primaryTypes'], raw['primaryDuration'], raw['primaryRpe']].any((v) => v != null);
    final hasSkill = [raw['skillTypes'], raw['skillDuration'], raw['skillRpe']].any((v) => v != null);

    if (hasWellness && !hasTraining && !hasSkill) {
      return WellnessLog(
        id: id,
        date: date,
        sleep: _intValue(raw['sleep'], fallback: 3),
        wellness: _intValue(raw['wellness'], fallback: 3),
        soreness: _intValue(raw['soreness'], fallback: 3),
        fatigue: _intValue(raw['fatigue'], fallback: 3),
      );
    }

    if (hasSkill) {
      return SkillLog(
        id: id,
        timestamp: date,
        types: _skillTypes(raw['skillTypes']),
        duration: _intValue(raw['skillDuration']),
        rpe: _intValue(raw['skillRpe'], fallback: 5),
        subTypes: _skillTypes(raw['skillSubTypes']),
        subDuration: _maybeInt(raw['skillSubDuration']),
        subRpe: _maybeInt(raw['skillSubRpe']),
        ballsBowled: _maybeInt(raw['ballsBowled']),
        subBallsBowled: _maybeInt(raw['subBallsBowled']),
        maxHR: _maybeInt(raw['skillMaxHR']),
        avgHR: _maybeInt(raw['skillAvgHR']),
      );
    }

    return TrainingLog(
      id: id,
      timestamp: date,
      primaryTypes: _primaryTypes(raw['primaryTypes']),
      primaryDuration: _intValue(raw['primaryDuration']),
      primaryRpe: _intValue(raw['primaryRpe'], fallback: 5),
      subTypes: _secondaryTypes(raw['secondaryTypes']),
      subDuration: _maybeInt(raw['secondaryDuration']),
      subRpe: _maybeInt(raw['secondaryRpe']),
      distance: _maybeInt(raw['distance']),
      sprints: _maybeInt(raw['sprints']),
      maxHR: _maybeInt(raw['maxHR']),
      avgHR: _maybeInt(raw['avgHR']),
    );
  }

  int _intValue(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  int? _maybeInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Set<PrimarySessionType> _primaryTypes(dynamic value) {
    final items = _stringList(value);
    return items.map((name) => PrimarySessionType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => PrimarySessionType.strength,
    )).toSet();
  }

  Set<SecondarySessionType> _secondaryTypes(dynamic value) {
    final items = _stringList(value);
    return items.map((name) => SecondarySessionType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => SecondarySessionType.core,
    )).toSet();
  }

  Set<SkillSessionType> _skillTypes(dynamic value) {
    final items = _stringList(value);
    return items.map((name) => SkillSessionType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => SkillSessionType.rest,
    )).toSet();
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  bool get _todayWellnessLogged {
    final key = _dateKey(DateTime.now());
    return _wellnessLogs.any((w) => _dateKey(w.date) == key);
  }

  WellnessLog? get _todayWellness {
    final key = _dateKey(DateTime.now());
    try { return _wellnessLogs.lastWhere((w) => _dateKey(w.date) == key); }
    catch (_) { return null; }
  }

  List<TrainingLog> get _todayTraining {
    final key = _dateKey(DateTime.now());
    return _trainingLogs.where((t) => _dateKey(t.timestamp) == key).toList();
  }

  List<SkillLog> get _todaySkills {
    final key = _dateKey(DateTime.now());
    return _skillLogs.where((s) => _dateKey(s.timestamp) == key).toList();
  }

  List<DailyRecord> _buildDailyRecords() {
    final keys = <String>{
      for (final w in _wellnessLogs) _dateKey(w.date),
      for (final t in _trainingLogs) _dateKey(t.timestamp),
      for (final s in _skillLogs)    _dateKey(s.timestamp),
    };
    return keys.map((key) {
      final p = key.split('-');
      final date = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      WellnessLog? well;
      try { well = _wellnessLogs.lastWhere((w) => _dateKey(w.date) == key); }
      catch (_) {}
      return DailyRecord(
        date:     date,
        wellness: well,
        training: _trainingLogs.where((t) => _dateKey(t.timestamp) == key).toList(),
        skills:   _skillLogs.where((s) => _dateKey(s.timestamp) == key).toList(),
      );
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  // ── Analytics ─────────────────────────────────────────────────────────────

  double get _acuteLoad {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _buildDailyRecords()
        .where((r) => r.date.isAfter(cutoff))
        .fold(0.0, (s, r) => s + r.totalLoad);
  }

  double get _chronicLoad {
    final records = _buildDailyRecords();
    if (records.isEmpty) return 0;
    const lambda = 2.0 / 29.0;
    double ewma = records.first.totalLoad;
    for (int i = 1; i < records.length; i++) {
      ewma = (records[i].totalLoad * lambda) + (ewma * (1 - lambda));
    }
    return ewma;
  }

  double get _acwr {
    final c = _chronicLoad;
    return c == 0 ? 0 : _acuteLoad / c;
  }

  double get _zScore {
    final records = _buildDailyRecords();
    if (records.length < 2) return 0;
    final loads = records.map((r) => r.totalLoad).toList();
    final mean  = loads.reduce((a, b) => a + b) / loads.length;
    final sigma = sqrt(loads.map((l) => pow(l - mean, 2)).reduce((a, b) => a + b) / loads.length);
    if (sigma == 0) return 0;
    return (records.last.totalLoad - mean) / sigma;
  }

  List<Map<String, dynamic>> _buildSeries(double Function(DailyRecord) fn) {
    final records = _buildDailyRecords();
    if (records.isEmpty) return [];
    const lambda = 2.0 / 29.0;
    double ewma = 0;
    return List.generate(records.length, (i) {
      final load = fn(records[i]);
      ewma = i == 0 ? load : (load * lambda) + (ewma * (1 - lambda));
      final cutoff = records[i].date.subtract(const Duration(days: 7));
      final acute  = records.sublist(0, i + 1)
          .where((r) => r.date.isAfter(cutoff))
          .fold(0.0, (s, r) => s + fn(r));
      return {
        'date':   records[i].date,
        'load':   load,
        'ewma':   ewma,
        'acwr':   ewma == 0 ? 0.0 : acute / ewma,
        'strain': load <= 0 ? 0.0 : (log(load) / log(1000)) * 10,
      };
    });
  }

  // ── Submit: Wellness ──────────────────────────────────────────────────────

  Future<void> _submitWellness() async {
    final now = DateTime.now();
    try {
      await ApiService.submitSession({
        'date': now.toIso8601String(),
        'sleep': _wSleep,
        'wellness': _wWellness,
        'soreness': _wSoreness,
        'fatigue': _wFatigue,
      });
      await _loadSessions();
      _snack("Morning wellness logged!");
    } catch (err) {
      _snack("Failed to save wellness: $err");
    }
  }

  Future<void> _resetWellnessForm() async {
    final current = _todayWellness;
    if (current?.id != null) {
      try {
        await ApiService.deleteSession(current!.id!);
      } catch (_) {}
    }
    await _loadSessions();
  }

  // ── Submit: Training ──────────────────────────────────────────────────────

  Future<void> _submitTraining() async {
    if (_tPrimaryTypes.isEmpty) { _snack("Select at least one session type"); return; }
    final dur = int.tryParse(_tPrimaryDurCtrl.text.trim()) ?? 0;
    if (dur <= 0) { _snack("Enter a valid duration"); return; }
    if (_tHasSub && (int.tryParse(_tSubDurCtrl.text.trim()) ?? 0) <= 0) {
      _snack("Enter subordinate session duration"); return;
    }

    final capturedPrimaryTypes = Set<PrimarySessionType>.from(_tPrimaryTypes);
    final capturedSubTypes = Set<SecondarySessionType>.from(_tSubTypes);
    final capturedPrimaryRpe = _tPrimaryRpe;
    final capturedSubRpe = _tHasSub ? _tSubRpe : null;
    final now = DateTime.now();

    try {
      await ApiService.submitSession({
        'date': now.toIso8601String(),
        'sessionType': _tSessionType,
        'primaryTypes': capturedPrimaryTypes.map((e) => e.name).toList(),
        'primaryDuration': dur,
        'primaryRpe': capturedPrimaryRpe,
        'hasSecondary': _tHasSub,
        'secondaryTypes': _tHasSub ? capturedSubTypes.map((e) => e.name).toList() : [],
        'secondaryDuration': _tHasSub ? int.tryParse(_tSubDurCtrl.text.trim()) : null,
        'secondaryRpe': capturedSubRpe,
        'distance': int.tryParse(_tDistCtrl.text.trim()),
        'sprints': int.tryParse(_tSprintsCtrl.text.trim()),
        'maxHR': int.tryParse(_tMaxHRCtrl.text.trim()),
        'avgHR': int.tryParse(_tAvgHRCtrl.text.trim()),
      });
      _clearTrainingForm();
      setState(() => _showTrainingForm = false);
      await _loadSessions();
      _snack("Training session logged!");
    } catch (err) {
      _snack("Failed to save training session: $err");
    }
  }

  // ── Submit: Skill ─────────────────────────────────────────────────────────

  Future<void> _submitSkill() async {
    if (_sTypes.isEmpty) { _snack("Select at least one skill type"); return; }
    final dur = int.tryParse(_sDurCtrl.text.trim()) ?? 0;
    if (dur <= 0) { _snack("Enter a valid duration"); return; }
    if (_sHasSub && (int.tryParse(_sSubDurCtrl.text.trim()) ?? 0) <= 0) {
      _snack("Enter subordinate skill session duration"); return;
    }

    final capturedTypes = Set<SkillSessionType>.from(_sTypes);
    final capturedSubTypes = Set<SkillSessionType>.from(_sSubTypes);
    final capturedRpe = _sRpe;
    final capturedSubRpe = _sHasSub ? _sSubRpe : null;
    final now = DateTime.now();

    try {
      await ApiService.submitSession({
        'date': now.toIso8601String(),
        'hasSkill': true,
        'skillTypes': capturedTypes.map((e) => e.name).toList(),
        'skillDuration': dur,
        'skillRpe': capturedRpe,
        'skillSubTypes': _sHasSub ? capturedSubTypes.map((e) => e.name).toList() : [],
        'skillSubDuration': _sHasSub ? int.tryParse(_sSubDurCtrl.text.trim()) : null,
        'skillSubRpe': capturedSubRpe,
        'ballsBowled': capturedTypes.contains(SkillSessionType.bowling) ? int.tryParse(_sBallsCtrl.text.trim()) : null,
        'subBallsBowled': _sHasSub && capturedSubTypes.contains(SkillSessionType.bowling)
            ? int.tryParse(_sSubBallsCtrl.text.trim())
            : null,
        'skillMaxHR': int.tryParse(_sMaxHRCtrl.text.trim()),
        'skillAvgHR': int.tryParse(_sAvgHRCtrl.text.trim()),
      });
      _clearSkillForm();
      setState(() => _showSkillForm = false);
      await _loadSessions();
      _snack("Skill session logged!");
    } catch (err) {
      _snack("Failed to save skill session: $err");
    }
  }

  // ── Clear forms ───────────────────────────────────────────────────────────

  void _clearTrainingForm() {
    _tPrimaryTypes.clear();
    _tPrimaryDurCtrl.clear();
    _tPrimaryRpe = 5;
    _tSessionType = null;
    _tHasSub = false;
    _tSubTypes.clear();
    _tSubDurCtrl.clear();
    _tSubRpe = 5;
    _tDistCtrl.clear();
    _tSprintsCtrl.clear();
    _tMaxHRCtrl.clear();
    _tAvgHRCtrl.clear();
  }

  void _clearSkillForm() {
    _sTypes.clear();
    _sDurCtrl.clear();
    _sRpe = 5;
    _sHasSub = false;
    _sSubTypes.clear();
    _sSubDurCtrl.clear();
    _sSubRpe = 5;
    _sBallsCtrl.clear();
    _sSubBallsCtrl.clear();
    _sMaxHRCtrl.clear();
    _sAvgHRCtrl.clear();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        title: const Text("Training Load",
            style: TextStyle(color: _kTextPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: _kTextPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(children: [
            const Divider(height: 1, color: _kBorder),
            TabBar(
              controller: _tabController,
              labelColor: _kAccent,
              unselectedLabelColor: _kTextSecondary,
              indicatorColor: _kAccent,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(icon: Icon(Icons.edit_note_rounded),  text: "Log"),
                Tab(icon: Icon(Icons.dashboard_rounded),  text: "Dashboard"),
              ],
            ),
          ]),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loadingSessions) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
          ],
          if (_sessionError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
              ),
              child: Text(
                'Failed to sync sessions: $_sessionError',
                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildWellnessSection(),
          const SizedBox(height: 14),
          _buildTrainingSessions(),
          const SizedBox(height: 14),
          _buildSkillSessions(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Wellness section ──────────────────────────────────────────────────────

  Widget _buildWellnessSection() {
    if (_todayWellnessLogged) {
      final w = _todayWellness!;
      return _SectionCard(
        title: "Morning Wellness",
        subtitle: "Logged today",
        child: Row(
          children: [
            _ReadinessDot(pct: w.readinessPercent, color: w.readinessColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${w.readinessPercent.toStringAsFixed(0)}% Ready",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: w.readinessColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Sleep ${w.sleep}  ·  Wellness ${w.wellness}  ·  Soreness ${w.soreness}  ·  Fatigue ${w.fatigue}",
                    style: const TextStyle(fontSize: 11, color: _kTextSecondary),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _resetWellnessForm,
                    child: const Text("Re-log",
                        style: TextStyle(fontSize: 12, color: _kAccent, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 24),
          ],
        ),
      );
    }

    return _SectionCard(
      title: "Morning Wellness",
      subtitle: "Log once upon waking up",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReadinessRow(label: "Sleep Score",    value: _wSleep,    lowLabel: "Excellent",   highLabel: "Poor",        onChanged: (v) => setState(() => _wSleep    = v)),
          const SizedBox(height: 10),
          _ReadinessRow(label: "Wellness Score", value: _wWellness, lowLabel: "Excellent",   highLabel: "Poor",        onChanged: (v) => setState(() => _wWellness = v)),
          const SizedBox(height: 10),
          _ReadinessRow(label: "Soreness Score", value: _wSoreness, lowLabel: "No Soreness", highLabel: "Very Severe", onChanged: (v) => setState(() => _wSoreness = v)),
          const SizedBox(height: 10),
          _ReadinessRow(label: "Fatigue Score",  value: _wFatigue,  lowLabel: "Fully Fresh", highLabel: "Exhausted",   onChanged: (v) => setState(() => _wFatigue  = v)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _submitWellness,
            icon: const Icon(Icons.wb_sunny_rounded, size: 18),
            label: const Text("Log Morning Wellness"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Training sessions section ─────────────────────────────────────────────

  Widget _buildTrainingSessions() {
    final today = _todayTraining;
    return _SectionCard(
      title: "Training Sessions",
      subtitle: "Log each session after completing it (30-min rule)",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < today.length; i++) ...[
            _TrainingLogTile(
              log: today[i],
              index: i + 1,
              onDelete: () async {
                final id = today[i].id;
                if (id != null) {
                  try { await ApiService.deleteSession(id); } catch (_) {}
                }
                await _loadSessions();
              },
            ),
            if (i < today.length - 1) const SizedBox(height: 8),
          ],
          if (today.isNotEmpty) const SizedBox(height: 12),
          if (_showTrainingForm) ...[
            _buildTrainingForm(),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _showTrainingForm = !_showTrainingForm;
              if (!_showTrainingForm) _clearTrainingForm();
            }),
            icon: Icon(_showTrainingForm ? Icons.close_rounded : Icons.add_rounded, size: 18),
            label: Text(_showTrainingForm ? "Cancel" : "+ Add Training Session"),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kAccent,
              side: BorderSide(color: _showTrainingForm ? _kBorder : _kAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingForm() {
    final showExtra = _tPrimaryTypes.contains(PrimarySessionType.endurance) ||
        _tPrimaryTypes.contains(PrimarySessionType.hiit);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel("Session Type (Primary)"),
          const SizedBox(height: 8),
          _ChipSelector<PrimarySessionType>(
            values: PrimarySessionType.values,
            selected: _tPrimaryTypes,
            label: (v) => v.label,
            onToggle: (v) => setState(() =>
                _tPrimaryTypes.contains(v) ? _tPrimaryTypes.remove(v) : _tPrimaryTypes.add(v)),
          ),
          const SizedBox(height: 14),
          _NumField(ctrl: _tPrimaryDurCtrl, label: "Duration (minutes)"),
          const SizedBox(height: 14),
          const _FieldLabel("RPE — Primary Session"),
          _RpeSlider(value: _tPrimaryRpe, onChanged: (v) => setState(() => _tPrimaryRpe = v)),
          const SizedBox(height: 14),
          const _FieldLabel("Session Category"),
          DropdownButton<String>(
            value: _tSessionType,
            isExpanded: true,
            hint: const Text("Select session category", style: TextStyle(color: _kTextSecondary)),
            items: [
              'Match day',
              'Strength Program',
              'Power Program',
              'Endurance Program',
              'HIIT',
              'Corrective Prehab Program',
              'Core Program',
              'Rest day'
            ].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() => _tSessionType = newValue);
            },
            style: const TextStyle(color: _kTextPrimary, fontSize: 14),
            dropdownColor: _kSurface,
            underline: Container(height: 1, color: _kBorder),
          ),
          if (showExtra) ...[
            const SizedBox(height: 14),
            _NumField(ctrl: _tDistCtrl,    label: "Distance (metres) — Endurance / HIIT"),
            const SizedBox(height: 10),
            _NumField(ctrl: _tSprintsCtrl, label: "Total sprints (High Intensity Running)"),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _NumField(ctrl: _tMaxHRCtrl, label: "Max HR")),
            const SizedBox(width: 10),
            Expanded(child: _NumField(ctrl: _tAvgHRCtrl, label: "Avg HR")),
          ]),

          // Subordinate session
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _tHasSub ? _kAccent.withValues(alpha: 0.45) : _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // FIX: Wrapped Column in Expanded to prevent Row overflow
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Subordinate Session",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextPrimary)),
                          Text("Corrective prehab or core work",
                              style: TextStyle(fontSize: 11, color: _kTextSecondary)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _tHasSub,
                      activeThumbColor: _kAccent,
                      activeTrackColor: _kAccent.withValues(alpha: 0.25),
                      onChanged: (v) => setState(() => _tHasSub = v),
                    ),
                  ],
                ),
                if (_tHasSub) ...[
                  const SizedBox(height: 12),
                  const _FieldLabel("Type (Subordinate)"),
                  const SizedBox(height: 8),
                  _ChipSelector<SecondarySessionType>(
                    values: SecondarySessionType.values,
                    selected: _tSubTypes,
                    label: (v) => v.label,
                    onToggle: (v) => setState(() =>
                        _tSubTypes.contains(v) ? _tSubTypes.remove(v) : _tSubTypes.add(v)),
                  ),
                  const SizedBox(height: 12),
                  _NumField(ctrl: _tSubDurCtrl, label: "Duration (minutes)"),
                  const SizedBox(height: 12),
                  const _FieldLabel("RPE — Subordinate Session"),
                  _RpeSlider(value: _tSubRpe, onChanged: (v) => setState(() => _tSubRpe = v)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _submitTraining,
            icon: const Icon(Icons.fitness_center_rounded, size: 18),
            label: const Text("Log Training Session"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Skill sessions section ────────────────────────────────────────────────

  Widget _buildSkillSessions() {
    final today = _todaySkills;
    return _SectionCard(
      title: "Skill Sessions",
      subtitle: "Log each skill session after completing it",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < today.length; i++) ...[
            _SkillLogTile(
              log: today[i],
              index: i + 1,
              onDelete: () async {
                final id = today[i].id;
                if (id != null) {
                  try { await ApiService.deleteSession(id); } catch (_) {}
                }
                await _loadSessions();
              },
            ),
            if (i < today.length - 1) const SizedBox(height: 8),
          ],
          if (today.isNotEmpty) const SizedBox(height: 12),
          if (_showSkillForm) ...[
            _buildSkillForm(),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _showSkillForm = !_showSkillForm;
              if (!_showSkillForm) _clearSkillForm();
            }),
            icon: Icon(_showSkillForm ? Icons.close_rounded : Icons.add_rounded, size: 18),
            label: Text(_showSkillForm ? "Cancel" : "+ Add Skill Session"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.greenAccent,
              side: BorderSide(color: _showSkillForm ? _kBorder : Colors.greenAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillForm() {
    final showBowling    = _sTypes.contains(SkillSessionType.bowling);
    final showSubBowling = _sHasSub && _sSubTypes.contains(SkillSessionType.bowling);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel("Skill Type"),
          const SizedBox(height: 8),
          _ChipSelector<SkillSessionType>(
            values: SkillSessionType.values,
            selected: _sTypes,
            label: (v) => v.label,
            onToggle: (v) => setState(() =>
                _sTypes.contains(v) ? _sTypes.remove(v) : _sTypes.add(v)),
          ),
          const SizedBox(height: 14),
          _NumField(ctrl: _sDurCtrl, label: "Duration (minutes)"),
          if (showBowling) ...[
            const SizedBox(height: 10),
            _NumField(ctrl: _sBallsCtrl, label: "Balls bowled"),
          ],
          const SizedBox(height: 14),
          const _FieldLabel("RPE (Rate of Perceived Exertion)"),
          _RpeSlider(value: _sRpe, onChanged: (v) => setState(() => _sRpe = v)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _NumField(ctrl: _sMaxHRCtrl, label: "Max HR")),
            const SizedBox(width: 10),
            Expanded(child: _NumField(ctrl: _sAvgHRCtrl, label: "Avg HR")),
          ]),

          // Subordinate skill session
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _sHasSub ? Colors.greenAccent.withValues(alpha: 0.45) : _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // FIX: Wrapped Column in Expanded to prevent Row overflow
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Subordinate Skill Session",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextPrimary)),
                          Text("Additional skill practice in the same block",
                              style: TextStyle(fontSize: 11, color: _kTextSecondary)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _sHasSub,
                      activeColor: Colors.greenAccent,
                      onChanged: (v) => setState(() => _sHasSub = v),
                    ),
                  ],
                ),
                if (_sHasSub) ...[
                  const SizedBox(height: 12),
                  const _FieldLabel("Skill Type (Subordinate)"),
                  const SizedBox(height: 8),
                  _ChipSelector<SkillSessionType>(
                    values: SkillSessionType.values,
                    selected: _sSubTypes,
                    label: (v) => v.label,
                    onToggle: (v) => setState(() =>
                        _sSubTypes.contains(v) ? _sSubTypes.remove(v) : _sSubTypes.add(v)),
                  ),
                  const SizedBox(height: 12),
                  _NumField(ctrl: _sSubDurCtrl, label: "Duration (minutes)"),
                  if (showSubBowling) ...[
                    const SizedBox(height: 10),
                    _NumField(ctrl: _sSubBallsCtrl, label: "Balls bowled"),
                  ],
                  const SizedBox(height: 12),
                  const _FieldLabel("RPE — Subordinate Skill Session"),
                  _RpeSlider(value: _sSubRpe, onChanged: (v) => setState(() => _sSubRpe = v)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _submitSkill,
            icon: const Icon(Icons.sports_cricket_rounded, size: 18),
            label: const Text("Log Skill Session"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dashboard Tab ─────────────────────────────────────────────────────────

  Widget _buildDashboardTab() {
    final records = _buildDailyRecords();
    final acwr    = _acwr;
    final zScore  = _zScore;
    final last    = records.isNotEmpty ? records.last : null;

    if (_loadingSessions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart_rounded, size: 52, color: _kBorder),
            const SizedBox(height: 16),
            const Text("No data yet",
                style: TextStyle(color: _kTextPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text("Log your first session to get started.",
                style: TextStyle(color: _kTextSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const WorkloadMonitorScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kAccent.withValues(alpha: 0.18), _kAccent.withValues(alpha: 0.06)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kAccent.withValues(alpha: 0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.monitor_heart_rounded, color: _kAccent, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Workload Monitor',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kTextPrimary)),
                        Text('Training · Skill · Daily Total — athlete comparison',
                            style: TextStyle(fontSize: 11, color: _kTextSecondary)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 13, color: _kAccent),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (last?.wellness != null)
            _SectionCard(
              title: "Latest Readiness",
              child: Row(
                children: [
                  _ReadinessDot(pct: last!.readinessPercent, color: last.readinessColor),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${last.readinessPercent.toStringAsFixed(0)}% Ready",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: last.readinessColor)),
                        Text(
                          "Sleep ${last.wellness!.sleep}  ·  Wellness ${last.wellness!.wellness}"
                          "  ·  Soreness ${last.wellness!.soreness}  ·  Fatigue ${last.wellness!.fatigue}",
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          _SectionCard(
            title: "Load Metrics",
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: _MetricTile(label: "Acute Load",   subtitle: "Last 7 days",   value: _acuteLoad.toStringAsFixed(0),  color: Colors.lightBlueAccent)),
                  const SizedBox(width: 12),
                  Expanded(child: _MetricTile(label: "Chronic Load", subtitle: "EWMA 28-day",   value: _chronicLoad.toStringAsFixed(1), color: Colors.purpleAccent)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _MetricTile(
                    label: "ACWR", subtitle: _acwrLabel(acwr),
                    value: acwr == 0 ? "—" : acwr.toStringAsFixed(2),
                    color: _acwrColor(acwr),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _MetricTile(
                    label: "Scaled Grade", subtitle: "Last day",
                    value: last != null ? last.scaledGrade.toStringAsFixed(1) : "—",
                    color: Colors.yellowAccent,
                  )),
                ]),
                const SizedBox(height: 12),
                _MetricTile(
                  label: "Z-Score", subtitle: "Last vs chronic baseline",
                  value: records.length < 2 ? "—" : zScore.toStringAsFixed(2),
                  color: zScore > 2 ? Colors.redAccent : zScore < -2 ? Colors.blueAccent : Colors.tealAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _SectionCard(title: "ACWR Zone", child: _AcwrGauge(acwr: acwr)),
          const SizedBox(height: 12),

          _SectionCard(
            title: "Daily Load History",
            child: _DailyLoadBarChart(records: records),
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: "Readiness Trend",
            subtitle: "% Readiness per day over time",
            child: _ReadinessTrendChart(records: records),
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: "ACWR Trends",
            subtitle: "Solid = Chronic Load  ·  Orange dashed = ACWR",
            child: Column(children: [
              _AcwrTrendChart(data: _buildSeries((r) => r.trainingLoad), title: "Training ACWR",  lineColor: Colors.lightBlueAccent),
              const SizedBox(height: 14),
              _AcwrTrendChart(data: _buildSeries((r) => r.skillLoad),    title: "Skill ACWR",     lineColor: Colors.greenAccent),
              const SizedBox(height: 14),
              _AcwrTrendChart(data: _buildSeries((r) => r.totalLoad),    title: "Daily ACWR",     lineColor: Colors.purpleAccent),
            ]),
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: "Load vs Strain",
            subtitle: "Bars = Load  ·  White line = Scaled Grade",
            child: Column(children: [
              _LoadStrainChart(data: _buildSeries((r) => r.trainingLoad), title: "Training Load vs Strain", barColor: Colors.lightBlueAccent),
              const SizedBox(height: 14),
              _LoadStrainChart(data: _buildSeries((r) => r.skillLoad),    title: "Skill Load vs Strain",    barColor: Colors.greenAccent),
              const SizedBox(height: 14),
              _LoadStrainChart(data: _buildSeries((r) => r.totalLoad),    title: "Daily Load vs Strain",    barColor: Colors.purpleAccent),
            ]),
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: "Session Log",
            child: Column(
              children: List.generate(records.length, (i) {
                final r = records[records.length - 1 - i];
                return _DayRecordTile(
                  record: r,
                  onDeleteTraining: (t) async {
                    if (t.id != null) {
                      try { await ApiService.deleteSession(t.id!); } catch (_) {}
                    }
                    await _loadSessions();
                  },
                  onDeleteSkill: (s) async {
                    if (s.id != null) {
                      try { await ApiService.deleteSession(s.id!); } catch (_) {}
                    }
                    await _loadSessions();
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Color  _acwrColor(double v) {
    if (v == 0)   return Colors.grey;
    if (v < 0.8)  return Colors.blueAccent;
    if (v <= 1.3) return Colors.greenAccent;
    if (v <= 1.5) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _acwrLabel(double v) {
    if (v == 0)   return "No Data";
    if (v < 0.8)  return "Undertraining";
    if (v <= 1.3) return "Sweet Spot";
    if (v <= 1.5) return "Caution";
    return "Danger Zone";
  }
}

// ── Training Log Tile ─────────────────────────────────────────────────────────

class _TrainingLogTile extends StatelessWidget {
  final TrainingLog  log;
  final int          index;
  final VoidCallback onDelete;
  const _TrainingLogTile({required this.log, required this.index, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final primary = log.primaryTypes.map((t) => t.label).join(', ');
    final t       = log.timestamp;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Center(
              child: Text("$index", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kAccent)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(primary, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextPrimary)),
                Text(
                  "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}  ·  "
                  "${log.primaryDuration}min  ·  RPE ${log.primaryRpe}  ·  Load ${log.totalLoad.toStringAsFixed(0)}"
                  "${log.subTypes.isNotEmpty ? '  +  ${log.subTypes.map((s) => s.label).join(', ')}' : ''}",
                  style: const TextStyle(fontSize: 11, color: _kTextSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _kTextSecondary),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Skill Log Tile ────────────────────────────────────────────────────────────

class _SkillLogTile extends StatelessWidget {
  final SkillLog     log;
  final int          index;
  final VoidCallback onDelete;
  const _SkillLogTile({required this.log, required this.index, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final types = log.types.map((t) => t.label).join(', ');
    final t     = log.timestamp;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Center(
              child: Text("$index", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.greenAccent)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(types, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextPrimary)),
                Text(
                  "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}  ·  "
                  "${log.duration}min  ·  RPE ${log.rpe}  ·  Load ${log.totalLoad.toStringAsFixed(0)}"
                  "${log.subTypes.isNotEmpty ? '  +  ${log.subTypes.map((s) => s.label).join(', ')}' : ''}",
                  style: const TextStyle(fontSize: 11, color: _kTextSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _kTextSecondary),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Day Record Tile (dashboard session log) ───────────────────────────────────

class _DayRecordTile extends StatefulWidget {
  final DailyRecord record;
  final void Function(TrainingLog) onDeleteTraining;
  final void Function(SkillLog)    onDeleteSkill;
  const _DayRecordTile({required this.record, required this.onDeleteTraining, required this.onDeleteSkill});

  @override
  State<_DayRecordTile> createState() => _DayRecordTileState();
}

class _DayRecordTileState extends State<_DayRecordTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.record.date;
    final r = widget.record;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: r.readinessColor.withValues(alpha: 0.2),
                  child: Text(
                    r.wellness != null ? "${r.readinessPercent.toStringAsFixed(0)}%" : "—",
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${d.day}/${d.month}/${d.year}  ·  Load: ${r.totalLoad.toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 13, color: _kTextPrimary),
                      ),
                      Text(
                        "Training: ${r.trainingLoad.toStringAsFixed(0)}  ·  Skill: ${r.skillLoad.toStringAsFixed(0)}"
                        "  ·  ${r.training.length} training, ${r.skills.length} skill",
                        style: const TextStyle(fontSize: 11, color: _kTextSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18, color: _kTextSecondary),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          for (final t in r.training)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 6),
              child: _TrainingLogTile(
                log: t, index: r.training.indexOf(t) + 1,
                onDelete: () => widget.onDeleteTraining(t),
              ),
            ),
          for (final s in r.skills)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 6),
              child: _SkillLogTile(
                log: s, index: r.skills.indexOf(s) + 1,
                onDelete: () => widget.onDeleteSkill(s),
              ),
            ),
          const SizedBox(height: 4),
        ],
        const Divider(height: 1, color: _kBorder),
      ],
    );
  }
}

// ── Readiness Row ─────────────────────────────────────────────────────────────

class _ReadinessRow extends StatelessWidget {
  final String label, lowLabel, highLabel;
  final int    value;
  final ValueChanged<int> onChanged;
  const _ReadinessRow({required this.label, required this.value, required this.lowLabel, required this.highLabel, required this.onChanged});

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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _color(value).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _color(value).withValues(alpha: 0.6)),
              ),
              child: Text(value.toString(), style: TextStyle(color: _color(value), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(), min: 1, max: 5, divisions: 4,
          activeColor: _color(value),
          onChanged: (v) => onChanged(v.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lowLabel,  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(highLabel, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

// ── RPE Slider ────────────────────────────────────────────────────────────────

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
    return Column(children: [
      Slider(
        value: value.toDouble(), min: 1, max: 10, divisions: 9,
        label: value.toString(), activeColor: _color(value),
        onChanged: (v) => onChanged(v.round()),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("1 Not Intense", style: TextStyle(fontSize: 10, color: Colors.grey)),
          Text("RPE $value", style: TextStyle(fontWeight: FontWeight.bold, color: _color(value))),
          const Text("10 Very Intense", style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    ]);
  }
}

// ── Chip Selector ─────────────────────────────────────────────────────────────

class _ChipSelector<T> extends StatelessWidget {
  final List<T> values;
  final Set<T>  selected;
  final String Function(T) label;
  final void   Function(T) onToggle;
  const _ChipSelector({required this.values, required this.selected, required this.label, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 4,
      children: values.map((v) {
        final on = selected.contains(v);
        return FilterChip(
          label: Text(label(v), style: TextStyle(fontSize: 12, color: on ? Colors.white : _kTextSecondary, fontWeight: on ? FontWeight.w600 : FontWeight.normal)),
          selected: on,
          onSelected: (_) => onToggle(v),
          selectedColor: _kAccent,
          backgroundColor: _kBg,
          checkmarkColor: Colors.white,
          side: BorderSide(color: on ? _kAccent : _kBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        filled: true, fillColor: _kBg, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kAccent)),
      ),
    );
  }
}

// ── Field Label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 12, color: _kTextSecondary));
}

// ── Readiness Dot ─────────────────────────────────────────────────────────────

class _ReadinessDot extends StatelessWidget {
  final double pct;
  final Color  color;
  const _ReadinessDot({required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60, height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: pct / 100, strokeWidth: 5,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text("${pct.toStringAsFixed(0)}%",
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
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
            child: Row(children: [
              Expanded(flex: 40,  child: Container(color: Colors.blueAccent.withValues(alpha: 0.7))),
              Expanded(flex: 50,  child: Container(color: Colors.greenAccent.withValues(alpha: 0.85))),
              Expanded(flex: 10,  child: Container(color: Colors.orangeAccent.withValues(alpha: 0.85))),
              Expanded(flex: 100, child: Container(color: Colors.redAccent.withValues(alpha: 0.7))),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text("0",    style: TextStyle(fontSize: 10)),
            Text("0.8",  style: TextStyle(fontSize: 10)),
            Text("1.3",  style: TextStyle(fontSize: 10)),
            Text("1.5",  style: TextStyle(fontSize: 10)),
            Text("2.0+", style: TextStyle(fontSize: 10)),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (context, c) {
          final x = (c.maxWidth * (clamped / 2.0)).clamp(0.0, c.maxWidth - 20.0);
          return Stack(children: [
            const SizedBox(height: 24),
            Positioned(left: x, child: Icon(Icons.arrow_drop_down, color: acwr == 0 ? Colors.grey : Colors.white, size: 20)),
          ]);
        }),
        const SizedBox(height: 4),
        Text(
          acwr == 0 ? "Log sessions to see ACWR" : "ACWR: ${acwr.toStringAsFixed(2)}",
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            _ZoneLabel("Under-\ntraining", Colors.blueAccent),
            _ZoneLabel("Sweet\nSpot",      Colors.greenAccent),
            _ZoneLabel("Caution",          Colors.orangeAccent),
            _ZoneLabel("Danger",           Colors.redAccent),
          ],
        ),
      ],
    );
  }
}

class _ZoneLabel extends StatelessWidget {
  final String label;
  final Color  color;
  const _ZoneLabel(this.label, this.color);
  @override
  Widget build(BuildContext context) =>
      Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: color));
}

// ── Daily Load Bar Chart ──────────────────────────────────────────────────────

class _DailyLoadBarChart extends StatelessWidget {
  final List<DailyRecord> records;
  const _DailyLoadBarChart({required this.records});

  @override
  Widget build(BuildContext context) {
    final recent  = records.length > 14 ? records.sublist(records.length - 14) : records;
    final maxLoad = recent.map((r) => r.totalLoad).reduce(max);
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: recent.map((r) {
          final frac = maxLoad > 0 ? r.totalLoad / maxLoad : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(r.totalLoad.toStringAsFixed(0), style: const TextStyle(fontSize: 7)),
                  const SizedBox(height: 2),
                  Container(
                    height: 90 * frac + 4,
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text("${r.date.day}/${r.date.month}", style: const TextStyle(fontSize: 7)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Metric Tile ───────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  final String label, subtitle, value;
  final Color  color;
  const _MetricTile({required this.label, required this.subtitle, required this.value, required this.color});

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
          Text(label,    style: const TextStyle(fontSize: 11, color: _kTextSecondary)),
          const SizedBox(height: 6),
          Text(value,    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: _kTextSecondary)),
        ],
      ),
    );
  }
}

// ── ACWR Trend Chart ──────────────────────────────────────────────────────────

class _AcwrTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String title;
  final Color  lineColor;
  const _AcwrTrendChart({required this.data, required this.title, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(height: 80, child: Center(child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11))));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SizedBox(
          height: 160,
          child: CustomPaint(
            painter: _DualLinePainter(
              ewmaValues: data.map((d) => d['ewma']  as double).toList(),
              acwrValues: data.map((d) => d['acwr']  as double).toList(),
              dates:      data.map((d) => d['date']  as DateTime).toList(),
              lineColor:  lineColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _DualLinePainter extends CustomPainter {
  final List<double>   ewmaValues, acwrValues;
  final List<DateTime> dates;
  final Color          lineColor;
  _DualLinePainter({required this.ewmaValues, required this.acwrValues, required this.dates, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (ewmaValues.isEmpty) return;
    final n = ewmaValues.length;
    const bPad = 22.0, tPad = 14.0;
    final chartH = size.height - bPad - tPad;
    final xStep  = n > 1 ? size.width / (n - 1) : 0.0;
    double xAt(int i) => n == 1 ? size.width / 2 : i * xStep;

    double normY(double v, double mn, double mx) =>
        mx == mn ? tPad + chartH / 2 : tPad + chartH * (1 - (v - mn) / (mx - mn));

    final ewmaMin = ewmaValues.reduce(min), ewmaMax = ewmaValues.reduce(max);
    final acwrMin = acwrValues.reduce(min), acwrMax = acwrValues.reduce(max);

    final gPaint = Paint()..color = lineColor..strokeWidth = 2..style = PaintingStyle.stroke;
    final gPath  = Path();
    for (int i = 0; i < n; i++) {
      final p = Offset(xAt(i), normY(ewmaValues[i], ewmaMin, ewmaMax));
      i == 0 ? gPath.moveTo(p.dx, p.dy) : gPath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(gPath, gPaint);
    for (int i = 0; i < n; i++) {
      final p = Offset(xAt(i), normY(ewmaValues[i], ewmaMin, ewmaMax));
      canvas.drawCircle(p, 4, Paint()..color = lineColor);
      _text(canvas, "ACWR:${acwrValues[i].toStringAsFixed(2)}", p.dx, p.dy - 13, lineColor, 7.5);
    }

    final oPaint = Paint()..color = Colors.orangeAccent..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (int i = 0; i < n - 1; i++) {
      _dash(canvas, oPaint,
        Offset(xAt(i),     normY(acwrValues[i],     acwrMin, acwrMax)),
        Offset(xAt(i + 1), normY(acwrValues[i + 1], acwrMin, acwrMax)));
    }
    for (int i = 0; i < n; i++) {
      canvas.drawCircle(Offset(xAt(i), normY(acwrValues[i], acwrMin, acwrMax)), 3, Paint()..color = Colors.orangeAccent);
    }
    for (int i = 0; i < n; i++) {
      final d = dates[i];
      _text(canvas, "${d.day}/${d.month}", xAt(i), size.height - bPad + 5, Colors.grey, 7);
    }
  }

  void _dash(Canvas c, Paint p, Offset a, Offset b) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final nx = dx / dist, ny = dy / dist;
    double t = 0;
    while (t < dist) {
      final e = (t + 4.0).clamp(0.0, dist);
      c.drawLine(Offset(a.dx + nx * t, a.dy + ny * t), Offset(a.dx + nx * e, a.dy + ny * e), p);
      t += 7.0;
    }
  }

  void _text(Canvas c, String s, double cx, double cy, Color col, double fs) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs)), textDirection: TextDirection.ltr)..layout();
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
  final Color  barColor;
  const _LoadStrainChart({required this.data, required this.title, required this.barColor});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(height: 80, child: Center(child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11))));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SizedBox(
          height: 160,
          child: CustomPaint(
            painter: _BarLinePainter(
              barValues:  data.map((d) => d['load']   as double).toList(),
              lineValues: data.map((d) => d['strain'] as double).toList(),
              dates:      data.map((d) => d['date']   as DateTime).toList(),
              barColor:   barColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _BarLinePainter extends CustomPainter {
  final List<double>   barValues, lineValues;
  final List<DateTime> dates;
  final Color          barColor;
  _BarLinePainter({required this.barValues, required this.lineValues, required this.dates, required this.barColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (barValues.isEmpty) return;
    final n = barValues.length;
    const bPad = 22.0, tPad = 14.0;
    final chartH = size.height - bPad - tPad;
    final slotW  = size.width / n;
    final barW   = min(slotW * 0.6, 44.0);
    final maxBar = barValues.fold(0.0, (p, v) => v > p ? v : p).clamp(1.0, 1e9);
    final maxLine = lineValues.fold(0.0, (p, v) => v > p ? v : p);
    final minLine = lineValues.fold(maxLine, (p, v) => v < p ? v : p);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, tPad, size.width, chartH), const Radius.circular(4)),
      Paint()..color = Colors.white.withValues(alpha: 0.04),
    );

    final bPaint = Paint()..color = barColor.withValues(alpha: 0.75);
    for (int i = 0; i < n; i++) {
      final x  = i * slotW + (slotW - barW) / 2;
      final bh = (barValues[i] / maxBar) * chartH * 0.82;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - bPad - bh, barW, bh), const Radius.circular(3)),
        bPaint,
      );
      _text(canvas, barValues[i].toStringAsFixed(0), i * slotW + slotW / 2, size.height - bPad - bh - 11, Colors.white70, 7);
    }

    double lineY(double v) =>
        maxLine == minLine ? tPad + chartH / 2 : tPad + chartH * (1 - (v - minLine) / (maxLine - minLine));

    final lp   = Paint()..color = Colors.white..strokeWidth = 2..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < n; i++) {
      final x = i * slotW + slotW / 2;
      i == 0 ? path.moveTo(x, lineY(lineValues[i])) : path.lineTo(x, lineY(lineValues[i]));
    }
    canvas.drawPath(path, lp);
    for (int i = 0; i < n; i++) {
      final x = i * slotW + slotW / 2;
      canvas.drawCircle(Offset(x, lineY(lineValues[i])), 3, Paint()..color = Colors.white);
      _text(canvas, lineValues[i].toStringAsFixed(2), x, lineY(lineValues[i]) - 12, Colors.white, 7);
      _text(canvas, "${dates[i].day}/${dates[i].month}", x, size.height - bPad + 5, Colors.grey, 7);
    }
  }

  void _text(Canvas c, String s, double cx, double cy, Color col, double fs) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(cx - tp.width / 2, cy));
  }

  @override
  bool shouldRepaint(covariant _BarLinePainter old) =>
      old.barValues != barValues || old.lineValues != lineValues;
}

// ── Readiness Trend Chart ─────────────────────────────────────────────────────

class _ReadinessTrendChart extends StatelessWidget {
  final List<DailyRecord> records;
  const _ReadinessTrendChart({required this.records});

  @override
  Widget build(BuildContext context) {
    final withWellness = records.where((r) => r.wellness != null).toList();
    if (withWellness.isEmpty) {
      return const SizedBox(height: 80, child: Center(child: Text("No wellness data yet", style: TextStyle(color: Colors.grey, fontSize: 11))));
    }
    return SizedBox(height: 140, child: CustomPaint(painter: _ReadinessPainter(records: withWellness)));
  }
}

class _ReadinessPainter extends CustomPainter {
  final List<DailyRecord> records;
  _ReadinessPainter({required this.records});

  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;
    final n = records.length;
    const bPad = 22.0, tPad = 10.0;
    final chartH = size.height - bPad - tPad;
    final xStep  = n > 1 ? size.width / (n - 1) : 0.0;
    double xAt(int i) => n == 1 ? size.width / 2 : i * xStep;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, tPad, size.width, chartH), const Radius.circular(4)),
      Paint()..color = Colors.white.withValues(alpha: 0.04),
    );
    final refY = tPad + chartH * (1 - 0.75);
    canvas.drawLine(Offset(0, refY), Offset(size.width, refY),
        Paint()..color = Colors.greenAccent.withValues(alpha: 0.3)..strokeWidth = 1);
    _text(canvas, "75%", 16, refY - 9, Colors.greenAccent.withValues(alpha: 0.6), 7);

    final linePaint = Paint()..color = Colors.yellowAccent..strokeWidth = 2..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < n; i++) {
      final x = xAt(i), y = tPad + chartH * (1 - records[i].readinessPercent / 100);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, linePaint);

    final fill = Path()..addPath(path, Offset.zero);
    fill.lineTo(xAt(n - 1), size.height - bPad);
    fill.lineTo(xAt(0),     size.height - bPad);
    fill.close();
    canvas.drawPath(fill, Paint()..color = Colors.yellowAccent.withValues(alpha: 0.08));

    for (int i = 0; i < n; i++) {
      final pct = records[i].readinessPercent;
      final x   = xAt(i), y = tPad + chartH * (1 - pct / 100);
      final col = records[i].readinessColor;
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = col);
      _text(canvas, "${pct.toStringAsFixed(0)}%", x, y - 12, col, 7.5);
      final d = records[i].date;
      _text(canvas, "${d.day}/${d.month}", x, size.height - bPad + 5, Colors.grey, 7);
    }
  }

  void _text(Canvas c, String s, double cx, double cy, Color col, double fs) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(cx - tp.width / 2, cy));
  }

  @override
  bool shouldRepaint(covariant _ReadinessPainter old) => old.records != records;
}

// ── Section Card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String  title;
  final String? subtitle;
  final Widget  child;
  const _SectionCard({required this.title, this.subtitle, required this.child});

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
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kTextPrimary, letterSpacing: 0.1)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(subtitle!, style: const TextStyle(fontSize: 11, color: _kTextSecondary)),
            ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}