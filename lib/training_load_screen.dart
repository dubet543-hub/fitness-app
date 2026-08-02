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
  final Set<PrimarySessionType>   _tPrimaryTypes = {};
  final _tPrimaryDurCtrl = TextEditingController();
  int  _tPrimaryRpe = 5;
  String? _tSessionType; // "Match day", "Strength Program", etc.
  final _tDistCtrl       = TextEditingController();
  final _tSprintsCtrl    = TextEditingController();
  final _tMaxHRCtrl      = TextEditingController();
  final _tAvgHRCtrl      = TextEditingController();

  // ── Skill form ─────────────────────────────────────────────────────────────
  bool _showSkillForm = false;
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

    return Container(
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.calendar_month_rounded, size: 16, color: kAccent),
          const SizedBox(width: 8),
          Text('DAY-BY-DAY HISTORY',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: kTextSecondary, letterSpacing: 1.2)),
          const Spacer(),
          Text('${records.length} day${records.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 11, color: kTextMuted)),
        ]),
        const SizedBox(height: 6),
        if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No history yet — your logged days will appear here.',
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          )
        else
          ...records.map(_historyDayTile),
      ]),
    );
  }

  Widget _historyDayTile(DailyRecord r) {
    final hasWellness = r.wellness != null;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 8, bottom: 10),
        title: Row(children: [
          Container(width: 3, height: 30,
            decoration: BoxDecoration(
              color: hasWellness ? r.readinessColor : kBorder,
              borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_historyDateLabel(r.date),
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
              Text(
                hasWellness
                    ? 'Readiness ${r.readinessPercent.round()}%  ·  Load ${r.totalLoad.round()}'
                    : 'Load ${r.totalLoad.round()}  ·  no wellness log',
                style: TextStyle(fontSize: 11.5, color: kTextSecondary),
              ),
            ]),
          ),
          _loadChip('${r.totalLoad.round()}', kAccent),
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

  Widget _loadChip(String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
  );

  Widget _historyLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 12, color: kTextSecondary))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: kTextPrimary))),
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
    if (_todayTraining.length >= _maxTrainingPerDay) {
      _snack("Daily limit reached — max $_maxTrainingPerDay training sessions per day");
      return;
    }
    if (_tPrimaryTypes.isEmpty) { _snack("Select at least one session type"); return; }
    final dur = int.tryParse(_tPrimaryDurCtrl.text.trim()) ?? 0;
    if (dur <= 0) { _snack("Enter a valid duration"); return; }

    final capturedPrimaryTypes = Set<PrimarySessionType>.from(_tPrimaryTypes);
    final capturedPrimaryRpe = _tPrimaryRpe;
    final now = DateTime.now();

    try {
      await ApiService.submitSession({
        'date': now.toIso8601String(),
        'sessionType': _tSessionType,
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
      });
      AthleteMetricsService.invalidate(); // dashboard recomputes with this session
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
    if (_todaySkills.length >= _maxSkillPerDay) {
      _snack("Daily limit reached — max $_maxSkillPerDay skill sessions per day");
      return;
    }
    if (_sTypes.isEmpty) { _snack("Select at least one skill type"); return; }
    final dur = int.tryParse(_sDurCtrl.text.trim()) ?? 0;
    if (dur <= 0) { _snack("Enter a valid duration"); return; }

    final capturedTypes = Set<SkillSessionType>.from(_sTypes);
    final capturedRpe = _sRpe;
    final now = DateTime.now();

    try {
      await ApiService.submitSession({
        'date': now.toIso8601String(),
        'hasSkill': true,
        'skillTypes': capturedTypes.map((e) => e.name).toList(),
        'skillDuration': dur,
        'skillRpe': capturedRpe,
        'ballsBowled': capturedTypes.contains(SkillSessionType.bowling) ? int.tryParse(_sBallsCtrl.text.trim()) : null,
        'skillMaxHR': int.tryParse(_sMaxHRCtrl.text.trim()),
        'skillAvgHR': int.tryParse(_sAvgHRCtrl.text.trim()),
      });
      AthleteMetricsService.invalidate(); // dashboard recomputes with this session
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
    _tDistCtrl.clear();
    _tSprintsCtrl.clear();
    _tMaxHRCtrl.clear();
    _tAvgHRCtrl.clear();
  }

  void _clearSkillForm() {
    _sTypes.clear();
    _sDurCtrl.clear();
    _sRpe = 5;
    _sBallsCtrl.clear();
    _sMaxHRCtrl.clear();
    _sAvgHRCtrl.clear();
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
        backgroundColor: kSurface,
        title: Text("Training Load",
            style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true,
        iconTheme: IconThemeData(color: kTextPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: _buildLogTab(),
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
                color: kDanger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kDanger.withValues(alpha: 0.35)),
              ),
              child: Text(
                'Failed to sync sessions: $_sessionError',
                style: TextStyle(fontSize: 12, color: kDanger),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildTrainingSessions(),
          const SizedBox(height: 14),
          _buildSkillSessions(),
          const SizedBox(height: 14),
          _buildDayByDayHistory(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Training sessions section ─────────────────────────────────────────────

  Widget _buildTrainingSessions() {
    final today    = _todayTraining;
    final capped   = today.length >= _maxTrainingPerDay;
    return _SectionCard(
      title: "Training Sessions",
      subtitle: "Up to $_maxTrainingPerDay per day · ${today.length}/$_maxTrainingPerDay logged today",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < today.length; i++) ...[
            _TrainingLogTile(
              log: today[i],
              index: i + 1,
            ),
            if (i < today.length - 1) const SizedBox(height: 8),
          ],
          if (today.isNotEmpty) const SizedBox(height: 12),
          if (_showTrainingForm && !capped) ...[
            _buildTrainingForm(),
            const SizedBox(height: 12),
          ],
          if (capped)
            _DailyLimitNotice(text: "Daily training limit reached ($_maxTrainingPerDay sessions).")
          else
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _showTrainingForm = !_showTrainingForm;
                if (!_showTrainingForm) _clearTrainingForm();
              }),
              icon: Icon(_showTrainingForm ? Icons.close_rounded : Icons.add_rounded, size: 18),
              label: Text(_showTrainingForm ? "Cancel" : "+ Add Training Session"),
              style: OutlinedButton.styleFrom(
                foregroundColor: kAccent,
                side: BorderSide(color: _showTrainingForm ? kBorder : kAccent),
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
        color: kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
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
            hint: Text("Select session category", style: TextStyle(color: kTextSecondary)),
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
            style: TextStyle(color: kTextPrimary, fontSize: 14),
            dropdownColor: kSurface,
            underline: Container(height: 1, color: kBorder),
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
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _submitTraining,
            icon: const Icon(Icons.fitness_center_rounded, size: 18),
            label: const Text("Log Training Session"),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: kTextPrimary,
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
    final today  = _todaySkills;
    final capped = today.length >= _maxSkillPerDay;
    return _SectionCard(
      title: "Skill Sessions",
      subtitle: "Up to $_maxSkillPerDay per day · ${today.length}/$_maxSkillPerDay logged today",
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
                  try { await ApiService.deleteSession(id); AthleteMetricsService.invalidate(); } catch (_) {}
                }
                await _loadSessions();
              },
            ),
            if (i < today.length - 1) const SizedBox(height: 8),
          ],
          if (today.isNotEmpty) const SizedBox(height: 12),
          if (_showSkillForm && !capped) ...[
            _buildSkillForm(),
            const SizedBox(height: 12),
          ],
          if (capped)
            _DailyLimitNotice(text: "Daily skill limit reached ($_maxSkillPerDay sessions).")
          else
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _showSkillForm = !_showSkillForm;
                if (!_showSkillForm) _clearSkillForm();
              }),
              icon: Icon(_showSkillForm ? Icons.close_rounded : Icons.add_rounded, size: 18),
              label: Text(_showSkillForm ? "Cancel" : "+ Add Skill Session"),
              style: OutlinedButton.styleFrom(
                foregroundColor: kSuccess,
                side: BorderSide(color: _showSkillForm ? kBorder : kSuccess),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
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
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _submitSkill,
            icon: const Icon(Icons.sports_cricket_rounded, size: 18),
            label: const Text("Log Skill Session"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: kTextPrimary,
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

}

// ── Daily Limit Notice ────────────────────────────────────────────────────────

class _DailyLimitNotice extends StatelessWidget {
  final String text;
  const _DailyLimitNotice({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kBorder),
    ),
    child: Row(children: [
      Icon(Icons.check_circle_rounded, size: 18, color: kSuccess),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text,
            style: TextStyle(fontSize: 12.5, color: kTextSecondary)),
      ),
    ]),
  );
}

// ── Training Log Tile ─────────────────────────────────────────────────────────

class _TrainingLogTile extends StatelessWidget {
  final TrainingLog  log;
  final int          index;
  const _TrainingLogTile({required this.log, required this.index});

  @override
  Widget build(BuildContext context) {
    final primary = log.primaryTypes.map((t) => t.label).join(', ');
    final t       = log.timestamp;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Center(
              child: Text("$index", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kAccent)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(primary, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
                Text(
                  "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}  ·  "
                  "${log.primaryDuration}min  ·  RPE ${log.primaryRpe}  ·  Load ${log.totalLoad.toStringAsFixed(0)}"
                  "${log.subTypes.isNotEmpty ? '  +  ${log.subTypes.map((s) => s.label).join(', ')}' : ''}",
                  style: TextStyle(fontSize: 11, color: kTextSecondary),
                ),
              ],
            ),
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
        color: kSuccess.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kSuccess.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: kSuccess.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Center(
              child: Text("$index", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kSuccess)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(types, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
                Text(
                  "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}  ·  "
                  "${log.duration}min  ·  RPE ${log.rpe}  ·  Load ${log.totalLoad.toStringAsFixed(0)}"
                  "${log.subTypes.isNotEmpty ? '  +  ${log.subTypes.map((s) => s.label).join(', ')}' : ''}",
                  style: TextStyle(fontSize: 11, color: kTextSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 18, color: kTextSecondary),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── RPE Slider ────────────────────────────────────────────────────────────────

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
    return Column(children: [
      Slider(
        value: value.toDouble(), min: 1, max: 10, divisions: 9,
        label: value.toString(), activeColor: _color(value),
        onChanged: (v) => onChanged(v.round()),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("1 Not Intense", style: TextStyle(fontSize: 10, color: kTextSecondary)),
          Text("RPE $value", style: TextStyle(fontWeight: FontWeight.bold, color: _color(value))),
          Text("10 Very Intense", style: TextStyle(fontSize: 10, color: kTextSecondary)),
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
          label: Text(label(v), style: TextStyle(fontSize: 12, color: on ? kTextPrimary : kTextSecondary, fontWeight: on ? FontWeight.w600 : FontWeight.normal)),
          selected: on,
          onSelected: (_) => onToggle(v),
          selectedColor: kAccent,
          backgroundColor: kBg,
          checkmarkColor: kTextPrimary,
          side: BorderSide(color: on ? kAccent : kBorder),
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
      style: TextStyle(color: kTextPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: kTextSecondary, fontSize: 13),
        filled: true, fillColor: kBg, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kAccent)),
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
      Text(text, style: TextStyle(fontSize: 12, color: kTextSecondary));
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
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: 0.1)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(subtitle!, style: TextStyle(fontSize: 11, color: kTextSecondary)),
            ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
