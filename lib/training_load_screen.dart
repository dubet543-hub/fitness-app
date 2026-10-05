import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'core/theme.dart';
import 'services/dashboard_metrics.dart';
import 'services/entitlements.dart';
import 'widgets/feature_gate.dart';

// Aliases so the rest of the file compiles without change.

// ── Enums ─────────────────────────────────────────────────────────────────────

enum PrimarySessionType {
  strength('Strength Program'),
  power('Power Program'),
  endurance('Endurance Program'),
  plyometrics('Plyometrics/Agility'),
  hiit('HIIT'),
  corrective('Corrective Prehab'),
  core('Core Program'),
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
    if (p >= 75) return kSuccess;
    if (p >= 50) return kWarn;
    if (p >= 25) return kWarn;
    return kDanger;
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
  Color  get readinessColor   => wellness?.readinessColor   ?? kTextSecondary;

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

class _TrainingLoadScreenState extends State<TrainingLoadScreen> {

  final List<WellnessLog> _wellnessLogs = [];
  final List<TrainingLog> _trainingLogs = [];
  final List<SkillLog>    _skillLogs    = [];

  // ── Training form ──────────────────────────────────────────────────────────
  bool _showTrainingForm = false;
  // True while a training submit is in flight — guards against a double-tap
  // (or a slow network prompting a second tap) firing two separate POSTs for
  // the same still-unlocked form, which was creating duplicate sessions.
  bool _submittingTraining = false;
  // Non-null while the form is editing an existing session rather than
  // logging a new one — set by tapping a today-tile's edit icon.
  TrainingLog? _editingTraining;
  final Set<PrimarySessionType>   _tPrimaryTypes = {};
  final _tPrimaryDurCtrl = TextEditingController();
  int  _tPrimaryRpe = 5;
  final _tDistCtrl       = TextEditingController();
  final _tSprintsCtrl    = TextEditingController();
  final _tMaxHRCtrl      = TextEditingController();
  final _tAvgHRCtrl      = TextEditingController();

  // ── Skill form ─────────────────────────────────────────────────────────────
  bool _showSkillForm = false;
  bool _submittingSkill = false; // same double-submit guard as training, above
  SkillLog? _editingSkill; // same edit-mode flag as training, above
  final Set<SkillSessionType> _sTypes    = {};
  final _sDurCtrl        = TextEditingController();
  int  _sRpe             = 5;
  final _sBallsCtrl      = TextEditingController();
  final _sMaxHRCtrl      = TextEditingController();
  final _sAvgHRCtrl      = TextEditingController();

  bool _loadingSessions = true;
  String? _sessionError;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    for (final c in [
      _tPrimaryDurCtrl, _tDistCtrl, _tSprintsCtrl, _tMaxHRCtrl, _tAvgHRCtrl,
      _sDurCtrl, _sBallsCtrl, _sMaxHRCtrl, _sAvgHRCtrl,
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
    // Mongoose array paths (primaryTypes/skillTypes) come back as [] rather
    // than null when empty, so a bare `!= null` check reports EVERY session as
    // having skill data (skillTypes: []) and misfiles training sessions under
    // Skill. Treat an empty list as absent, and trust the explicit hasSkill
    // flag the skill payload sets as the authoritative signal.
    bool present(dynamic v) => v is List ? v.isNotEmpty : v != null;
    final hasWellness = [raw['sleep'], raw['wellness'], raw['soreness'], raw['fatigue']].any(present);
    final hasTraining = [raw['primaryTypes'], raw['primaryDuration'], raw['primaryRpe']].any(present);
    final hasSkill = raw['hasSkill'] == true ||
        [raw['skillTypes'], raw['skillDuration'], raw['skillRpe']].any(present);

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

  List<TrainingLog> get _todayTraining {
    final key = _dateKey(DateTime.now());
    return _trainingLogs.where((t) => _dateKey(t.timestamp) == key).toList();
  }

  List<SkillLog> get _todaySkills {
    final key = _dateKey(DateTime.now());
    return _skillLogs.where((s) => _dateKey(s.timestamp) == key).toList();
  }

  // ── Day-by-day history ──────────────────────────────────────────────────────

  static const _monthsShort = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static const _weekdaysShort = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

  String _historyDateLabel(DateTime d) {
    final today = DateTime.now();
    final isToday = _dateKey(d) == _dateKey(today);
    final isYesterday = _dateKey(d) == _dateKey(today.subtract(const Duration(days: 1)));
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    return '${_weekdaysShort[d.weekday - 1]}, ${d.day} ${_monthsShort[d.month - 1]}';
  }

  Widget _buildDayByDayHistory() {
    // Newest day first; only days that actually have logged data.
    final records = _buildDailyRecords().reversed
        .where((r) => r.wellness != null || r.training.isNotEmpty || r.skills.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
          child: Row(children: [
            const Expanded(child: _SectionLabel('Day-by-day history')),
            Text('${records.length} day${records.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 13, color: kTextMuted)),
          ]),
        ),
        _Card(
          padding: EdgeInsets.zero,
          child: records.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Text('No history yet — your logged days will appear here.',
                      style: TextStyle(fontSize: 14, color: kTextSecondary)),
                )
              : Column(children: [
                  for (int i = 0; i < records.length; i++) ...[
                    if (i > 0) const Divider(height: 0.6, indent: 16),
                    _historyDayTile(records[i]),
                  ],
                ]),
        ),
      ],
    );
  }

  Widget _historyDayTile(DailyRecord r) {
    final hasWellness = r.wellness != null;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.only(left: 16, right: 12),
        childrenPadding: const EdgeInsets.fromLTRB(34, 0, 16, 14),
        iconColor: kTextMuted,
        collapsedIconColor: kTextMuted,
        onExpansionChanged: (_) => hapticSelect(),
        title: Row(children: [
          // Readiness status dot — grey when no wellness was logged that day.
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: hasWellness ? r.readinessColor : kBorderBright,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_historyDateLabel(r.date),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextPrimary)),
              const SizedBox(height: 2),
              Text(
                hasWellness
                    ? 'Readiness ${r.readinessPercent.round()}%  ·  Load ${r.totalLoad.round()}'
                    : 'Load ${r.totalLoad.round()}  ·  no wellness log',
                style: const TextStyle(fontSize: 13, color: kTextSecondary),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Text('${r.totalLoad.round()}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: kTextPrimary, letterSpacing: -0.3)),
        ]),
        children: [
          _historyLine('Wellness', hasWellness ? '${r.readinessPercent.round()}% readiness' : '—'),
          _historyLine('Training', r.training.isEmpty
              ? '—'
              : '${r.training.length} session${r.training.length == 1 ? '' : 's'}  ·  load ${r.trainingLoad.round()}'),
          _historyLine('Skill', r.skills.isEmpty
              ? '—'
              : '${r.skills.length} session${r.skills.length == 1 ? '' : 's'}  ·  load ${r.skillLoad.round()}'),
          _historyLine('Daily total', 'load ${r.totalLoad.round()}  ·  grade ${r.scaledGrade.toStringAsFixed(1)}'),
        ],
      ),
    );
  }

  Widget _historyLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 96, child: Text(label, style: const TextStyle(fontSize: 13, color: kTextSecondary))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: kTextPrimary))),
    ]),
  );

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

  // ── Submit: Training ──────────────────────────────────────────────────────

  // Daily activity-log caps: 2 training sessions + 2 skill sessions.
  static const int _maxTrainingPerDay = 2;
  static const int _maxSkillPerDay    = 2;

  Future<void> _submitTraining() async {
    if (_submittingTraining) return; // already saving this exact tap's request
    final editing = _editingTraining;
    // Editing replaces an already-counted session rather than adding a new
    // one, so the daily cap only applies when there's nothing being edited.
    if (editing == null && _todayTraining.length >= _maxTrainingPerDay) {
      _snack("Daily limit reached — max $_maxTrainingPerDay training sessions per day");
      return;
    }
    if (_tPrimaryTypes.isEmpty) { _snack("Select at least one session type"); return; }
    final dur = int.tryParse(_tPrimaryDurCtrl.text.trim()) ?? 0;
    if (dur <= 0) { _snack("Enter a valid duration"); return; }

    final capturedPrimaryTypes = Set<PrimarySessionType>.from(_tPrimaryTypes);
    final capturedPrimaryRpe = _tPrimaryRpe;
    final now = DateTime.now();

    setState(() => _submittingTraining = true);
    try {
      final payload = {
        'primaryTypes': capturedPrimaryTypes.map((e) => e.name).toList(),
        'primaryDuration': dur,
        'primaryRpe': capturedPrimaryRpe,
        'hasSecondary': false,
        'secondaryTypes': [],
        'secondaryDuration': null,
        'secondaryRpe': null,
        'distance': int.tryParse(_tDistCtrl.text.trim()),
        'sprints': int.tryParse(_tSprintsCtrl.text.trim()),
        'maxHR': int.tryParse(_tMaxHRCtrl.text.trim()),
        'avgHR': int.tryParse(_tAvgHRCtrl.text.trim()),
      };
      if (editing != null) {
        await ApiService.updateSession(editing.id!, payload);
      } else {
        await ApiService.submitSession({
          // UTC + offset marker — a bare local ISO string has no timezone
          // info, so the backend's `new Date(str)` cast parses it as if it
          // were already UTC, silently shifting the stored instant by the
          // device's offset (and occasionally into the wrong calendar day).
          'date': now.toUtc().toIso8601String(),
          ...payload,
        });
      }
      AthleteMetricsService.invalidate(); // dashboard recomputes with this session
      _clearTrainingForm();
      setState(() => _showTrainingForm = false);
      await _loadSessions();
      _snack(editing != null ? "Training session updated!" : "Training session logged!");
    } catch (err) {
      _snack("Failed to save training session: $err");
    } finally {
      if (mounted) setState(() => _submittingTraining = false);
    }
  }

  // ── Submit: Skill ─────────────────────────────────────────────────────────

  Future<void> _submitSkill() async {
    if (_submittingSkill) return; // already saving this exact tap's request
    final editing = _editingSkill;
    // Editing replaces an already-counted session rather than adding a new
    // one, so the daily cap only applies when there's nothing being edited.
    if (editing == null && _todaySkills.length >= _maxSkillPerDay) {
      _snack("Daily limit reached — max $_maxSkillPerDay skill sessions per day");
      return;
    }
    if (_sTypes.isEmpty) { _snack("Select at least one skill type"); return; }
    final dur = int.tryParse(_sDurCtrl.text.trim()) ?? 0;
    if (dur <= 0) { _snack("Enter a valid duration"); return; }

    final capturedTypes = Set<SkillSessionType>.from(_sTypes);
    final capturedRpe = _sRpe;
    final now = DateTime.now();

    setState(() => _submittingSkill = true);
    try {
      final payload = {
        'hasSkill': true,
        'skillTypes': capturedTypes.map((e) => e.name).toList(),
        'skillDuration': dur,
        'skillRpe': capturedRpe,
        'ballsBowled': capturedTypes.contains(SkillSessionType.bowling) ? int.tryParse(_sBallsCtrl.text.trim()) : null,
        'skillMaxHR': int.tryParse(_sMaxHRCtrl.text.trim()),
        'skillAvgHR': int.tryParse(_sAvgHRCtrl.text.trim()),
      };
      if (editing != null) {
        await ApiService.updateSession(editing.id!, payload);
      } else {
        await ApiService.submitSession({
          'date': now.toUtc().toIso8601String(),
          ...payload,
        });
      }
      AthleteMetricsService.invalidate(); // dashboard recomputes with this session
      _clearSkillForm();
      setState(() => _showSkillForm = false);
      await _loadSessions();
      _snack(editing != null ? "Skill session updated!" : "Skill session logged!");
    } catch (err) {
      _snack("Failed to save skill session: $err");
    } finally {
      if (mounted) setState(() => _submittingSkill = false);
    }
  }

  // ── Clear forms ───────────────────────────────────────────────────────────

  void _clearTrainingForm() {
    _tPrimaryTypes.clear();
    _tPrimaryDurCtrl.clear();
    _tPrimaryRpe = 5;
    _tDistCtrl.clear();
    _tSprintsCtrl.clear();
    _tMaxHRCtrl.clear();
    _tAvgHRCtrl.clear();
    _editingTraining = null;
  }

  void _clearSkillForm() {
    _sTypes.clear();
    _sDurCtrl.clear();
    _sRpe = 5;
    _sBallsCtrl.clear();
    _sMaxHRCtrl.clear();
    _sAvgHRCtrl.clear();
    _editingSkill = null;
  }

  /// Opens the training form pre-filled with an existing session's values,
  /// so submitting saves changes to it instead of logging a new one.
  void _startEditTraining(TrainingLog log) {
    setState(() {
      _editingTraining = log;
      _tPrimaryTypes..clear()..addAll(log.primaryTypes);
      _tPrimaryDurCtrl.text = log.primaryDuration.toString();
      _tPrimaryRpe = log.primaryRpe;
      _tDistCtrl.text = log.distance?.toString() ?? '';
      _tSprintsCtrl.text = log.sprints?.toString() ?? '';
      _tMaxHRCtrl.text = log.maxHR?.toString() ?? '';
      _tAvgHRCtrl.text = log.avgHR?.toString() ?? '';
      _showTrainingForm = true;
    });
  }

  /// Same as [_startEditTraining], for the skill session form.
  void _startEditSkill(SkillLog log) {
    setState(() {
      _editingSkill = log;
      _sTypes..clear()..addAll(log.types);
      _sDurCtrl.text = log.duration.toString();
      _sRpe = log.rpe;
      _sBallsCtrl.text = log.ballsBowled?.toString() ?? '';
      _sMaxHRCtrl.text = log.maxHR?.toString() ?? '';
      _sAvgHRCtrl.text = log.avgHR?.toString() ?? '';
      _showSkillForm = true;
    });
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => FeatureGuard(
      feature: FeatureKeys.loadModulation, child: _gatedBody(context));

  Widget _gatedBody(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text("Training load"),
      ),
      body: _buildLogTab(),
    );
  }

  // ── Log Tab ───────────────────────────────────────────────────────────────

  Widget _buildLogTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loadingSessions) ...[
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(2)),
              child: LinearProgressIndicator(minHeight: 2),
            ),
            const SizedBox(height: 12),
          ],
          if (_sessionError != null) ...[
            _Card(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.error_outline_rounded, size: 18, color: kDanger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Failed to sync sessions: $_sessionError',
                    style: const TextStyle(fontSize: 13, color: kTextSecondary, height: 1.4),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          _buildTrainingSessions(),
          const SizedBox(height: 16),
          _buildSkillSessions(),
          const SizedBox(height: 28),
          _buildDayByDayHistory(),
        ],
      ),
    );
  }

  // ── Training sessions section ─────────────────────────────────────────────

  Widget _buildTrainingSessions() {
    final today    = _todayTraining;
    final capped   = today.length >= _maxTrainingPerDay;
    return _SectionCard(
      title: "Training sessions",
      subtitle: "Up to $_maxTrainingPerDay per day · ${today.length}/$_maxTrainingPerDay logged today",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < today.length; i++) ...[
            if (i > 0) const Divider(height: 0.6, indent: 32),
            _TrainingLogTile(
              log: today[i],
              index: i + 1,
              onEdit: () { hapticSelect(); _startEditTraining(today[i]); },
            ),
          ],
          if (today.isNotEmpty) const SizedBox(height: 12),
          if (_showTrainingForm && (!capped || _editingTraining != null)) ...[
            _buildTrainingForm(),
            const SizedBox(height: 12),
          ],
          if (capped && _editingTraining == null)
            _DailyLimitNotice(text: "Daily training limit reached ($_maxTrainingPerDay sessions).")
          else
            OutlinedButton.icon(
              onPressed: () {
                hapticSelect();
                setState(() {
                  _showTrainingForm = !_showTrainingForm;
                  if (!_showTrainingForm) _clearTrainingForm();
                });
              },
              icon: Icon(_showTrainingForm ? Icons.close_rounded : Icons.add_rounded, size: 20),
              label: Text(_showTrainingForm ? "Cancel" : "Add training session"),
            ),
        ],
      ),
    );
  }

  Widget _buildTrainingForm() {
    final showExtra = _tPrimaryTypes.contains(PrimarySessionType.endurance) ||
        _tPrimaryTypes.contains(PrimarySessionType.hiit);
    return _FormWell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel("Session type (primary)"),
          const SizedBox(height: 8),
          _ChipSelector<PrimarySessionType>(
            values: PrimarySessionType.values,
            selected: _tPrimaryTypes,
            label: (v) => v.label,
            // Single-select: a training session is one type at a time, so
            // picking a new one replaces whatever was picked before instead
            // of piling up (the Set only ever held one PrimarySessionType by
            // convention, but toggling by add/remove let a second tap leave
            // both selected).
            onToggle: (v) => setState(() => _tPrimaryTypes
              ..clear()
              ..add(v)),
          ),
          const SizedBox(height: 20),
          _NumField(ctrl: _tPrimaryDurCtrl, label: "Duration (minutes)"),
          const SizedBox(height: 20),
          const _FieldLabel("RPE — primary session"),
          const SizedBox(height: 4),
          _RpeSlider(value: _tPrimaryRpe, onChanged: (v) => setState(() => _tPrimaryRpe = v)),
          if (showExtra) ...[
            const SizedBox(height: 20),
            _NumField(ctrl: _tDistCtrl,    label: "Distance (metres) — Endurance / HIIT"),
            const SizedBox(height: 12),
            _NumField(ctrl: _tSprintsCtrl, label: "Total sprints (High Intensity Running)"),
          ],
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _NumField(ctrl: _tMaxHRCtrl, label: "Max HR")),
            const SizedBox(width: 12),
            Expanded(child: _NumField(ctrl: _tAvgHRCtrl, label: "Avg HR")),
          ]),
          const SizedBox(height: 24),
          _SubmitButton(
            busy: _submittingTraining,
            label: _editingTraining != null ? "Save changes" : "Log training session",
            onPressed: _submitTraining,
          ),
        ],
      ),
    );
  }

  // ── Skill sessions section ────────────────────────────────────────────────

  Widget _buildSkillSessions() {
    final today  = _todaySkills;
    final capped = today.length >= _maxSkillPerDay;
    return _SectionCard(
      title: "Skill sessions",
      subtitle: "Up to $_maxSkillPerDay per day · ${today.length}/$_maxSkillPerDay logged today",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < today.length; i++) ...[
            if (i > 0) const Divider(height: 0.6, indent: 32),
            _SkillLogTile(
              log: today[i],
              index: i + 1,
              onEdit: () { hapticSelect(); _startEditSkill(today[i]); },
            ),
          ],
          if (today.isNotEmpty) const SizedBox(height: 12),
          if (_showSkillForm && (!capped || _editingSkill != null)) ...[
            _buildSkillForm(),
            const SizedBox(height: 12),
          ],
          if (capped && _editingSkill == null)
            _DailyLimitNotice(text: "Daily skill limit reached ($_maxSkillPerDay sessions).")
          else
            OutlinedButton.icon(
              onPressed: () {
                hapticSelect();
                setState(() {
                  _showSkillForm = !_showSkillForm;
                  if (!_showSkillForm) _clearSkillForm();
                });
              },
              icon: Icon(_showSkillForm ? Icons.close_rounded : Icons.add_rounded, size: 20),
              label: Text(_showSkillForm ? "Cancel" : "Add skill session"),
            ),
        ],
      ),
    );
  }

  Widget _buildSkillForm() {
    final showBowling    = _sTypes.contains(SkillSessionType.bowling);
    return _FormWell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel("Skill type"),
          const SizedBox(height: 8),
          _ChipSelector<SkillSessionType>(
            values: SkillSessionType.values,
            selected: _sTypes,
            label: (v) => v.label,
            // Single-select, same reasoning as the primary training chips.
            onToggle: (v) => setState(() => _sTypes
              ..clear()
              ..add(v)),
          ),
          const SizedBox(height: 20),
          _NumField(ctrl: _sDurCtrl, label: "Duration (minutes)"),
          if (showBowling) ...[
            const SizedBox(height: 12),
            _NumField(ctrl: _sBallsCtrl, label: "Balls bowled"),
          ],
          const SizedBox(height: 20),
          const _FieldLabel("RPE (rate of perceived exertion)"),
          const SizedBox(height: 4),
          _RpeSlider(value: _sRpe, onChanged: (v) => setState(() => _sRpe = v)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _NumField(ctrl: _sMaxHRCtrl, label: "Max HR")),
            const SizedBox(width: 12),
            Expanded(child: _NumField(ctrl: _sAvgHRCtrl, label: "Avg HR")),
          ]),
          const SizedBox(height: 24),
          _SubmitButton(
            busy: _submittingSkill,
            label: _editingSkill != null ? "Save changes" : "Log skill session",
            onPressed: _submitSkill,
          ),
        ],
      ),
    );
  }

}

// ── Primitives ────────────────────────────────────────────────────────────────

/// Flat card: kCard fill, hairline border, no shadow. A Material so ripples
/// from rows inside it (e.g. the history ExpansionTiles) paint on the card.
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => Material(
    color: kCard,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kRadius),
      side: const BorderSide(color: kBorder, width: 0.6),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

/// Inset well that holds an open log form inside a section card, so the
/// kCard-filled inputs and chips read clearly against it.
class _FormWell extends StatelessWidget {
  final Widget child;
  const _FormWell({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
    decoration: BoxDecoration(
      color: kBg,
      borderRadius: BorderRadius.circular(kRadiusSm),
      border: Border.all(color: kBorder, width: 0.6),
    ),
    child: child,
  );
}

/// Section label above a group: 13 w600 secondary, sentence case.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
  );
}

/// Full-width green primary action with a confirm haptic. While [busy] the
/// button is disabled (the double-submit guard) and shows a spinner.
class _SubmitButton extends StatelessWidget {
  final bool busy;
  final String label;
  final VoidCallback onPressed;
  const _SubmitButton({required this.busy, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: busy ? null : () { hapticConfirm(); onPressed(); },
      child: busy
          ? const Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: kTextSecondary, strokeWidth: 2)),
              SizedBox(width: 10),
              Text("Saving…"),
            ])
          : Text(label),
    ),
  );
}

// ── Daily Limit Notice ────────────────────────────────────────────────────────

class _DailyLimitNotice extends StatelessWidget {
  final String text;
  const _DailyLimitNotice({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 52),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: kBg,
      borderRadius: BorderRadius.circular(kRadiusSm),
      border: Border.all(color: kBorder, width: 0.6),
    ),
    child: Row(children: [
      const Icon(Icons.check_circle_rounded, size: 18, color: kSuccess),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text,
            style: const TextStyle(fontSize: 14, color: kTextSecondary)),
      ),
    ]),
  );
}

// ── Today's session rows ──────────────────────────────────────────────────────
// Plain list rows: index in muted text, title, one line of detail, and an
// edit button. No tinted tiles.

class _SessionRow extends StatelessWidget {
  final int          index;
  final String       title;
  final String       detail;
  final VoidCallback onEdit;
  const _SessionRow({required this.index, required this.title, required this.detail, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text("$index",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextMuted)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextPrimary)),
                const SizedBox(height: 2),
                Text(detail, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20, color: kTextSecondary),
            tooltip: "Edit session",
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

String _hhmm(DateTime t) =>
    "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}";

// ── Training Log Tile ─────────────────────────────────────────────────────────

class _TrainingLogTile extends StatelessWidget {
  final TrainingLog  log;
  final int          index;
  final VoidCallback onEdit;
  const _TrainingLogTile({required this.log, required this.index, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final primary = log.primaryTypes.map((t) => t.label).join(', ');
    return _SessionRow(
      index: index,
      title: primary,
      detail: "${_hhmm(log.timestamp)}  ·  "
          "${log.primaryDuration}min  ·  RPE ${log.primaryRpe}  ·  Load ${log.totalLoad.toStringAsFixed(0)}"
          "${log.subTypes.isNotEmpty ? '  +  ${log.subTypes.map((s) => s.label).join(', ')}' : ''}",
      onEdit: onEdit,
    );
  }
}

// ── Skill Log Tile ────────────────────────────────────────────────────────────

class _SkillLogTile extends StatelessWidget {
  final SkillLog     log;
  final int          index;
  final VoidCallback onEdit;
  const _SkillLogTile({required this.log, required this.index, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final types = log.types.map((t) => t.label).join(', ');
    return _SessionRow(
      index: index,
      title: types,
      detail: "${_hhmm(log.timestamp)}  ·  "
          "${log.duration}min  ·  RPE ${log.rpe}  ·  Load ${log.totalLoad.toStringAsFixed(0)}"
          "${log.subTypes.isNotEmpty ? '  +  ${log.subTypes.map((s) => s.label).join(', ')}' : ''}",
      onEdit: onEdit,
    );
  }
}

// ── RPE Slider ────────────────────────────────────────────────────────────────
// Neutral theme slider; the chosen value is shown large, with a small dot that
// keeps the old intensity cue (easy → moderate → hard).

class _RpeSlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _RpeSlider({required this.value, required this.onChanged});

  Color _color(int v) {
    if (v <= 3) return kSuccess;
    if (v <= 6) return kWarn;
    if (v <= 8) return kWarn;
    return kDanger;
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        label: "RPE $value of 10",
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("$value",
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700,
                    color: kTextPrimary, letterSpacing: -0.8, height: 1.1)),
            const Text(" /10",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
            const SizedBox(width: 10),
            // Intensity cue: green easy, amber moderate/hard, red maximal.
            Container(width: 8, height: 8,
                decoration: BoxDecoration(color: _color(value), shape: BoxShape.circle)),
          ],
        ),
      ),
      Slider(
        value: value.toDouble(), min: 1, max: 10, divisions: 9,
        label: value.toString(),
        onChanged: (v) {
          final next = v.round();
          if (next != value) hapticSelect();
          onChanged(next);
        },
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("1 Not intense", style: TextStyle(fontSize: 12, color: kTextMuted)),
            Text("10 Very intense", style: TextStyle(fontSize: 12, color: kTextMuted)),
          ],
        ),
      ),
    ]);
  }
}

// ── Chip Selector ─────────────────────────────────────────────────────────────
// Theme chips: unselected = card with hairline, selected = light fill with
// dark text. No checkmark, no colour tint.

class _ChipSelector<T> extends StatelessWidget {
  final List<T> values;
  final Set<T>  selected;
  final String Function(T) label;
  final void   Function(T) onToggle;
  const _ChipSelector({required this.values, required this.selected, required this.label, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: values.map((v) {
        final on = selected.contains(v);
        return FilterChip(
          label: Text(label(v)),
          labelStyle: TextStyle(
            fontSize: 14,
            color: on ? kBg : kTextPrimary,
            fontWeight: on ? FontWeight.w600 : FontWeight.w500,
          ),
          selected: on,
          showCheckmark: false,
          onSelected: (_) { hapticSelect(); onToggle(v); },
          selectedColor: kTextPrimary,
          backgroundColor: kCard,
          side: BorderSide(color: on ? kTextPrimary : kBorder),
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
      style: const TextStyle(color: kTextPrimary, fontSize: 16),
      decoration: InputDecoration(labelText: label),
    );
  }
}

// ── Field Label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary));
}

// ── Section Card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String  title;
  final String? subtitle;
  final Widget  child;
  const _SectionCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextPrimary, letterSpacing: -0.2)),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
            ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
