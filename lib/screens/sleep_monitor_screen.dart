import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/sleep_metrics.dart';
import '../services/entitlements.dart';
import '../widgets/feature_gate.dart';

/// Which clock a time picker is editing.
enum _Clock { bed, wake, outOfBed }

class SleepMonitorScreen extends StatefulWidget {
  const SleepMonitorScreen({super.key});

  @override
  State<SleepMonitorScreen> createState() => _SleepMonitorScreenState();
}

class _SleepMonitorScreenState extends State<SleepMonitorScreen> {
  // Q1 – Time to bed
  TimeOfDay _timeToBed = const TimeOfDay(hour: 22, minute: 30);

  // Q2 – Minutes to fall asleep
  int _fallAsleepMins = 15;

  // Q3 – Wake-up time, and the time actually got out of bed. The two differ by
  // however long was spent lying in bed awake, which is what separates sleep
  // time from time in bed in the efficiency formula.
  TimeOfDay _wakeUpTime  = const TimeOfDay(hour: 6, minute: 30);
  TimeOfDay _outOfBedTime = const TimeOfDay(hour: 6, minute: 40);

  // Q5 – Disturbances
  bool _hadDisturbance = false;
  final _disturbanceCtrl = TextEditingController();

  // Q6 – Awake after disturbance (minutes)
  int _awakeAfterMins = 10;

  // Q7 – Room conditions
  final _tempCtrl  = TextEditingController();
  final _noiseCtrl = TextEditingController();
  final _lightCtrl = TextEditingController();

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int _mins(TimeOfDay t) => t.hour * 60 + t.minute;

  /// Tonight's log expressed as a [SleepNight], so sleep time, time in bed and
  /// efficiency all come from the shared sheet formulae rather than being
  /// recomputed here.
  SleepNight get _night => nightFromLog(
        d: 'tonight',
        timeToBed: _mins(_timeToBed),
        latencyMinutes: _fallAsleepMins,
        wokeUp: _mins(_wakeUpTime),
        outOfBed: _mins(_outOfBedTime),
        awakeMinutes: _hadDisturbance ? _awakeAfterMins : 0,
      );

  Future<void> _pickTime(_Clock which) async {
    final current = switch (which) {
      _Clock.bed      => _timeToBed,
      _Clock.wake     => _wakeUpTime,
      _Clock.outOfBed => _outOfBedTime,
    };
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: kSleep,
            surface: kSurface,
            onSurface: kTextPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      switch (which) {
        case _Clock.bed:      _timeToBed = picked;
        case _Clock.wake:     _wakeUpTime = picked;
        case _Clock.outOfBed: _outOfBedTime = picked;
      }
    });
  }

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle_outline_rounded, color: kSleep, size: 18),
          const SizedBox(width: 10),
          Text('Sleep log saved', style: TextStyle(color: kTextPrimary)),
        ]),
        backgroundColor: kCard,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _disturbanceCtrl.dispose();
    _tempCtrl.dispose();
    _noiseCtrl.dispose();
    _lightCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => FeatureGuard(
      feature: FeatureKeys.recovery, child: _gatedBody(context));

  Widget _gatedBody(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
          color: kTextPrimary,
        ),
        title: Text(
          'SLEEP MONITOR',
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: kTextSecondary, letterSpacing: 1.4,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [

          // ── Sleep Quality Summary ──────────────────────────────────────────
          _SleepSummaryCard(
            night: _night,
            bedTime: _fmtTime(_timeToBed),
            wakeTime: _fmtTime(_wakeUpTime),
          ),
          const SizedBox(height: 24),

          // ── Q1: Time to Bed ───────────────────────────────────────────────
          _SectionLabel('1. Time to Bed'),
          const SizedBox(height: 8),
          _TimePickerTile(
            label: 'Bedtime',
            value: _fmtTime(_timeToBed),
            icon: Icons.bedtime_rounded,
            onTap: () => _pickTime(_Clock.bed),
          ),
          const SizedBox(height: 16),

          // ── Q2: Fall Asleep Duration ──────────────────────────────────────
          _SectionLabel('2. Approximately how long did it take you to fall asleep?'),
          const SizedBox(height: 8),
          _MinuteStepper(
            value: _fallAsleepMins,
            unit: 'minutes',
            min: 0,
            max: 120,
            step: 5,
            onChanged: (v) => setState(() => _fallAsleepMins = v),
          ),
          const SizedBox(height: 16),

          // ── Q3: Wake-up Time ──────────────────────────────────────────────
          _SectionLabel('3. Wake-up & Out of Bed'),
          const SizedBox(height: 8),
          _TimePickerTile(
            label: 'Wake-up',
            value: _fmtTime(_wakeUpTime),
            icon: Icons.wb_sunny_outlined,
            onTap: () => _pickTime(_Clock.wake),
          ),
          const SizedBox(height: 8),
          _TimePickerTile(
            label: 'Got out of bed',
            value: _fmtTime(_outOfBedTime),
            icon: Icons.king_bed_outlined,
            onTap: () => _pickTime(_Clock.outOfBed),
          ),
          const SizedBox(height: 16),

          // ── Q4: Total Time in Bed (auto-calculated) ───────────────────────
          _SectionLabel('4. Total Time in Bed'),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.schedule_rounded,
            label: 'Bedtime → out of bed',
            value: formatHhMm(_night.timeInBedMinutes),
            color: kSleep,
          ),
          const SizedBox(height: 16),

          // ── Q5: Disturbances ──────────────────────────────────────────────
          _SectionLabel('5. Disturbances during sleep'),
          const SizedBox(height: 8),
          _YesNoTile(
            value: _hadDisturbance,
            onChanged: (v) => setState(() => _hadDisturbance = v),
          ),
          if (_hadDisturbance) ...[
            const SizedBox(height: 8),
            _InputField(
              controller: _disturbanceCtrl,
              hint: 'Describe disturbance (e.g. Noise, Cramps, Stress…)',
              maxLines: 2,
            ),
          ],
          const SizedBox(height: 16),

          // ── Q6: Awake Duration after Disturbance (conditional) ────────────
          if (_hadDisturbance) ...[
            _SectionLabel('6. How long were you awake after the disturbance?'),
            const SizedBox(height: 8),
            _MinuteStepper(
              value: _awakeAfterMins,
              unit: 'minutes',
              min: 0,
              max: 120,
              step: 5,
              onChanged: (v) => setState(() => _awakeAfterMins = v),
            ),
            const SizedBox(height: 16),
          ],

          // ── Q7: Room Conditions ───────────────────────────────────────────
          _SectionLabel('7. Room Conditions'),
          const SizedBox(height: 10),
          _RoomConditionRow(
            tempCtrl:  _tempCtrl,
            noiseCtrl: _noiseCtrl,
            lightCtrl: _lightCtrl,
          ),

          const SizedBox(height: 32),

          // ── Save Button ───────────────────────────────────────────────────
          SizedBox(
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kSleep,
                foregroundColor: kOnAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _save,
              child: const Text(
                'Save Sleep Log',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sleep Summary Card ────────────────────────────────────────────────────────

class _SleepSummaryCard extends StatelessWidget {
  final SleepNight night;
  final String bedTime;
  final String wakeTime;
  const _SleepSummaryCard({
    required this.night,
    required this.bedTime,
    required this.wakeTime,
  });

  double get _sleepHours => night.sleepHours;

  Color get _qualityColor {
    if (_sleepHours >= 8.0) return kAccent;
    if (_sleepHours >= 7.0) return kSky;
    if (_sleepHours >= 6.0) return kWarn;
    return kDanger;
  }

  String get _qualityLabel {
    if (_sleepHours >= 8.0) return 'Excellent';
    if (_sleepHours >= 7.0) return 'Good';
    if (_sleepHours >= 6.0) return 'Fair';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    final efficiency = (night.efficiency * 100).clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kSleep.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kSleep.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bedtime_rounded, size: 18, color: kSleep),
              ),
              const SizedBox(width: 10),
              Text(
                'TONIGHT\'S SLEEP',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.2),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _qualityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _qualityLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _qualityColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Effective sleep big number
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatHhMm(night.sleepMinutes),
                      style: TextStyle(
                        fontSize: 42, fontWeight: FontWeight.w800,
                        color: _qualityColor, letterSpacing: -1.5, height: 1.0,
                      ),
                    ),
                    Text('sleep time (hh:mm)',
                        style: TextStyle(fontSize: 11, color: kTextSecondary)),
                  ],
                ),
              ),
              // Time markers
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _TimeLabel(icon: Icons.bedtime_outlined, label: 'Bed', time: bedTime),
                  const SizedBox(height: 8),
                  _TimeLabel(icon: Icons.wb_sunny_outlined, label: 'Wake', time: wakeTime),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Efficiency bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sleep Efficiency', style: TextStyle(fontSize: 11, color: kTextSecondary)),
                  Text(
                    '${efficiency.toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _qualityColor),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: efficiency / 100,
                  minHeight: 5,
                  backgroundColor: kBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(_qualityColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   time;
  const _TimeLabel({required this.icon, required this.label, required this.time});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: kTextMuted),
      const SizedBox(width: 4),
      Text('$label  ', style: TextStyle(fontSize: 11, color: kTextMuted)),
      Text(time, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
    ],
  );
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600,
      color: kTextPrimary,
    ),
  );
}

// ── Time Picker Tile ──────────────────────────────────────────────────────────

class _TimePickerTile extends StatelessWidget {
  final String     label;
  final String     value;
  final IconData   icon;
  final VoidCallback onTap;
  const _TimePickerTile({required this.label, required this.value, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kSleep.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: kSleep),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: kTextSecondary)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.5)),
            ],
          ),
          const Spacer(),
          Icon(Icons.edit_outlined, size: 16, color: kTextMuted),
        ],
      ),
    ),
  );
}

// ── Minute Stepper ────────────────────────────────────────────────────────────

class _MinuteStepper extends StatelessWidget {
  final int    value;
  final String unit;
  final int    min;
  final int    max;
  final int    step;
  final ValueChanged<int> onChanged;
  const _MinuteStepper({
    required this.value, required this.unit,
    required this.min,   required this.max,
    required this.step,  required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          // Decrement
          _StepBtn(
            icon: Icons.remove_rounded,
            enabled: value > min,
            onTap: () { if (value > min) onChanged(value - step); },
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                '$value',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -1.0),
              ),
              Text(unit, style: TextStyle(fontSize: 11, color: kTextSecondary)),
            ],
          ),
          const Spacer(),
          // Increment
          _StepBtn(
            icon: Icons.add_rounded,
            enabled: value < max,
            onTap: () { if (value < max) onChanged(value + step); },
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData   icon;
  final bool       enabled;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: enabled ? kSleep.withValues(alpha: 0.12) : kBorder.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: enabled ? kSleep.withValues(alpha: 0.35) : kBorder),
      ),
      child: Icon(icon, size: 20, color: enabled ? kSleep : kTextMuted),
    ),
  );
}

// ── Info Tile (read-only) ─────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  const _InfoTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kBorder),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12, color: kTextSecondary)),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5),
        ),
      ],
    ),
  );
}

// ── Yes/No Tile ───────────────────────────────────────────────────────────────

class _YesNoTile extends StatelessWidget {
  final bool   value;
  final ValueChanged<bool> onChanged;
  const _YesNoTile({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _ChoiceChip(label: 'No', selected: !value,  color: kAccent,  onTap: () => onChanged(false))),
      const SizedBox(width: 10),
      Expanded(child: _ChoiceChip(label: 'Yes', selected: value, color: kDanger, onTap: () => onChanged(true))),
    ],
  );
}

class _ChoiceChip extends StatelessWidget {
  final String   label;
  final bool     selected;
  final Color    color;
  final VoidCallback onTap;
  const _ChoiceChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.15) : kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? color : kBorder, width: selected ? 1.5 : 1.0),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700,
          color: selected ? color : kTextSecondary,
        ),
      ),
    ),
  );
}

// ── Input Field ───────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int    maxLines;
  const _InputField({required this.controller, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLines: maxLines,
    style: TextStyle(color: kTextPrimary, fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: kTextMuted, fontSize: 12),
      filled: true,
      fillColor: kCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border:         OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kBorder)),
      enabledBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kBorder)),
      focusedBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kSleep, width: 1.5)),
    ),
  );
}

// ── Room Condition Row ────────────────────────────────────────────────────────

class _RoomConditionRow extends StatelessWidget {
  final TextEditingController tempCtrl;
  final TextEditingController noiseCtrl;
  final TextEditingController lightCtrl;
  const _RoomConditionRow({required this.tempCtrl, required this.noiseCtrl, required this.lightCtrl});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _RoomTile(
        icon: Icons.thermostat_rounded,
        label: 'Temperature',
        hint: 'e.g. 20°C, Cold, Warm',
        controller: tempCtrl,
        color: kOrange,
      ),
      const SizedBox(height: 8),
      _RoomTile(
        icon: Icons.volume_down_rounded,
        label: 'Noise',
        hint: 'e.g. Silent, Fan, Traffic',
        controller: noiseCtrl,
        color: kSky,
      ),
      const SizedBox(height: 8),
      _RoomTile(
        icon: Icons.light_mode_outlined,
        label: 'Light',
        hint: 'e.g. Pitch Black, Dim, Bright',
        controller: lightCtrl,
        color: kWarn,
      ),
    ],
  );
}

class _RoomTile extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final String     hint;
  final TextEditingController controller;
  final Color      color;
  const _RoomTile({required this.icon, required this.label, required this.hint, required this.controller, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kBorder),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(fontSize: 12, color: kTextSecondary)),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            style: TextStyle(color: kTextPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: kTextMuted, fontSize: 12),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    ),
  );
}
