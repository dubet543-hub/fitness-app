import 'package:flutter/material.dart';
import '../api_service.dart';
import '../core/theme.dart';
import '../services/dashboard_metrics.dart';
import '../services/local_log_store.dart';
import '../services/entitlements.dart';
import '../services/sleep_metrics.dart';
import '../widgets/feature_gate.dart';

/// Which clock a sleep-detail time picker is editing.
enum _SleepClock { bed, asleep, wake, outOfBed }

class WellnessLogScreen extends StatefulWidget {
  const WellnessLogScreen({super.key});

  @override
  State<WellnessLogScreen> createState() => _WellnessLogScreenState();
}

class _WellnessLogScreenState extends State<WellnessLogScreen> {
  // ── Core readiness ratings (1=best, 5=worst) ──────────────────────────────
  int _sleepScore   = 3;
  int _wellness     = 3;
  int _soreness     = 3;
  int _fatigue      = 3;

  // ── Sleep details ─────────────────────────────────────────────────────────
  TimeOfDay _timeToBed    = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _sleepTime    = const TimeOfDay(hour: 22, minute: 20);
  TimeOfDay _wakeUpTime   = const TimeOfDay(hour: 6,  minute: 0);
  TimeOfDay _outOfBedTime = const TimeOfDay(hour: 6,  minute: 10);
  bool      _disturbances = false;
  final _disturbanceCtrl        = TextEditingController();
  final _disturbanceMinutesCtrl = TextEditingController();
  final _roomTempCtrl     = TextEditingController();
  final _roomNoiseCtrl    = TextEditingController();
  final _roomLightCtrl    = TextEditingController();

  // ── Mood questions ────────────────────────────────────────────────────────
  String  _motivation    = '';
  String  _appetite      = '';
  final Set<String> _externalFactors = {};
  String  _needsPsych    = '';

  // ── Fatigue questions ─────────────────────────────────────────────────────
  final Set<String> _fatigueSymptoms = {};
  String  _perfDecrease   = '';
  final _perfDescCtrl      = TextEditingController();

  bool _submitting = false;
  String? _error;

  // Once recovery is logged it stays locked until the next 00:00 midnight.
  bool _alreadyLogged = false;

  @override
  void initState() {
    super.initState();
    LocalLogStore.recoveryLoggedToday().then((logged) {
      if (mounted) setState(() => _alreadyLogged = logged);
    });
  }

  bool get _showExtended => _wellness >= 3 || _fatigue >= 3;

  int _mins(TimeOfDay t) => t.hour * 60 + t.minute;

  /// Tonight's sleep expressed via the shared sheet formulae, so the log
  /// screen's duration/time-in-bed/efficiency figures stay identical to the
  /// Sleep Monitor's and to whatever the dashboard recomputes them into.
  SleepNight get _night => SleepNight(
        d: 'today',
        timeToBed:    _mins(_timeToBed),
        fellAsleep:   _mins(_sleepTime),
        wokeUp:       _mins(_wakeUpTime),
        outOfBed:     _mins(_outOfBedTime),
        awakeMinutes: _disturbances ? (int.tryParse(_disturbanceMinutesCtrl.text) ?? 0) : 0,
      );

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmt12(TimeOfDay t) {
    final hour12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour12:${t.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _pickTime(_SleepClock which) async {
    final current = switch (which) {
      _SleepClock.bed      => _timeToBed,
      _SleepClock.asleep   => _sleepTime,
      _SleepClock.wake     => _wakeUpTime,
      _SleepClock.outOfBed => _outOfBedTime,
    };
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
        child: Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
              primary: kAccent,
              surface: kSurface,
              onSurface: kTextPrimary,
            ),
          ),
          child: child!,
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      switch (which) {
        case _SleepClock.bed:      _timeToBed = picked;
        case _SleepClock.asleep:   _sleepTime = picked;
        case _SleepClock.wake:     _wakeUpTime = picked;
        case _SleepClock.outOfBed: _outOfBedTime = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!await LocalLogStore.dailyLogsConsent()) {
      if (mounted) {
        setState(() => _error =
            'Daily logs are turned off. Enable them in Privacy & Security settings to save.');
      }
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final payload = <String, dynamic>{
        'sleep':    _sleepScore,
        'wellness': _wellness,
        'soreness': _soreness,
        'fatigue':  _fatigue,
        'sleepTimeToBed':   _fmt(_timeToBed),
        'sleepFellAsleep':  _fmt(_sleepTime),
        'sleepWakeUpTime':  _fmt(_wakeUpTime),
        'sleepOutOfBedTime': _fmt(_outOfBedTime),
        'sleepTimeInBedMinutes': _night.timeInBedMinutes,
        'sleepMinutes':          _night.sleepMinutes,
        'sleepEfficiency':       (_night.efficiency * 100).roundToDouble() / 100,
        'sleepDisturbances': _disturbances,
        if (_disturbances && _disturbanceCtrl.text.isNotEmpty)
          'sleepDisturbanceDetails': _disturbanceCtrl.text.trim(),
        if (_disturbances && _disturbanceMinutesCtrl.text.isNotEmpty)
          'sleepDisturbanceMinutes': int.tryParse(_disturbanceMinutesCtrl.text) ?? 0,
        if (_roomTempCtrl.text.isNotEmpty)   'sleepRoomTemp':  _roomTempCtrl.text.trim(),
        if (_roomNoiseCtrl.text.isNotEmpty)  'sleepRoomNoise': _roomNoiseCtrl.text.trim(),
        if (_roomLightCtrl.text.isNotEmpty)  'sleepRoomLight': _roomLightCtrl.text.trim(),
        if (_showExtended) ...{
          if (_motivation.isNotEmpty)    'moodMotivation': _motivation,
          if (_appetite.isNotEmpty)      'moodAppetite': _appetite,
          if (_externalFactors.isNotEmpty) 'moodExternalFactors': _externalFactors.toList(),
          if (_needsPsych.isNotEmpty)    'moodNeedsPsychologist': _needsPsych,
          if (_fatigueSymptoms.isNotEmpty) 'fatigueSymptoms': _fatigueSymptoms.toList(),
          if (_perfDecrease.isNotEmpty)  'fatiguePerformanceDecrease': _perfDecrease,
          if (_perfDescCtrl.text.isNotEmpty) 'fatiguePerformanceDescription': _perfDescCtrl.text.trim(),
        },
      };
      await ApiService.submitSession(payload);
      AthleteMetricsService.invalidate(); // dashboard recomputes with this log
      await LocalLogStore.markRecoveryLogged();
      if (mounted) {
        setState(() => _alreadyLogged = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wellness log saved')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _disturbanceCtrl.dispose();
    _disturbanceMinutesCtrl.dispose();
    _roomTempCtrl.dispose();
    _roomNoiseCtrl.dispose();
    _roomLightCtrl.dispose();
    _perfDescCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FeatureGuard(
      feature: FeatureKeys.recovery, child: _gatedBody(context));

  Widget _gatedBody(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Wellness log'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 40),
        children: [
          // ── Readiness Ratings ───────────────────────────────────────────
          const _SectionHeader(title: 'Daily readiness', subtitle: '1 = Excellent · 5 = Very poor'),
          const SizedBox(height: 12),
          _Group(children: [
            _RatingSlider(label: 'Sleep quality',   value: _sleepScore, onChanged: (v) => setState(() => _sleepScore = v)),
            _RatingSlider(label: 'Wellness',        value: _wellness,   onChanged: (v) => setState(() => _wellness   = v)),
            _RatingSlider(label: 'Muscle soreness', value: _soreness,   onChanged: (v) => setState(() => _soreness   = v)),
            _RatingSlider(label: 'Fatigue',         value: _fatigue,    onChanged: (v) => setState(() => _fatigue    = v)),
          ]),

          const SizedBox(height: 32),
          // ── Sleep Details ───────────────────────────────────────────────
          const _SectionHeader(title: 'Sleep details'),
          const SizedBox(height: 12),

          // Time to bed / Fell asleep
          Row(
            children: [
              Expanded(child: _TimePickerTile(
                label: 'Time to bed',
                value: _fmt12(_timeToBed),
                onTap: () => _pickTime(_SleepClock.bed),
              )),
              const SizedBox(width: 12),
              Expanded(child: _TimePickerTile(
                label: 'Fell asleep',
                value: _fmt12(_sleepTime),
                onTap: () => _pickTime(_SleepClock.asleep),
              )),
            ],
          ),
          const SizedBox(height: 12),
          // Wake-up / Out of bed
          Row(
            children: [
              Expanded(child: _TimePickerTile(
                label: 'Wake-up time',
                value: _fmt12(_wakeUpTime),
                onTap: () => _pickTime(_SleepClock.wake),
              )),
              const SizedBox(width: 12),
              Expanded(child: _TimePickerTile(
                label: 'Out of bed',
                value: _fmt12(_outOfBedTime),
                onTap: () => _pickTime(_SleepClock.outOfBed),
              )),
            ],
          ),
          const SizedBox(height: 12),
          // Derived figures (read-only)
          _Group(children: [
            _ValueRow(label: 'Sleep time',       value: formatHhMm(_night.sleepMinutes)),
            _ValueRow(label: 'Time in bed',      value: formatHhMm(_night.timeInBedMinutes)),
            _ValueRow(label: 'Sleep efficiency', value: '${(_night.efficiency * 100).toStringAsFixed(0)}%'),
          ]),
          const SizedBox(height: 12),

          // Disturbances
          _ToggleTile(
            label: 'Sleep disturbances?',
            value: _disturbances,
            onChanged: (v) => setState(() => _disturbances = v),
          ),
          if (_disturbances) ...[
            const SizedBox(height: 12),
            _InputField(controller: _disturbanceCtrl, hint: 'Describe disturbance (e.g. Cramps, Noisy)'),
            const SizedBox(height: 12),
            _InputField(
              controller: _disturbanceMinutesCtrl,
              hint: 'Minutes awake during disturbance (e.g. 15)',
              label: 'Time awake during disturbance',
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 24),

          // Room Conditions
          const _SectionLabel('Room conditions'),
          const SizedBox(height: 8),
          _Group(children: [
            _InlineField(controller: _roomTempCtrl,  label: 'Temp',  hint: 'Temperature (e.g. 20°C)'),
            _InlineField(controller: _roomNoiseCtrl, label: 'Noise', hint: 'Noise (e.g. Silent)'),
            _InlineField(controller: _roomLightCtrl, label: 'Light', hint: 'Light (e.g. Pitch Black)'),
          ]),

          // ── Extended Questions (when wellness >= 3 OR fatigue >= 3) ────
          if (_showExtended) ...[
            const SizedBox(height: 32),
            const _Notice(
              icon: Icons.info_outline_rounded,
              iconColor: kTextSecondary,
              text: 'Wellness or fatigue concern detected — please complete the additional questions below.',
            ),
            const SizedBox(height: 28),

            // ── Mood Questions ────────────────────────────────────────
            const _SectionHeader(title: 'Mood assessment'),
            const SizedBox(height: 16),

            const _SectionLabel('1. Current motivation level for training & competition'),
            const SizedBox(height: 8),
            _OptionGroup(
              value: _motivation,
              options: const {
                'very_low':  'a) Very Low — Hard to even start',
                'low':       'b) Low — Going through the motions',
                'moderate':  'c) Moderate — Neutral, consistent effort',
                'high':      'd) High — Enthusiastic and focused',
                'very_high': 'e) Very High — Highly driven and excited',
              },
              onChanged: (v) => setState(() => _motivation = v),
            ),
            const SizedBox(height: 24),

            const _SectionLabel('2. Significant changes in appetite recently?'),
            const SizedBox(height: 8),
            _OptionGroup(
              value: _appetite,
              options: const {
                'no_change':  'a) No change',
                'decreased':  'b) Decreased appetite',
                'increased':  'c) Increased appetite',
              },
              onChanged: (v) => setState(() => _appetite = v),
            ),
            const SizedBox(height: 24),

            const _SectionLabel('3. External factors impacting your mood? (Select all that apply)'),
            const SizedBox(height: 8),
            _MultiOptionGroup(
              values: _externalFactors,
              options: const {
                'academic':    'a) Academic / Study Pressure',
                'family':      'b) Family Issues',
                'relationship':'c) Relationship Concerns',
                'financial':   'd) Financial Stress',
                'injury':      'e) Injury / Physical Health',
                'coach_team':  'f) Coach / Team Dynamics',
                'none':        'g) None / Not Applicable',
              },
              onChanged: (v) => setState(() {
                _externalFactors.clear();
                _externalFactors.addAll(v);
              }),
            ),
            const SizedBox(height: 24),

            const _SectionLabel('4. Do you need to speak with a sports psychologist this week?'),
            const SizedBox(height: 8),
            _OptionGroup(
              value: _needsPsych,
              options: const {
                'yes_urgent':    'a) Yes, urgently',
                'yes_this_week': 'b) Yes, sometime this week',
                'maybe':         'c) Maybe, I\'m unsure',
                'no':            'd) No, I am fine',
              },
              onChanged: (v) => setState(() => _needsPsych = v),
            ),
            const SizedBox(height: 32),

            // ── Fatigue Questions ──────────────────────────────────────
            const _SectionHeader(title: 'Fatigue assessment'),
            const SizedBox(height: 16),

            const _SectionLabel('1. Physical symptoms of fatigue you are currently experiencing? (Select all)'),
            const SizedBox(height: 8),
            _MultiOptionGroup(
              values: _fatigueSymptoms,
              options: const {
                'heavy_legs':        'a) Heavy legs / limbs',
                'headache':          'b) Persistent headache',
                'loss_of_appetite':  'c) Loss of appetite',
                'increased_hr':      'd) Increased resting heart rate',
                'slow_recovery':     'e) Slow recovery after exertion',
                'frequent_illness':  'f) Frequent minor illness',
                'joint_pain':        'g) Joint pain',
                'none':              'h) None of the above',
              },
              onChanged: (v) => setState(() {
                _fatigueSymptoms.clear();
                _fatigueSymptoms.addAll(v);
              }),
            ),
            const SizedBox(height: 24),

            const _SectionLabel('2. Performance change in recent training / competitions?'),
            const SizedBox(height: 8),
            _OptionGroup(
              value: _perfDecrease,
              options: const {
                'significant': 'a) Yes, significant decrease',
                'slight':      'b) Yes, slight decrease',
                'stable':      'c) No, performance is stable',
                'improved':    'd) No, performance has improved',
              },
              onChanged: (v) => setState(() => _perfDecrease = v),
            ),
            if (_perfDecrease == 'significant' || _perfDecrease == 'slight') ...[
              const SizedBox(height: 24),
              const _SectionLabel('3. Describe the nature of the performance decrease:'),
              const SizedBox(height: 8),
              _InputField(
                controller: _perfDescCtrl,
                hint: 'e.g. Lower speed, reduced endurance, missed lifts…',
                maxLines: 3,
              ),
            ],
          ],

          const SizedBox(height: 32),
          if (_error != null) ...[
            _Notice(icon: Icons.error_outline_rounded, iconColor: kDanger, text: _error!),
            const SizedBox(height: 12),
          ],
          if (_alreadyLogged) ...[
            const _Notice(
              icon: Icons.check_circle_rounded,
              iconColor: kSuccess,
              text: 'Recovery already logged today. The next entry unlocks after midnight.',
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_submitting || _alreadyLogged) ? null : () { hapticConfirm(); _submit(); },
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kTextSecondary))
                  : Text(_alreadyLogged ? 'Logged for today' : 'Save wellness log'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

/// Major section title (e.g. "Sleep details") with an optional caption.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.4)),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 2),
        Text(subtitle!, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
      ],
    ],
  );
}

/// Label above a group or question: 13 w600 secondary, sentence case.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary, height: 1.35),
    ),
  );
}

/// One flat card holding several rows, separated by hairlines.
class _Group extends StatelessWidget {
  final List<Widget> children;
  final double dividerIndent;
  const _Group({required this.children, this.dividerIndent = 16});

  @override
  Widget build(BuildContext context) => Material(
    color: kCard,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kRadius),
      side: const BorderSide(color: kBorder, width: 0.6),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 0.6, indent: dividerIndent),
          children[i],
        ],
      ],
    ),
  );
}

/// Status / info line: a small coloured icon carries the meaning, the text
/// stays neutral.
class _Notice extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  const _Notice({required this.icon, required this.iconColor, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(kRadiusSm),
      border: Border.all(color: kBorder, width: 0.6),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, color: kTextSecondary, height: 1.4)),
        ),
      ],
    ),
  );
}

class _RatingSlider extends StatelessWidget {
  final String label;
  final int    value;
  final ValueChanged<int> onChanged;
  const _RatingSlider({required this.label, required this.value, required this.onChanged});

  // Kept as a small status dot next to the value: green = good, amber =
  // moderate, red = poor.
  Color get _color {
    if (value <= 2) return kSuccess;
    if (value == 3) return kWarn;
    return kDanger;
  }

  String get _label {
    switch (value) {
      case 1: return 'Excellent';
      case 2: return 'Good';
      case 3: return 'Moderate';
      case 4: return 'Poor';
      default: return 'Very Poor';
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 16, color: kTextPrimary, fontWeight: FontWeight.w500)),
            ),
            Container(width: 8, height: 8, decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('$value', style: const TextStyle(fontSize: 15, color: kTextPrimary, fontWeight: FontWeight.w700)),
            Text(' · $_label', style: const TextStyle(fontSize: 14, color: kTextSecondary)),
          ],
        ),
        Slider(
          min: 1, max: 5, divisions: 4,
          value: value.toDouble(),
          onChanged: (v) {
            final next = v.round();
            if (next != value) hapticSelect();
            onChanged(next);
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 Excellent', style: TextStyle(fontSize: 12, color: kTextMuted)),
              Text('5 Very poor', style: TextStyle(fontSize: 12, color: kTextMuted)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _TimePickerTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label, $value. Change time',
    excludeSemantics: true,
    child: Material(
      color: kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusSm),
        side: const BorderSide(color: kBorder, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () { hapticSelect(); onTap(); },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: kTextSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: kTextPrimary, letterSpacing: -0.4)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Read-only label / value row inside a [_Group].
class _ValueRow extends StatelessWidget {
  final String label;
  final String value;
  const _ValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 52),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15, color: kTextSecondary))),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kTextPrimary)),
        ],
      ),
    ),
  );
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final bool   value;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 56),
    padding: const EdgeInsets.only(left: 16, right: 8),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(kRadius),
      border: Border.all(color: kBorder, width: 0.6),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 16, color: kTextPrimary, fontWeight: FontWeight.w500)),
        ),
        Switch(
          value: value,
          onChanged: (v) { hapticSelect(); onChanged(v); },
        ),
      ],
    ),
  );
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String  hint;
  final String? label;
  final int     maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  const _InputField({
    required this.controller, required this.hint, this.label, this.maxLines = 1,
    this.keyboardType, this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label != null) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(label!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextSecondary)),
        ),
        const SizedBox(height: 6),
      ],
      TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(color: kTextPrimary, fontSize: 16),
        decoration: InputDecoration(hintText: hint),
      ),
    ],
  );
}

/// Label + borderless text field on one row, for use inside a [_Group].
class _InlineField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _InlineField({required this.controller, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 52),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(fontSize: 16, color: kTextPrimary, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: kTextPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: hint,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Single-choice list: one card, one row per option, a neutral radio mark on
/// the left and the selected row in bold.
class _OptionGroup extends StatelessWidget {
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  const _OptionGroup({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) => _Group(
    dividerIndent: 48,
    children: options.entries.map((e) {
      final selected = value == e.key;
      return _OptionRow(
        text: e.value,
        selected: selected,
        icon: selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
        onTap: () => onChanged(e.key),
      );
    }).toList(),
  );
}

class _MultiOptionGroup extends StatelessWidget {
  final Set<String> values;
  final Map<String, String> options;
  final ValueChanged<Set<String>> onChanged;
  const _MultiOptionGroup({required this.values, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) => _Group(
    dividerIndent: 48,
    children: options.entries.map((e) {
      final selected = values.contains(e.key);
      return _OptionRow(
        text: e.value,
        selected: selected,
        icon: selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
        onTap: () {
          final updated = Set<String>.from(values);
          if (selected) {
            updated.remove(e.key);
          } else {
            if (e.key == 'none') {
              updated.clear();
            } else {
              updated.remove('none');
            }
            updated.add(e.key);
          }
          onChanged(updated);
        },
      );
    }).toList(),
  );
}

class _OptionRow extends StatelessWidget {
  final String text;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  const _OptionRow({required this.text, required this.selected, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: () { hapticSelect(); onTap(); },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? kTextPrimary : kTextMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    color: kTextPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
