import 'package:flutter/material.dart';
import '../api_service.dart';
import '../core/theme.dart';
import '../services/local_log_store.dart';

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
  TimeOfDay _timeToBed   = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _wakeUpTime  = const TimeOfDay(hour: 6,  minute: 0);
  bool      _disturbances = false;
  final _disturbanceCtrl  = TextEditingController();
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

  double get _sleepDuration {
    final bedMins  = _timeToBed.hour  * 60 + _timeToBed.minute;
    final wakeMins = _wakeUpTime.hour * 60 + _wakeUpTime.minute;
    double diff = (wakeMins - bedMins).toDouble();
    if (diff < 0) diff += 24 * 60;
    return (diff / 60 * 100).roundToDouble() / 100;
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isBed) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isBed ? _timeToBed : _wakeUpTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: kAccent,
            surface: kSurface,
            onSurface: kTextPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => isBed ? _timeToBed = picked : _wakeUpTime = picked);
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      final payload = <String, dynamic>{
        'sleep':    _sleepScore,
        'wellness': _wellness,
        'soreness': _soreness,
        'fatigue':  _fatigue,
        'sleepTimeToBed':  _fmt(_timeToBed),
        'sleepWakeUpTime': _fmt(_wakeUpTime),
        'sleepDisturbances': _disturbances,
        if (_disturbances && _disturbanceCtrl.text.isNotEmpty)
          'sleepDisturbanceDetails': _disturbanceCtrl.text.trim(),
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
      await LocalLogStore.markRecoveryLogged();
      if (mounted) {
        setState(() => _alreadyLogged = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wellness log saved'), backgroundColor: Color(0xFF22C55E)),
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
    _roomTempCtrl.dispose();
    _roomNoiseCtrl.dispose();
    _roomLightCtrl.dispose();
    _perfDescCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: const Text('WELLNESS LOG', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4)),
        iconTheme: const IconThemeData(color: kTextPrimary),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Readiness Ratings ───────────────────────────────────────────
          _SectionHeader(title: 'Daily Readiness', subtitle: '1 = Excellent · 5 = Very Poor'),
          const SizedBox(height: 12),
          _RatingSlider(label: 'Sleep Quality',  value: _sleepScore, onChanged: (v) => setState(() => _sleepScore = v)),
          _RatingSlider(label: 'Wellness',       value: _wellness,   onChanged: (v) => setState(() => _wellness   = v)),
          _RatingSlider(label: 'Muscle Soreness',value: _soreness,   onChanged: (v) => setState(() => _soreness   = v)),
          _RatingSlider(label: 'Fatigue',        value: _fatigue,    onChanged: (v) => setState(() => _fatigue    = v)),

          const SizedBox(height: 24),
          // ── Sleep Details ───────────────────────────────────────────────
          _SectionHeader(title: 'Sleep Details'),
          const SizedBox(height: 12),

          // Time to bed / Wake-up
          Row(
            children: [
              Expanded(child: _TimePickerTile(
                label: 'Time to Bed',
                value: _fmt(_timeToBed),
                onTap: () => _pickTime(true),
              )),
              const SizedBox(width: 12),
              Expanded(child: _TimePickerTile(
                label: 'Wake-up Time',
                value: _fmt(_wakeUpTime),
                onTap: () => _pickTime(false),
              )),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.bedtime_outlined, size: 16, color: kTextSecondary),
                const SizedBox(width: 8),
                Text('Sleep Duration', style: const TextStyle(fontSize: 13, color: kTextSecondary)),
                const Spacer(),
                Text('${_sleepDuration.toStringAsFixed(2)} hrs',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Disturbances
          _ToggleTile(
            label: 'Sleep Disturbances?',
            value: _disturbances,
            onChanged: (v) => setState(() => _disturbances = v),
          ),
          if (_disturbances) ...[
            const SizedBox(height: 8),
            _InputField(controller: _disturbanceCtrl, hint: 'Describe disturbance (e.g. Cramps, Noisy)'),
          ],
          const SizedBox(height: 12),

          // Room Conditions
          _SectionLabel('Room Conditions'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _InputField(controller: _roomTempCtrl,  hint: 'Temperature (e.g. 20°C)',   label: 'Temp')),
              const SizedBox(width: 8),
              Expanded(child: _InputField(controller: _roomNoiseCtrl, hint: 'Noise (e.g. Silent)',       label: 'Noise')),
              const SizedBox(width: 8),
              Expanded(child: _InputField(controller: _roomLightCtrl, hint: 'Light (e.g. Pitch Black)',  label: 'Light')),
            ],
          ),

          // ── Extended Questions (when wellness >= 3 OR fatigue >= 3) ────
          if (_showExtended) ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kAccent.withValues(alpha: 0.30)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: kAccent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Wellness or fatigue concern detected — please complete the additional questions below.',
                      style: TextStyle(fontSize: 12, color: kTextSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Mood Questions ────────────────────────────────────────
            _SectionHeader(title: 'Mood Assessment'),
            const SizedBox(height: 12),

            _SectionLabel('1. Current motivation level for training & competition'),
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
            const SizedBox(height: 16),

            _SectionLabel('2. Significant changes in appetite recently?'),
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
            const SizedBox(height: 16),

            _SectionLabel('3. External factors impacting your mood? (Select all that apply)'),
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
            const SizedBox(height: 16),

            _SectionLabel('4. Do you need to speak with a sports psychologist this week?'),
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
            const SizedBox(height: 24),

            // ── Fatigue Questions ──────────────────────────────────────
            _SectionHeader(title: 'Fatigue Assessment'),
            const SizedBox(height: 12),

            _SectionLabel('1. Physical symptoms of fatigue you are currently experiencing? (Select all)'),
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
            const SizedBox(height: 16),

            _SectionLabel('2. Performance change in recent training / competitions?'),
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
              const SizedBox(height: 12),
              _SectionLabel('3. Describe the nature of the performance decrease:'),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF450A0A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF87171)),
              ),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 13)),
            ),
            const SizedBox(height: 12),
          ],
          if (_alreadyLogged) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kAccent.withValues(alpha: 0.30)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, size: 18, color: kAccent),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Recovery already logged today. The next entry unlocks after midnight.',
                    style: TextStyle(fontSize: 12.5, color: kTextSecondary),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (_submitting || _alreadyLogged) ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                  : Text(_alreadyLogged ? 'Logged for Today' : 'Save Wellness Log',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.3)),
      if (subtitle != null) ...[
        const SizedBox(height: 2),
        Text(subtitle!, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
      ],
    ],
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary),
  );
}

class _RatingSlider extends StatelessWidget {
  final String label;
  final int    value;
  final ValueChanged<int> onChanged;
  const _RatingSlider({required this.label, required this.value, required this.onChanged});

  Color get _color {
    if (value <= 2) return const Color(0xFF22C55E);
    if (value == 3) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
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
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: kTextPrimary, fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text('$value — $_label', style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _color,
            thumbColor: _color,
            inactiveTrackColor: kBorder,
            overlayColor: _color.withValues(alpha: 0.12),
            trackHeight: 4,
          ),
          child: Slider(
            min: 1, max: 5, divisions: 4,
            value: value.toDouble(),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('1 Excellent', style: TextStyle(fontSize: 10, color: kTextMuted)),
            Text('5 Very Poor', style: TextStyle(fontSize: 10, color: kTextMuted)),
          ],
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 16, color: kAccent),
              const SizedBox(width: 6),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary)),
            ],
          ),
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
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder),
    ),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: kTextPrimary, fontWeight: FontWeight.w600)),
        const Spacer(),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: kAccent,
          activeTrackColor: kAccent.withValues(alpha: 0.25),
          inactiveThumbColor: kTextMuted,
          inactiveTrackColor: kBorder,
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
  const _InputField({required this.controller, required this.hint, this.label, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label != null) ...[
        Text(label!, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
        const SizedBox(height: 4),
      ],
      TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: kTextPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kTextMuted, fontSize: 12),
          filled: true,
          fillColor: kCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kAccent)),
        ),
      ),
    ],
  );
}

class _OptionGroup extends StatelessWidget {
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  const _OptionGroup({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
    children: options.entries.map((e) {
      final selected = value == e.key;
      return GestureDetector(
        onTap: () => onChanged(e.key),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? kAccent.withValues(alpha: 0.12) : kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? kAccent : kBorder),
          ),
          child: Text(
            e.value,
            style: TextStyle(
              fontSize: 13,
              color: selected ? kAccent : kTextPrimary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
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
  Widget build(BuildContext context) => Column(
    children: options.entries.map((e) {
      final selected = values.contains(e.key);
      return GestureDetector(
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
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? kAccent.withValues(alpha: 0.12) : kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? kAccent : kBorder),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 18,
                color: selected ? kAccent : kTextMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 13,
                    color: selected ? kAccent : kTextPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList(),
  );
}
