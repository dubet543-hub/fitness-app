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
          colorScheme: const ColorScheme.dark(
            primary: kAccent,
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
      const SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle_outline_rounded, color: kBg, size: 18),
          SizedBox(width: 10),
          Text('Sleep log saved'),
        ]),
        duration: Duration(seconds: 2),
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
        leading: IconButton(
          icon: const BackButtonIcon(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Sleep monitor'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 40),
        children: [

          // ── Sleep Quality Summary ──────────────────────────────────────────
          _SleepSummaryCard(
            night: _night,
            bedTime: _fmtTime(_timeToBed),
            wakeTime: _fmtTime(_wakeUpTime),
          ),
          const SizedBox(height: 28),

          // ── Q1: Time to Bed ───────────────────────────────────────────────
          const _SectionLabel('1. Time to bed'),
          const SizedBox(height: 8),
          _TimePickerTile(
            label: 'Bedtime',
            value: _fmtTime(_timeToBed),
            icon: Icons.bedtime_outlined,
            onTap: () => _pickTime(_Clock.bed),
          ),
          const SizedBox(height: 24),

          // ── Q2: Fall Asleep Duration ──────────────────────────────────────
          const _SectionLabel('2. Approximately how long did it take you to fall asleep?'),
          const SizedBox(height: 8),
          _MinuteStepper(
            value: _fallAsleepMins,
            unit: 'minutes',
            min: 0,
            max: 120,
            step: 5,
            onChanged: (v) => setState(() => _fallAsleepMins = v),
          ),
          const SizedBox(height: 24),

          // ── Q3: Wake-up Time ──────────────────────────────────────────────
          const _SectionLabel('3. Wake-up & out of bed'),
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
          const SizedBox(height: 24),

          // ── Q4: Total Time in Bed (auto-calculated) ───────────────────────
          const _SectionLabel('4. Total time in bed'),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.schedule_rounded,
            label: 'Bedtime → out of bed',
            value: formatHhMm(_night.timeInBedMinutes),
          ),
          const SizedBox(height: 24),

          // ── Q5: Disturbances ──────────────────────────────────────────────
          const _SectionLabel('5. Disturbances during sleep'),
          const SizedBox(height: 8),
          _YesNoTile(
            value: _hadDisturbance,
            onChanged: (v) => setState(() => _hadDisturbance = v),
          ),
          if (_hadDisturbance) ...[
            const SizedBox(height: 12),
            _InputField(
              controller: _disturbanceCtrl,
              hint: 'Describe disturbance (e.g. Noise, Cramps, Stress…)',
              maxLines: 2,
            ),
          ],
          const SizedBox(height: 24),

          // ── Q6: Awake Duration after Disturbance (conditional) ────────────
          if (_hadDisturbance) ...[
            const _SectionLabel('6. How long were you awake after the disturbance?'),
            const SizedBox(height: 8),
            _MinuteStepper(
              value: _awakeAfterMins,
              unit: 'minutes',
              min: 0,
              max: 120,
              step: 5,
              onChanged: (v) => setState(() => _awakeAfterMins = v),
            ),
            const SizedBox(height: 24),
          ],

          // ── Q7: Room Conditions ───────────────────────────────────────────
          const _SectionLabel('7. Room conditions'),
          const SizedBox(height: 8),
          _RoomConditionRow(
            tempCtrl:  _tempCtrl,
            noiseCtrl: _noiseCtrl,
            lightCtrl: _lightCtrl,
          ),

          const SizedBox(height: 32),

          // ── Save Button ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () { hapticConfirm(); _save(); },
              child: const Text('Save sleep log'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared card shape ─────────────────────────────────────────────────────────

ShapeBorder _cardShape(double radius) => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(radius),
  side: const BorderSide(color: kBorder, width: 0.6),
);

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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: ShapeDecoration(color: kCard, shape: _cardShape(kRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tonight\'s sleep',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextSecondary),
                ),
              ),
              // Quality status: dot in the status colour + the word.
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: _qualityColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                _qualityLabel,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Effective sleep big number
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatHhMm(night.sleepMinutes),
                      style: const TextStyle(
                        fontSize: 40, fontWeight: FontWeight.w700,
                        color: kTextPrimary, letterSpacing: -1.2, height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('sleep time (hh:mm)',
                        style: TextStyle(fontSize: 13, color: kTextSecondary)),
                  ],
                ),
              ),
              // Time markers
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _TimeLabel(icon: Icons.bedtime_outlined, label: 'Bed', time: bedTime),
                  const SizedBox(height: 6),
                  _TimeLabel(icon: Icons.wb_sunny_outlined, label: 'Wake', time: wakeTime),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 0.6),
          const SizedBox(height: 14),
          // Efficiency bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sleep efficiency', style: TextStyle(fontSize: 13, color: kTextSecondary)),
                  Text(
                    '${efficiency.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: efficiency / 100,
                  minHeight: 4,
                  backgroundColor: kBorderBright,
                  valueColor: const AlwaysStoppedAnimation<Color>(kSleep),
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
      Icon(icon, size: 14, color: kTextMuted),
      const SizedBox(width: 4),
      Text('$label  ', style: const TextStyle(fontSize: 12, color: kTextMuted)),
      Text(time, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
    ],
  );
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: kTextSecondary, height: 1.35,
        ),
      ),
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
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label, $value. Change time',
    excludeSemantics: true,
    child: Material(
      color: kCard,
      shape: _cardShape(kRadiusSm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () { hapticSelect(); onTap(); },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: kTextSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
                    const SizedBox(height: 2),
                    Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: kTextMuted),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: ShapeDecoration(color: kCard, shape: _cardShape(kRadiusSm)),
      child: Row(
        children: [
          // Decrement
          _StepBtn(
            icon: Icons.remove_rounded,
            semanticLabel: 'Decrease',
            enabled: value > min,
            onTap: () { if (value > min) onChanged(value - step); },
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                '$value',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -1.0, height: 1.1),
              ),
              Text(unit, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
            ],
          ),
          const Spacer(),
          // Increment
          _StepBtn(
            icon: Icons.add_rounded,
            semanticLabel: 'Increase',
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
  final String     semanticLabel;
  final bool       enabled;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.semanticLabel, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: semanticLabel,
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusSm),
        side: BorderSide(color: enabled ? kBorderBright : kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? () { hapticSelect(); onTap(); } : null,
        child: SizedBox(
          width: 44, height: 44,
          child: Icon(icon, size: 20, color: enabled ? kTextPrimary : kTextMuted),
        ),
      ),
    ),
  );
}

// ── Info Tile (read-only) ─────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 56),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: ShapeDecoration(color: kCard, shape: _cardShape(kRadiusSm)),
    child: Row(
      children: [
        Icon(icon, size: 22, color: kTextSecondary),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 15, color: kTextSecondary)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.5),
        ),
      ],
    ),
  );
}

// ── Yes/No Tile ───────────────────────────────────────────────────────────────
// Segmented look: the selected half is a light fill with dark text.

class _YesNoTile extends StatelessWidget {
  final bool   value;
  final ValueChanged<bool> onChanged;
  const _YesNoTile({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _ChoiceChip(label: 'No', selected: !value, onTap: () => onChanged(false))),
      const SizedBox(width: 10),
      Expanded(child: _ChoiceChip(label: 'Yes', selected: value, onTap: () => onChanged(true))),
    ],
  );
}

class _ChoiceChip extends StatelessWidget {
  final String   label;
  final bool     selected;
  final VoidCallback onTap;
  const _ChoiceChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () { if (!selected) hapticSelect(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? kTextPrimary : kCard,
          borderRadius: BorderRadius.circular(kRadiusSm),
          border: Border.all(color: selected ? kTextPrimary : kBorder, width: selected ? 1 : 0.6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: selected ? kBg : kTextSecondary,
          ),
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
    style: const TextStyle(color: kTextPrimary, fontSize: 16),
    decoration: InputDecoration(hintText: hint),
  );
}

// ── Room Condition Row ────────────────────────────────────────────────────────
// One grouped card: label on the left, borderless field on the right,
// hairlines between rows.

class _RoomConditionRow extends StatelessWidget {
  final TextEditingController tempCtrl;
  final TextEditingController noiseCtrl;
  final TextEditingController lightCtrl;
  const _RoomConditionRow({required this.tempCtrl, required this.noiseCtrl, required this.lightCtrl});

  @override
  Widget build(BuildContext context) => Material(
    color: kCard,
    shape: _cardShape(kRadius),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        _RoomTile(
          label: 'Temperature',
          hint: 'e.g. 20°C, Cold, Warm',
          controller: tempCtrl,
        ),
        const Divider(height: 0.6, indent: 16),
        _RoomTile(
          label: 'Noise',
          hint: 'e.g. Silent, Fan, Traffic',
          controller: noiseCtrl,
        ),
        const Divider(height: 0.6, indent: 16),
        _RoomTile(
          label: 'Light',
          hint: 'e.g. Pitch Black, Dim, Bright',
          controller: lightCtrl,
        ),
      ],
    ),
  );
}

class _RoomTile extends StatelessWidget {
  final String     label;
  final String     hint;
  final TextEditingController controller;
  const _RoomTile({required this.label, required this.hint, required this.controller});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 54),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: kTextPrimary)),
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
