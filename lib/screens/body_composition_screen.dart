import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../api_service.dart';
import '../services/local_log_store.dart';
import '../services/entitlements.dart';
import '../widgets/feature_gate.dart';

// ─── Data Model ────────────────────────────────────────────────────────────

class _BCA {
  final bool   isMale;
  final double weightKg;
  final double heightCm;

  // Primary composition
  final double bfPercent;
  final double bfKg;
  final double lbm;

  // LBM components (kg)
  final double bmc;           // Bone Mineral Content  (6.5% of LBM)
  final double lst;           // Lean Soft Tissue      (LBM × 0.935)
  final double tsm;           // Total Skeletal Muscle (58.29% of LST)
  final double essentialOrgans;
  final double skinConnective;
  final double nonMuscleFluid;

  // Skeletal muscle split
  final double asm;   // Appendicular (75% of TSM)
  final double axial; // Axial        (25% of TSM)

  // Key ratios
  final double smmPercent;          // TSM / Weight × 100
  final double smi;                 // TSM / height_m²
  final double relativeAsm;         // ASM / Weight × 100
  final double mbr;                 // LBM / BMC
  final double ffmi;                // LBM / height_m²
  final double appendicularToTotal; // ASM / Weight × 100
  final double axialToTotal;        // Axial / Weight × 100

  const _BCA({
    required this.isMale,
    required this.weightKg,
    required this.heightCm,
    required this.bfPercent,
    required this.bfKg,
    required this.lbm,
    required this.bmc,
    required this.lst,
    required this.tsm,
    required this.essentialOrgans,
    required this.skinConnective,
    required this.nonMuscleFluid,
    required this.asm,
    required this.axial,
    required this.smmPercent,
    required this.smi,
    required this.relativeAsm,
    required this.mbr,
    required this.ffmi,
    required this.appendicularToTotal,
    required this.axialToTotal,
  });

  double get heightM => heightCm / 100;
}

// ─── Grade Helper ──────────────────────────────────────────────────────────

class _Grade {
  final String label;
  final Color  color;
  const _Grade(this.label, this.color);
}

// ─── Grading Functions (per formulae & interpretation PDFs) ────────────────

_Grade _gradeBF(double pct, bool male) {
  if (male) {
    if (pct < 5)  return _Grade('Below Essential', kDanger);
    if (pct <= 13) return _Grade('Elite / Athletic',      kSuccess);
    if (pct <= 17) return _Grade('Good / Competitive',    kInfo);
    if (pct <= 24) return _Grade('Moderate / Transition', kWarn);
    return _Grade('High', kDanger);
  } else {
    if (pct < 12)  return _Grade('Below Essential', kDanger);
    if (pct <= 20) return _Grade('Elite / Athletic',      kSuccess);
    if (pct <= 24) return _Grade('Good / Competitive',    kInfo);
    if (pct <= 31) return _Grade('Moderate / Transition', kWarn);
    return _Grade('High', kDanger);
  }
}

_Grade _gradeFFMI(double v, bool male) {
  if (male) {
    if (v < 18)  return _Grade('Below Average',              kDanger);
    if (v < 20)  return _Grade('Average / Untrained',        kWarn);
    if (v < 22)  return _Grade('Good / Athletic',            kInfo);
    if (v < 24)  return _Grade('Advanced / Excellent',       kSuccess);
    if (v <= 25) return _Grade('Elite Natural Limit',        kViolet);
    return _Grade('Exceptional Outlier', kViolet);
  } else {
    if (v < 15)  return _Grade('Below Average',              kDanger);
    if (v < 18)  return _Grade('Good Baseline',              kWarn);
    if (v < 20)  return _Grade('Advanced Athletic',          kInfo);
    if (v < 22)  return _Grade('Elite / Exceptional',        kSuccess);
    return _Grade('Exceptional', kViolet);
  }
}

_Grade _gradeSMM(double pct, bool male) {
  if (male) {
    if (pct < 39)  return _Grade('Deficient – Risk Zone',    kDanger);
    if (pct < 43)  return _Grade('Sub-Optimal / Lean',       kWarn);
    if (pct < 48)  return _Grade('Optimal / Athletic',       kSuccess);
    return _Grade('Elite / Hypertrophic', kInfo);
  } else {
    if (pct < 32)  return _Grade('Deficient – Risk Zone',    kDanger);
    if (pct < 36)  return _Grade('Sub-Optimal / Lean',       kWarn);
    if (pct < 40)  return _Grade('Optimal / Athletic',       kSuccess);
    return _Grade('Elite / Hypertrophic', kInfo);
  }
}

_Grade _gradeSMI(double v, bool male) {
  if (male) {
    if (v < 8.5)   return _Grade('Deficient – Risk Zone',    kDanger);
    if (v < 9.5)   return _Grade('Sub-Optimal / Lean',       kWarn);
    if (v <= 11.5) return _Grade('Optimal / Athletic',       kSuccess);
    return _Grade('Elite / Hypertrophic', kInfo);
  } else {
    if (v < 7.0)   return _Grade('Deficient – Risk Zone',    kDanger);
    if (v < 8.0)   return _Grade('Sub-Optimal / Lean',       kWarn);
    if (v <= 9.5)  return _Grade('Optimal / Athletic',       kSuccess);
    return _Grade('Elite / Hypertrophic', kInfo);
  }
}

_Grade _gradeRelASM(double pct, bool male) {
  if (male) {
    if (pct < 19.4) return _Grade('Clinical Risk (Sarcopenic)', kDanger);
    if (pct < 26.0) return _Grade('Low / Under-Conditioned',    kWarn);
    if (pct < 31.5) return _Grade('Average / Healthy Baseline', kInfo);
    if (pct < 35.0) return _Grade('Well-Conditioned',           kSuccess);
    return _Grade('Elite / Highly Conditioned', kViolet);
  } else {
    if (pct < 15.0) return _Grade('Clinical Risk (Sarcopenic)', kDanger);
    if (pct < 21.0) return _Grade('Low / Under-Conditioned',    kWarn);
    if (pct < 26.5) return _Grade('Average / Healthy Baseline', kInfo);
    if (pct < 30.0) return _Grade('Well-Conditioned',           kSuccess);
    return _Grade('Elite / Highly Conditioned', kViolet);
  }
}

_Grade _gradeMBR(double v) {
  if (v < 15) return _Grade('Critical – Under-Muscled', kDanger);
  if (v < 19) return _Grade('Weak / Sedentary',         kWarn);
  if (v < 24) return _Grade('Normal / Healthy Baseline', kInfo);
  return _Grade('Strong / Athletic Framework', kSuccess);
}

// Appendicular / axial muscle are fixed shares of total skeletal muscle (75% /
// 25%), so their % of body weight moves in lockstep with SMM %. The cut-offs
// are the SMM % bands scaled by those shares, keeping the grades consistent
// with the Skeletal Muscle % grade instead of pinning everyone at Grade 4.
List<double> _scaledSmmBands(bool male, double share) =>
    (male ? const [39.0, 43.0, 48.0] : const [32.0, 36.0, 40.0])
        .map((b) => b * share)
        .toList();

_Grade _gradeAppendicular(double pct, bool male) {
  final b = _scaledSmmBands(male, 0.75);
  if (pct < b[0]) return _Grade('Grade 4 – At Risk',        kDanger);
  if (pct < b[1]) return _Grade('Grade 3 – Compact',        kWarn);
  if (pct < b[2]) return _Grade('Grade 2 – Balanced',       kSuccess);
  return _Grade('Grade 1 – Distal Lever Dominant', kInfo);
}

_Grade _gradeAxial(double pct, bool male) {
  final b = _scaledSmmBands(male, 0.25);
  if (pct < b[0]) return _Grade('Grade 4 – Structural Insufficiency', kDanger);
  if (pct < b[1]) return _Grade('Grade 3 – Elongated / Locomotive',  kWarn);
  if (pct < b[2]) return _Grade('Grade 2 – Balanced Core Base',      kSuccess);
  return _Grade('Grade 1 – Rotational Anchor', kInfo);
}

// ─── Calculation Engine ────────────────────────────────────────────────────

_BCA? _compute({
  required bool   isMale,
  required double weightKg,
  required double heightCm,
  required double neckCm,
  required double abdomenCm,
  double? hipCm,
}) {
  final double ln10 = log(10);

  double bfPct;
  if (isMale) {
    // US Navy formula (cm): BF% = 86.010 × log10(abdomen-neck) − 70.041 × log10(height) + 36
    final diff = abdomenCm - neckCm;
    if (diff <= 0) return null;
    bfPct = 86.010 * (log(diff) / ln10) - 70.041 * (log(heightCm) / ln10) + 36.0;
  } else {
    if (hipCm == null || hipCm <= 0) return null;
    final sum = abdomenCm + hipCm - neckCm;
    if (sum <= 0) return null;
    bfPct = 163.305 * (log(sum) / ln10) - 97.684 * (log(heightCm) / ln10) - 78.387;
  }

  bfPct = bfPct.clamp(2.0, 50.0);

  final bfKg  = weightKg * bfPct / 100.0;
  final lbm   = weightKg - bfKg;

  // LBM Components
  final bmc             = lbm * 0.065;
  final lst             = lbm * 0.935;
  final tsm             = lst * 0.5829;
  final essentialOrgans = lst * 0.1230;
  final skinConn        = lst * 0.1123;
  final nonMuscleFluid  = lst * 0.1818;

  // Skeletal muscle split
  final asm   = tsm * 0.75;
  final axial = tsm * 0.25;

  final heightM = heightCm / 100.0;

  return _BCA(
    isMale:               isMale,
    weightKg:             weightKg,
    heightCm:             heightCm,
    bfPercent:            bfPct,
    bfKg:                 bfKg,
    lbm:                  lbm,
    bmc:                  bmc,
    lst:                  lst,
    tsm:                  tsm,
    essentialOrgans:      essentialOrgans,
    skinConnective:       skinConn,
    nonMuscleFluid:       nonMuscleFluid,
    asm:                  asm,
    axial:                axial,
    smmPercent:           tsm / weightKg * 100,
    smi:                  tsm / (heightM * heightM),
    relativeAsm:          asm / weightKg * 100,
    mbr:                  lbm / bmc,
    ffmi:                 lbm / (heightM * heightM),
    appendicularToTotal:  asm   / weightKg * 100,
    axialToTotal:         axial / weightKg * 100,
  );
}

// ─── Screen ────────────────────────────────────────────────────────────────

class BodyCompositionScreen extends StatefulWidget {
  /// When true, renders just the content (no Scaffold/AppBar) so it can be
  /// embedded inside another screen — e.g. the dashboard's Body Comp tab.
  final bool embedded;
  const BodyCompositionScreen({super.key, this.embedded = false});

  @override
  State<BodyCompositionScreen> createState() => _BodyCompositionScreenState();
}

class _BodyCompositionScreenState extends State<BodyCompositionScreen> {
  bool _isMale = true;
  int  _trendIdx = 0;

  final _weightCtrl  = TextEditingController();
  final _heightCtrl  = TextEditingController();
  final _neckCtrl    = TextEditingController();
  final _abdomenCtrl = TextEditingController();
  final _hipCtrl     = TextEditingController();

  _BCA? _result;
  String? _error;

  // ── Persistence / 2-week gate ──────────────────────────────────────────────
  bool _loading = true;
  bool _locked  = false;            // true while within 2 weeks of last analysis
  DateTime? _nextAvailable;         // when a new analysis is permitted
  List<Map<String, dynamic>> _history = []; // stored measurements, oldest first

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await LocalLogStore.bcaHistory();
    final locked  = await LocalLogStore.bcaLocked();
    final next    = await LocalLogStore.bcaNextAvailable();
    if (!mounted) return;
    setState(() {
      _history       = history;
      _locked        = locked;
      _nextAvailable = next;
      _result        = history.isNotEmpty ? _bcaFromEntry(history.last) : null;
      _loading       = false;
    });
    // Push any locally-stored readings that haven't reached the backend yet.
    unawaited(_syncPendingBca());
  }

  // Best-effort backfill: upload any local BCA readings not yet synced, so
  // estimates recorded before backend sync existed still reach coaches/admins.
  Future<void> _syncPendingBca() async {
    final history = await LocalLogStore.bcaHistory();
    if (history.isEmpty) return;
    final synced = await LocalLogStore.bcaSyncedDates();
    for (final entry in history) {
      final date = entry['date'] as String?;
      if (date == null || synced.contains(date)) continue;
      final r = _bcaFromEntry(entry);
      if (r == null) continue;
      final res = await ApiService.submitBodyComposition(_bcaPayload(entry, r));
      if (res != null) await LocalLogStore.markBcaSynced(date);
    }
  }

  // Builds the backend payload from a stored entry (raw inputs) + its computed
  // analysis (derived metrics).
  Map<String, dynamic> _bcaPayload(Map<String, dynamic> entry, _BCA r) {
    final isMale = entry['isMale'] == true;
    final num? hip = entry['hip'] as num?;
    return {
      'date':       entry['date'],
      'isMale':     isMale,
      'weightKg':   entry['weight'],
      'heightCm':   entry['height'],
      'neckCm':     entry['neck'],
      'abdomenCm':  entry['abdomen'],
      if (!isMale && hip != null) 'hipCm': hip,
      'bfPercent':  r.bfPercent,
      'bfKg':       r.bfKg,
      'lbm':        r.lbm,
      'smmPercent': r.smmPercent,
      'smi':        r.smi,
      'ffmi':       r.ffmi,
    };
  }

  // Reconstruct a full analysis from a stored measurement entry.
  _BCA? _bcaFromEntry(Map<String, dynamic> e) {
    final isMale = e['isMale'] == true;
    return _compute(
      isMale:    isMale,
      weightKg:  (e['weight']  as num).toDouble(),
      heightCm:  (e['height']  as num).toDouble(),
      neckCm:    (e['neck']    as num).toDouble(),
      abdomenCm: (e['abdomen'] as num).toDouble(),
      hipCm:     isMale ? null : (e['hip'] as num?)?.toDouble(),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _neckCtrl.dispose();
    _abdomenCtrl.dispose();
    _hipCtrl.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    final weight  = double.tryParse(_weightCtrl.text.trim());
    final height  = double.tryParse(_heightCtrl.text.trim());
    final neck    = double.tryParse(_neckCtrl.text.trim());
    final abdomen = double.tryParse(_abdomenCtrl.text.trim());
    final hip     = double.tryParse(_hipCtrl.text.trim());

    if (weight == null || height == null || neck == null || abdomen == null ||
        weight <= 0 || height <= 0 || neck <= 0 || abdomen <= 0) {
      setState(() { _error = 'Please fill in all required fields with valid values.'; });
      return;
    }
    if (!_isMale && (hip == null || hip <= 0)) {
      setState(() { _error = 'Hip circumference is required for females.'; });
      return;
    }

    // One-time disclaimer/consent before the first analysis.
    if (!await LocalLogStore.bcaConsent()) {
      final agreed = await _showDisclaimerConsent();
      if (agreed != true) return;
      await LocalLogStore.setBcaConsent(true);
    }

    final result = _compute(
      isMale:    _isMale,
      weightKg:  weight,
      heightCm:  height,
      neckCm:    neck,
      abdomenCm: abdomen,
      hipCm:     _isMale ? null : hip,
    );

    if (result == null) {
      setState(() { _error = 'Invalid measurements — abdomen must be greater than neck circumference.'; });
      return;
    }

    final entry = {
      'date':    DateTime.now().toIso8601String(),
      'isMale':  _isMale,
      'weight':  weight,
      'height':  height,
      'neck':    neck,
      'abdomen': abdomen,
      if (!_isMale) 'hip': hip,
    };
    await LocalLogStore.addBcaEntry(entry);

    // The backend sync happens in _loadHistory below, via _syncPendingBca.
    // Uploading here as well raced that backfill and stored every reading twice.

    if (!mounted) return;
    setState(() { _result = result; _error = null; });
    FocusScope.of(context).unfocus();
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) => FeatureGuard(
      feature: FeatureKeys.bodyComposition, child: _gatedBody(context));

  Widget _gatedBody(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
        : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(kGutter, 8, kGutter, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Within the 2-week window the measurement analysis is locked and
            // only the interpretation of the latest reading is shown.
            if (_locked) _buildLockedBanner() else _buildInputCard(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(kRadiusSm),
                  border: Border.all(color: kBorder, width: 0.6),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.error_outline_rounded, color: kDanger, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(color: kTextSecondary, fontSize: 14, height: 1.4))),
                ]),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 28),
              _buildStructuralTable(_result!),
              const SizedBox(height: 16),
              _buildDonutRow(_result!),
              const SizedBox(height: 28),
              _buildMetricGrid(_result!),
              const SizedBox(height: 28),
              _buildTrends(_result!),
              const SizedBox(height: 16),
              _buildInterpretation(_result!),
            ],
          ],
        ),
      );

    if (widget.embedded) {
      return Container(color: kBg, child: body);
    }
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Body composition'),
      ),
      body: body,
    );
  }

  // ── Locked Banner (2-week interval) ────────────────────────────────────────

  Widget _buildLockedBanner() {
    final next = _nextAvailable;
    return _panel(
      padding: const EdgeInsets.fromLTRB(18, 10, 6, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lock_clock_rounded, size: 20, color: kTextSecondary),
          const SizedBox(width: 10),
          const Expanded(child: _CardTitle('Analysis interval')),
          _infoBtn(),
        ]),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            const Text(
              'Body composition is assessed once every 2 weeks. Your latest '
              'interpretation and trends are shown below.',
              style: TextStyle(fontSize: 14, color: kTextSecondary, height: 1.45),
            ),
            if (next != null) ...[
              const SizedBox(height: 14),
              const Divider(height: 0.6),
              const SizedBox(height: 14),
              Row(children: [
                const Expanded(
                  child: Text('Next analysis available',
                      style: TextStyle(fontSize: 14, color: kTextSecondary)),
                ),
                Text(_fmtDate(next),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextPrimary)),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  // ── Methodology Info ("i" button) ──────────────────────────────────────────

  Widget _infoBtn() => IconButton(
    onPressed: () { hapticSelect(); _showMethodologyInfo(); },
    tooltip: 'How this is calculated',
    icon: const Icon(Icons.info_outline_rounded, size: 20, color: kTextSecondary),
  );

  void _showMethodologyInfo() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: kBorderBright, borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: const Text('How this is calculated',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                        color: kTextPrimary, letterSpacing: -0.3)),
              ),
              const SizedBox(height: 10),
              const Text(
                'Calculated using validated anthropometric distribution models '
                '(Janssen et al., Gallagher et al.) mapped to the U.S. Navy '
                'Circumference framework.',
                style: TextStyle(fontSize: 15, color: kTextSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Disclaimer Consent (shown once before first analysis) ──────────────────

  Future<bool?> _showDisclaimerConsent() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Before you begin'),
        content: const Text(
          'This analysis provides an estimate of your body composition derived '
          'from your measurements. It is calculated using validated '
          'anthropometric distribution models (Janssen et al., Gallagher et al.) '
          'mapped to the U.S. Navy Circumference framework.\n\n'
          'It is intended for general fitness and informational purposes only '
          'and is not a medical diagnosis or a substitute for professional '
          'advice. By continuing you acknowledge and consent to this estimate '
          'being calculated and stored on your device.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: kTextSecondary),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () { hapticConfirm(); Navigator.of(ctx).pop(true); },
            style: TextButton.styleFrom(foregroundColor: kAccent),
            child: const Text('I understand & agree'),
          ),
        ],
      ),
    );
  }

  // ── Input Card ────────────────────────────────────────────────────────────

  Widget _buildInputCard() {
    return _panel(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: _CardTitle('Measurements')),
          Transform.translate(offset: const Offset(12, 0), child: _infoBtn()),
        ]),
        const SizedBox(height: 10),

        // Gender toggle — segmented control
        Container(
          decoration: BoxDecoration(
            color: kBg, borderRadius: BorderRadius.circular(kRadiusSm),
            border: Border.all(color: kBorder, width: 0.6),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(children: [
            _genderBtn('Male',   true),
            _genderBtn('Female', false),
          ]),
        ),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: _field(_weightCtrl, 'Weight (kg)', '73')),
          const SizedBox(width: 12),
          Expanded(child: _field(_heightCtrl, 'Height (cm)', '175')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _field(_neckCtrl,    'Neck (cm)',    '38')),
          const SizedBox(width: 12),
          Expanded(child: _field(_abdomenCtrl, 'Abdomen (cm)', '85')),
        ]),
        if (!_isMale) ...[
          const SizedBox(height: 12),
          _field(_hipCtrl, 'Hip (cm)', '95'),
        ],
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () { hapticConfirm(); _calculate(); },
            child: const Text('Calculate'),
          ),
        ),
      ]),
    );
  }

  Widget _genderBtn(String label, bool male) {
    final selected = _isMale == male;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!selected) hapticSelect();
            setState(() { _isMale = male; _result = null; _error = null; });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 38,
            decoration: BoxDecoration(
              color: selected ? kTextPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(
              color: selected ? kBg : kTextSecondary,
              fontWeight: FontWeight.w600, fontSize: 14,
            )),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint) =>
    TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      style: const TextStyle(color: kTextPrimary, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );

  // ── Structural Layer Table ─────────────────────────────────────────────────

  Widget _buildStructuralTable(_BCA r) {
    return _card(
      title: 'Structural layer composition',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _tableHeader(),
        const Divider(height: 0.6),
        _tableRow('Total Body Weight',     '100.00%', r.weightKg,           bold: true),
        _tableRow('Total Body Fat',        _pct(r.bfPercent),      r.bfKg,    accent: kDanger),
        _tableRow('Lean Body Mass (LBM)',  _pct(100 - r.bfPercent), r.lbm,   accent: kAccent),
        _tableRow('Total Skeletal Muscle', _pct(r.smmPercent),     r.tsm,    accent: kExertion),
        _tableRow('  Axial Muscle Mass',   _pct(r.axialToTotal),   r.axial),
        _tableRow('  Appendicular (ASM)',  _pct(r.appendicularToTotal), r.asm),
        _tableRow('Estimated Bone Mass',   _pct(r.bmc / r.weightKg * 100), r.bmc, last: true),
        const SizedBox(height: 22),
        const _Label('LBM components'),
        const SizedBox(height: 6),
        const Divider(height: 0.6),
        _tableRow('Skeletal Muscle',       _pct(r.tsm / r.lbm * 100), r.tsm,  accent: kExertion),
        _tableRow('Essential Organs',      _pct(r.essentialOrgans / r.lbm * 100), r.essentialOrgans),
        _tableRow('Bone Mineral Content',  _pct(r.bmc / r.lbm * 100), r.bmc),
        _tableRow('Skin & Connective',     _pct(r.skinConnective / r.lbm * 100), r.skinConnective),
        _tableRow('Non-Muscle Lean Fluids',_pct(r.nonMuscleFluid / r.lbm * 100), r.nonMuscleFluid, last: true),
      ]),
    );
  }

  static const _tabular = [FontFeature.tabularFigures()];

  Widget _tableHeader() {
    const h = TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w500);
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(flex: 5, child: Padding(
          padding: EdgeInsets.only(left: 16),
          child: Text('Layer', style: h),
        )),
        SizedBox(width: 60, child: Text('%', style: h, textAlign: TextAlign.right)),
        SizedBox(width: 56, child: Text('kg', style: h, textAlign: TextAlign.right)),
        SizedBox(width: 56, child: Text('lbs', style: h, textAlign: TextAlign.right)),
      ]),
    );
  }

  Widget _tableRow(String label, String pct, double kg, {bool bold = false, Color? accent, bool last = false}) {
    final lbs = kg * 2.20462;
    final indented = label.startsWith('  ');
    final style = TextStyle(
      color: kTextPrimary,
      fontSize: 13,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      fontFeatures: _tabular,
    );
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Expanded(flex: 5, child: Row(children: [
            // Layer key dot; rows without a series colour keep the space so
            // every label starts on the same line.
            SizedBox(
              width: 16,
              child: accent == null ? null : Align(
                alignment: Alignment.centerLeft,
                child: Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              ),
            ),
            Expanded(child: Padding(
              padding: EdgeInsets.only(left: indented ? 12 : 0),
              child: Text(label.trimLeft(),
                  style: indented ? style.copyWith(color: kTextSecondary) : style),
            )),
          ])),
          SizedBox(width: 60, child: Text(pct, style: style, textAlign: TextAlign.right)),
          SizedBox(width: 56, child: Text(kg.toStringAsFixed(2), style: style, textAlign: TextAlign.right)),
          SizedBox(width: 56, child: Text(lbs.toStringAsFixed(2),
              style: const TextStyle(color: kTextSecondary, fontSize: 12, fontFeatures: _tabular),
              textAlign: TextAlign.right)),
        ]),
      ),
      if (!last) const Divider(height: 0.6),
    ]);
  }

  // ── Donut Charts Row ───────────────────────────────────────────────────────

  Widget _buildDonutRow(_BCA r) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: _card(
          title: 'Composition %',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 128,
              child: CustomPaint(
                painter: _DonutPainter(segments: [
                  _Seg(r.bfPercent,        kDanger, 'Body Fat'),
                  _Seg(100 - r.bfPercent,  kAccent,                 'LBM'),
                ]),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${r.bfPercent.toStringAsFixed(1)}%',
                      style: const TextStyle(color: kTextPrimary, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
                  const Text('Body fat', style: TextStyle(color: kTextSecondary, fontSize: 12)),
                ])),
              ),
            ),
            const SizedBox(height: 14),
            _legend(kDanger, 'Body fat  ${r.bfPercent.toStringAsFixed(1)}%'),
            const SizedBox(height: 6),
            _legend(kAccent, 'LBM  ${(100 - r.bfPercent).toStringAsFixed(1)}%'),
          ]),
        )),
        const SizedBox(width: 12),
        Expanded(child: _card(
          title: 'LBM components',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 128,
              child: CustomPaint(
                painter: _DonutPainter(segments: [
                  _Seg(r.tsm  / r.lbm * 100, kExertion,                  'Muscle'),
                  _Seg(r.essentialOrgans / r.lbm * 100, kWarn, 'Organs'),
                  _Seg(r.bmc  / r.lbm * 100, kViolet,  'Bone'),
                  _Seg(r.skinConnective / r.lbm * 100, const Color(0xFF4ADE80), 'Skin'),
                  _Seg(r.nonMuscleFluid / r.lbm * 100, kTextSecondary, 'Fluids'),
                ]),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${(r.tsm / r.lbm * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: kTextPrimary, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
                  const Text('Muscle', style: TextStyle(color: kTextSecondary, fontSize: 12)),
                ])),
              ),
            ),
            const SizedBox(height: 14),
            _legend(kExertion,                  'Muscle ${(r.tsm / r.lbm * 100).toStringAsFixed(0)}%'),
            const SizedBox(height: 6),
            _legend(kWarn, 'Organs ${(r.essentialOrgans / r.lbm * 100).toStringAsFixed(0)}%'),
            const SizedBox(height: 6),
            _legend(kViolet, 'Bone ${(r.bmc / r.lbm * 100).toStringAsFixed(0)}%'),
          ]),
        )),
      ]),
    );
  }

  Widget _legend(Color color, String text) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Flexible(child: Text(text, style: const TextStyle(color: kTextSecondary, fontSize: 12))),
  ]);

  // ── Key Metrics Grid ───────────────────────────────────────────────────────

  Widget _buildMetricGrid(_BCA r) {
    final metrics = [
      _MetricData('Fat Percentage',       '${r.bfPercent.toStringAsFixed(1)}%', _gradeBF(r.bfPercent, r.isMale),
          'Composition balance'),
      _MetricData('FFMI',                 r.ffmi.toStringAsFixed(1),  _gradeFFMI(r.ffmi, r.isMale),
          'Fat-free mass index'),
      _MetricData('Skeletal Muscle %',    '${r.smmPercent.toStringAsFixed(1)}%', _gradeSMM(r.smmPercent, r.isMale),
          'of total body weight'),
      _MetricData('Muscle Mass Index',    '${r.smi.toStringAsFixed(2)} kg/m²', _gradeSMI(r.smi, r.isMale),
          'Sarcopenia screening'),
      _MetricData('Relative ASM',         '${r.relativeAsm.toStringAsFixed(1)}%', _gradeRelASM(r.relativeAsm, r.isMale),
          'Functional limb muscle'),
      _MetricData('Muscle-Bone Ratio',    r.mbr.toStringAsFixed(1), _gradeMBR(r.mbr),
          'LBM / Bone mass'),
      _MetricData('Appendicular Ratio',   '${r.appendicularToTotal.toStringAsFixed(1)}%', _gradeAppendicular(r.appendicularToTotal, r.isMale),
          'Limb muscle vs body'),
      _MetricData('Axial Ratio',          '${r.axialToTotal.toStringAsFixed(1)}%', _gradeAxial(r.axialToTotal, r.isMale),
          'Core muscle vs body'),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: _Label('Key metrics & analysis'),
      ),
      const SizedBox(height: 8),
      GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12,
          mainAxisSpacing: 12, mainAxisExtent: 164,
        ),
        itemCount: metrics.length,
        itemBuilder: (_, i) => _metricCard(metrics[i]),
      ),
    ]);
  }

  Widget _metricCard(_MetricData m) => _panel(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: kTextSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(m.value, style: const TextStyle(
            color: kTextPrimary, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
      ),
      Text(m.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: kTextMuted, fontSize: 12)),
      const Spacer(),
      _GradeTag(grade: m.grade, maxLines: 3),
    ]),
  );

  // ── Metric Trends (real bi-weekly history) ─────────────────────────────────

  // Each stored measurement reconstructed into a full analysis, oldest first.
  List<_BCA> get _historyBcas =>
      _history.map(_bcaFromEntry).whereType<_BCA>().toList();

  // X-axis labels — the actual date each analysis was recorded (dd/MM).
  List<String> get _trendDates => _history.map((e) {
        final d = DateTime.parse(e['date'] as String);
        return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
      }).toList();

  List<_TrendMetric> _trendsFor(_BCA r) {
    final bcas = _historyBcas;
    List<double> s(double Function(_BCA) f) => bcas.map(f).toList();
    return [
      _TrendMetric('Body Fat', '%',        s((b) => b.bfPercent),   kDanger, goalDown: true),
      _TrendMetric('FFMI', '',             s((b) => b.ffmi),        kAccent,                 goalDown: false),
      _TrendMetric('Skeletal Muscle', '%', s((b) => b.smmPercent),  kExertion,                 goalDown: false),
      _TrendMetric('Muscle Index', '',     s((b) => b.smi),         kInfo, goalDown: false),
      _TrendMetric('Relative ASM', '%',    s((b) => b.relativeAsm), kViolet, goalDown: false),
      _TrendMetric('Weight', 'kg',         s((b) => b.weightKg),    kWarn, goalDown: false),
    ];
  }

  Widget _buildTrends(_BCA r) {
    final trends = _trendsFor(r);
    if (_trendIdx >= trends.length) _trendIdx = 0;
    final m       = trends[_trendIdx];
    if (m.values.isEmpty) return const SizedBox.shrink();
    final first   = m.values.first;
    final last    = m.values.last;
    final change  = last - first;
    final improved = m.goalDown ? change < 0 : change > 0;
    final chgCol  = improved ? kAccent : kDanger;
    final readings = m.values.length;
    final single  = readings < 2;

    return _card(
      title: 'Metric trends · $readings reading${readings == 1 ? '' : 's'} (bi-weekly)',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Metric selector chips
        Wrap(spacing: 8, runSpacing: 8, children: List.generate(trends.length, (i) {
          final active = i == _trendIdx;
          final t = trends[i];
          return ChoiceChip(
            label: Text(t.name),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? kBg : kTextPrimary,
            ),
            selected: active,
            showCheckmark: false,
            selectedColor: kTextPrimary,
            backgroundColor: kCard,
            side: BorderSide(color: active ? kTextPrimary : kBorder),
            onSelected: (_) {
              if (!active) hapticSelect();
              setState(() => _trendIdx = i);
            },
          );
        })),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('${last.toStringAsFixed(1)}${m.unit}',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -1.0)),
          const SizedBox(width: 10),
          if (!single) ...[
            Icon(change == 0 ? Icons.remove_rounded : change > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 14, color: chgCol),
            const SizedBox(width: 2),
            Text('${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}${m.unit}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
          ],
        ]),
        const SizedBox(height: 4),
        Text(
          single
              ? 'First reading recorded · trend builds from your next analysis'
              : 'From ${first.toStringAsFixed(1)}${m.unit} at first reading · ${improved ? "On track" : "Needs attention"}',
          style: const TextStyle(fontSize: 13, color: kTextSecondary),
        ),
        const SizedBox(height: 16),
        if (single)
          Container(
            height: 96,
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(kRadiusSm),
              border: Border.all(color: kBorder, width: 0.6),
            ),
            child: const Text('A chart appears once you have two or more readings',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kTextSecondary)),
          )
        else
          SizedBox(
            height: 170,
            child: CustomPaint(
              painter: _TrendChartPainter(values: m.values, dates: _trendDates, color: m.color),
              size: Size.infinite,
            ),
          ),
        const SizedBox(height: 10),
        const Text('Follow-up every 2 weeks · tracks adaptation across the season',
            style: TextStyle(fontSize: 12, color: kTextMuted)),
      ]),
    );
  }

  // ── Interpretation Report ─────────────────────────────────────────────────

  Widget _buildInterpretation(_BCA r) {
    final bfGrade   = _gradeBF(r.bfPercent, r.isMale);
    final smmGrade  = _gradeSMM(r.smmPercent, r.isMale);
    final relGrade  = _gradeRelASM(r.relativeAsm, r.isMale);
    final mbrGrade  = _gradeMBR(r.mbr);

    // Determine overall profile
    final isAtRisk    = r.bfPercent > (r.isMale ? 24 : 31) || r.smmPercent < (r.isMale ? 39 : 32);
    final isAthletic  = r.bfPercent <= (r.isMale ? 13 : 20) && r.smmPercent >= (r.isMale ? 43 : 36);
    final overallLabel = isAtRisk ? 'Sub-optimal / At-Risk' : (isAthletic ? 'Optimal / Athletic' : 'Balanced / Developing');
    final overallColor = isAtRisk ? kDanger : (isAthletic ? kAccent : kExertion);

    // Limb dominance
    final limbDominant = r.appendicularToTotal > r.axialToTotal;
    final weightDist   = limbDominant ? 'Limb-Dominant' : 'Core-Dominant';

    // Action plan
    final List<String> actions = [];
    if (r.bfPercent > (r.isMale ? 17 : 24)) {
      actions.add('Nutrition: Create a modest caloric deficit (300–500 kcal/day) with high protein intake (≥1.8g/kg) to reduce body fat while preserving lean mass.');
    }
    if (r.smmPercent < (r.isMale ? 43 : 36)) {
      actions.add('Exercise: Prioritise progressive resistance training (3–5 sessions/week) with compound lifts to increase skeletal muscle mass.');
    }
    if (r.relativeAsm < (r.isMale ? 31.5 : 26.5)) {
      actions.add('Focus on limb strengthening — squats, lunges, deadlifts, and upper-body pulls to develop appendicular muscle mass.');
    }
    if (actions.isEmpty) {
      actions.add('Maintain current training and nutrition protocols. Focus on consistency and progressive overload.');
    }
    actions.add('Follow-up body composition assessment recommended in 2 weeks to track adaptations.');

    return _card(
      title: 'Interpretation report',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Overall impression
        const Text('Overall profile', style: TextStyle(color: kTextSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        Row(children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: overallColor, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(overallLabel, style: const TextStyle(
                color: kTextPrimary, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          ),
        ]),
        const SizedBox(height: 24),

        // Executive summary
        _sectionTitle('I. Executive summary'),
        const SizedBox(height: 4),
        _interpretRow('Body Fat', '${r.bfPercent.toStringAsFixed(1)}%', bfGrade),
        const Divider(height: 0.6),
        _interpretRow('Skeletal Muscle', '${r.smmPercent.toStringAsFixed(1)}%', smmGrade),
        const Divider(height: 0.6),
        _interpretRow('Functional Limb Muscle', '${r.relativeAsm.toStringAsFixed(1)}%', relGrade),
        const Divider(height: 0.6),
        _interpretRow('Muscle-Bone Framework', r.mbr.toStringAsFixed(1), mbrGrade),
        const SizedBox(height: 24),

        // Diagnostic insights
        _sectionTitle('II. Analytical insights'),
        const SizedBox(height: 12),
        _bullet('Muscle Efficiency',
            'FFMI of ${r.ffmi.toStringAsFixed(1)} kg/m² — ${_gradeFFMI(r.ffmi, r.isMale).label} muscularity relative to height.'),
        _bullet('Skeletal Support',
            'Muscle-to-Bone Ratio of ${r.mbr.toStringAsFixed(1)} — ${mbrGrade.label}. Skeleton is ${r.mbr >= 19 ? "adequately" : "insufficiently"} supported by current muscle mass.'),
        _bullet('Weight Distribution',
            '$weightDist body architecture (${r.appendicularToTotal.toStringAsFixed(1)}% limb / ${r.axialToTotal.toStringAsFixed(1)}% core muscle of BW).'),
        _bullet('Composition Balance',
            '${r.lbm.toStringAsFixed(1)} kg lean mass vs ${r.bfKg.toStringAsFixed(1)} kg fat mass. LBM constitutes ${(r.lbm / r.weightKg * 100).toStringAsFixed(1)}% of total weight.'),
        const SizedBox(height: 14),

        // Action plan
        _sectionTitle('III. Suggestions'),
        const SizedBox(height: 12),
        ...actions.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 22,
              child: Text('${e.key + 1}.', style: const TextStyle(
                  color: kTextMuted, fontSize: 14, fontWeight: FontWeight.w600, height: 1.5)),
            ),
            Expanded(child: Text(e.value, style: const TextStyle(
                color: kTextSecondary, fontSize: 14, height: 1.5))),
          ]),
        )),
      ]),
    );
  }

  Widget _sectionTitle(String t) => _Label(t);

  Widget _interpretRow(String label, String value, _Grade grade) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 13)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: kTextPrimary, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
      ])),
      const SizedBox(width: 12),
      Expanded(flex: 6, child: Align(
        alignment: Alignment.centerRight,
        child: _GradeTag(grade: grade, maxLines: 2, alignEnd: true),
      )),
    ]),
  );

  Widget _bullet(String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 4, height: 4,
        margin: const EdgeInsets.only(top: 9, right: 12, left: 2),
        decoration: const BoxDecoration(color: kTextMuted, shape: BoxShape.circle),
      ),
      Expanded(child: Text.rich(TextSpan(children: [
        TextSpan(text: '$title: ', style: const TextStyle(
            color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w600, height: 1.5)),
        TextSpan(text: body, style: const TextStyle(
            color: kTextSecondary, fontSize: 14, height: 1.5)),
      ]))),
    ]),
  );

  // ── Shared Helpers ─────────────────────────────────────────────────────────

  /// Flat card — kCard, hairline border, no shadow.
  Widget _panel({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(18)}) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: kCard, borderRadius: BorderRadius.circular(kRadius),
      border: Border.all(color: kBorder, width: 0.6),
    ),
    padding: padding,
    child: child,
  );

  Widget _card({required String title, required Widget child}) => _panel(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _CardTitle(title),
      const SizedBox(height: 14),
      child,
    ]),
  );

  String _pct(double v) => '${v.toStringAsFixed(2)}%';
}

// ─── Small presentational widgets ──────────────────────────────────────────

/// Card title: 17 w600 primary, sentence case.
class _CardTitle extends StatelessWidget {
  final String text;
  const _CardTitle(this.text);

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: const TextStyle(
        fontSize: 17, fontWeight: FontWeight.w600, color: kTextPrimary, letterSpacing: -0.2)),
  );
}

/// Group / sub-section label: 13 w600 secondary, sentence case.
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
  );
}

/// Grade shown as a small status dot in the grade colour plus the word.
class _GradeTag extends StatelessWidget {
  final _Grade grade;
  final int maxLines;
  final bool alignEnd;
  const _GradeTag({required this.grade, this.maxLines = 2, this.alignEnd = false});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Container(width: 8, height: 8,
            decoration: BoxDecoration(color: grade.color, shape: BoxShape.circle)),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(grade.label,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: const TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w500, height: 1.3)),
      ),
    ],
  );
}

// ─── Data Helpers ──────────────────────────────────────────────────────────

class _MetricData {
  final String   name, value, subtitle;
  final _Grade   grade;
  const _MetricData(this.name, this.value, this.grade, this.subtitle);
}

class _Seg {
  final double percent;
  final Color  color;
  final String label;
  const _Seg(this.percent, this.color, this.label);
}

class _TrendMetric {
  final String name, unit;
  final List<double> values;
  final Color color;
  final bool  goalDown; // true if a downward trend is the improvement
  const _TrendMetric(this.name, this.unit, this.values, this.color, {required this.goalDown});
}

// ─── Trend Line Chart Painter ───────────────────────────────────────────────

class _TrendChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> dates;
  final Color color;
  const _TrendChartPainter({required this.values, required this.dates, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final n = values.length;
    const bPad = 22.0, tPad = 10.0, lPad = 4.0, rPad = 4.0;
    final chartH = size.height - bPad - tPad;
    final chartW = size.width - lPad - rPad;

    double lo = values.reduce(min), hi = values.reduce(max);
    final pad = (hi - lo) * 0.18 + 0.5;
    lo -= pad; hi += pad;
    double yAt(double v) => tPad + chartH * (1 - (v - lo) / (hi - lo));
    double xAt(int i) => lPad + chartW * i / (n - 1);

    // Grid lines — hairline
    final grid = Paint()..color = kBorder..strokeWidth = 0.6;
    for (int g = 0; g <= 3; g++) {
      final y = tPad + chartH * g / 3;
      canvas.drawLine(Offset(lPad, y), Offset(size.width - rPad, y), grid);
    }

    final pts = List.generate(n, (i) => Offset(xAt(i), yAt(values[i])));

    // Smooth line
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < n - 1; i++) {
      final p0 = i > 0 ? pts[i - 1] : pts[0];
      final p1 = pts[i], p2 = pts[i + 1];
      final p3 = i < n - 2 ? pts[i + 2] : pts[n - 1];
      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    // Flat wash under the line (no gradient).
    final fill = Path.from(path)
      ..lineTo(pts.last.dx, size.height - bPad)
      ..lineTo(pts.first.dx, size.height - bPad)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));

    canvas.drawPath(path, Paint()
      ..color = color..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);

    // Reading dots
    for (final p in pts) {
      canvas.drawCircle(p, 2.0, Paint()..color = color);
    }
    // Latest reading: solid dot with a card-coloured ring to lift it off the line.
    canvas.drawCircle(pts.last, 5.5, Paint()..color = kCard);
    canvas.drawCircle(pts.last, 4, Paint()..color = color);

    // Date labels (every ~5th)
    final step = max(1, n ~/ 5);
    for (int i = 0; i < n; i += step) {
      final tp = TextPainter(
        text: TextSpan(text: dates[i], style: const TextStyle(color: kTextMuted, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((xAt(i) - tp.width / 2).clamp(0.0, size.width - tp.width), size.height - bPad + 6));
    }
  }

  @override
  bool shouldRepaint(_TrendChartPainter old) => old.values != values || old.color != color;
}

// ─── Custom Donut Chart Painter ─────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final List<_Seg> segments;
  _DonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 4;
    const strokeWidth = 14.0;
    const gap = 0.03; // radians gap between segments

    double total = segments.fold(0, (s, e) => s + e.percent);
    if (total <= 0) return;

    double startAngle = -pi / 2;

    for (final seg in segments) {
      final sweep = (seg.percent / total) * (2 * pi) - gap;
      if (sweep <= 0) continue;

      final paint = Paint()
        ..color = seg.color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle, sweep, false, paint,
      );

      startAngle += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.segments != segments;
}
