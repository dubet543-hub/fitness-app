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

_Grade _gradeAppendicular(double pct, bool male) {
  if (male) {
    if (pct < 44) return _Grade('Grade 4 – At Risk',        kDanger);
    if (pct < 49) return _Grade('Grade 3 – Compact',        kWarn);
    if (pct < 54) return _Grade('Grade 2 – Balanced',       kSuccess);
    return _Grade('Grade 1 – Distal Lever Dominant', kInfo);
  } else {
    if (pct < 42) return _Grade('Grade 4 – At Risk',        kDanger);
    if (pct < 47) return _Grade('Grade 3 – Compact',        kWarn);
    if (pct < 52) return _Grade('Grade 2 – Balanced',       kSuccess);
    return _Grade('Grade 1 – Distal Lever Dominant', kInfo);
  }
}

_Grade _gradeAxial(double pct, bool male) {
  if (male) {
    if (pct < 40) return _Grade('Grade 4 – Structural Insufficiency', kDanger);
    if (pct < 46) return _Grade('Grade 3 – Elongated / Locomotive',  kWarn);
    if (pct < 56) return _Grade('Grade 2 – Balanced Core Base',      kSuccess);
    return _Grade('Grade 1 – Rotational Anchor', kInfo);
  } else {
    if (pct < 42) return _Grade('Grade 4 – Structural Insufficiency', kDanger);
    if (pct < 48) return _Grade('Grade 3 – Elongated / Locomotive',  kWarn);
    if (pct < 58) return _Grade('Grade 2 – Balanced Core Base',      kSuccess);
    return _Grade('Grade 1 – Rotational Anchor', kInfo);
  }
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
  bool _justCalculated = false;     // show full breakdown for the fresh analysis
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

    // Best-effort sync to the backend so coaches/admins can review it. Runs in
    // the background and never blocks or fails the on-device result.
    unawaited(() async {
      final res = await ApiService.submitBodyComposition(_bcaPayload(entry, result));
      if (res != null) await LocalLogStore.markBcaSynced(entry['date'] as String);
    }());

    if (!mounted) return;
    setState(() { _result = result; _error = null; _justCalculated = true; });
    FocusScope.of(context).unfocus();
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) => FeatureGuard(
      feature: FeatureKeys.bodyComposition, child: _gatedBody(context));

  Widget _gatedBody(BuildContext context) {
    final body = _loading
        ? Center(child: CircularProgressIndicator(color: kAccent))
        : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Within the 2-week window the measurement analysis is locked and
            // only the interpretation of the latest reading is shown.
            if (_locked) _buildLockedBanner() else _buildInputCard(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kDanger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kDanger.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline_rounded, color: kDanger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: TextStyle(color: kDanger, fontSize: 12.5))),
                ]),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 28),
              // The raw measurement breakdown is part of running an analysis, so
              // it is only shown right after a fresh analysis, then hidden while
              // the 2-week interval keeps the segment to interpretation only.
              if (!_locked || _justCalculated) ...[
                _buildStructuralTable(_result!),
                const SizedBox(height: 20),
                _buildDonutRow(_result!),
                const SizedBox(height: 20),
              ],
              _buildMetricGrid(_result!),
              const SizedBox(height: 20),
              _buildTrends(_result!),
              const SizedBox(height: 20),
              _buildInterpretation(_result!),
            ],
            const SizedBox(height: 40),
          ],
        ),
      );

    if (widget.embedded) {
      return Container(color: kBg, child: body);
    }
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: Text(
          'BODY COMPOSITION',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: kTextSecondary, letterSpacing: 1.4),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: body,
    );
  }

  // ── Locked Banner (2-week interval) ────────────────────────────────────────

  Widget _buildLockedBanner() {
    final next = _nextAvailable;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kAccent.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.lock_clock_rounded, size: 18, color: kAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('ANALYSIS INTERVAL',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: kTextSecondary, letterSpacing: 1.4)),
          ),
          _infoBtn(),
        ]),
        const SizedBox(height: 14),
        Text(
          'Body composition is assessed once every 2 weeks. Your latest '
          'interpretation and trends are shown below.',
          style: TextStyle(fontSize: 13, color: kTextSecondary, height: 1.5),
        ),
        if (next != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kSurface, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Row(children: [
              Icon(Icons.event_available_rounded, size: 16, color: kAccent),
              const SizedBox(width: 10),
              Text('Next analysis available',
                  style: TextStyle(fontSize: 12.5, color: kTextSecondary)),
              const Spacer(),
              Text(_fmtDate(next),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
            ]),
          ),
        ],
      ]),
    );
  }

  // ── Methodology Info ("i" button) ──────────────────────────────────────────

  Widget _infoBtn() => GestureDetector(
    onTap: _showMethodologyInfo,
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: 22, height: 22,
      decoration: BoxDecoration(
        color: kSurface,
        shape: BoxShape.circle,
        border: Border.all(color: kBorder),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.info_outline_rounded, size: 14, color: kTextSecondary),
    ),
  );

  void _showMethodologyInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: kBorder, borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Icon(Icons.info_outline_rounded, size: 18, color: kAccent),
                const SizedBox(width: 10),
                Text('HOW THIS IS CALCULATED',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: kTextSecondary, letterSpacing: 1.4)),
              ]),
              const SizedBox(height: 14),
              Text(
                'Calculated using validated anthropometric distribution models '
                '(Janssen et al., Gallagher et al.) mapped to the U.S. Navy '
                'Circumference framework.',
                style: TextStyle(fontSize: 13.5, color: kTextPrimary, height: 1.5),
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
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(children: [
          Icon(Icons.verified_user_outlined, size: 18, color: kAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text('BEFORE YOU BEGIN',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: kTextSecondary, letterSpacing: 1.4)),
          ),
        ]),
        content: Text(
          'This analysis provides an estimate of your body composition derived '
          'from your measurements. It is calculated using validated '
          'anthropometric distribution models (Janssen et al., Gallagher et al.) '
          'mapped to the U.S. Navy Circumference framework.\n\n'
          'It is intended for general fitness and informational purposes only '
          'and is not a medical diagnosis or a substitute for professional '
          'advice. By continuing you acknowledge and consent to this estimate '
          'being calculated and stored on your device.',
          style: TextStyle(fontSize: 13.5, color: kTextPrimary, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('I Understand & Agree',
                style: TextStyle(color: kAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Input Card ────────────────────────────────────────────────────────────

  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('MEASUREMENTS', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: kTextSecondary, letterSpacing: 1.4)),
          const Spacer(),
          _infoBtn(),
        ]),
        const SizedBox(height: 16),

        // Gender toggle
        Container(
          decoration: BoxDecoration(
            color: kSurface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          padding: const EdgeInsets.all(4),
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
          child: ElevatedButton(
            onPressed: _calculate,
            child: const Text('CALCULATE'),
          ),
        ),
      ]),
    );
  }

  Widget _genderBtn(String label, bool male) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() { _isMale = male; _result = null; _error = null; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _isMale == male ? kAccent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: _isMale == male ? kAccent : Colors.transparent, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(
          color: _isMale == male ? kAccent : kTextSecondary,
          fontWeight: FontWeight.w700, fontSize: 13,
        )),
      ),
    ),
  );

  Widget _field(TextEditingController ctrl, String label, String hint) =>
    TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      style: TextStyle(color: kTextPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: kTextMuted),
      ),
    );

  // ── Structural Layer Table ─────────────────────────────────────────────────

  Widget _buildStructuralTable(_BCA r) {
    return _card(
      title: 'STRUCTURAL LAYER COMPOSITION',
      child: Column(children: [
        _tableHeader(),
        _tableRow('Total Body Weight',     '100.00%', r.weightKg,           bold: true),
        _tableRow('Total Body Fat',        _pct(r.bfPercent),      r.bfKg,    accent: kDanger),
        _tableRow('Lean Body Mass (LBM)',  _pct(100 - r.bfPercent), r.lbm,   accent: kAccent),
        Divider(height: 20, color: kBorder),
        _tableRow('Total Skeletal Muscle', _pct(r.smmPercent),     r.tsm,    accent: kExertion),
        _tableRow('  Axial Muscle Mass',   _pct(r.axialToTotal),   r.axial),
        _tableRow('  Appendicular (ASM)',  _pct(r.appendicularToTotal), r.asm),
        _tableRow('Estimated Bone Mass',   _pct(r.bmc / r.weightKg * 100), r.bmc),
        Divider(height: 20, color: kBorder),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('LBM COMPONENTS', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: kTextSecondary, letterSpacing: 1.2)),
        ),
        const SizedBox(height: 8),
        _tableRow('Skeletal Muscle',       _pct(r.tsm / r.lbm * 100), r.tsm,  accent: kExertion),
        _tableRow('Essential Organs',      _pct(r.essentialOrgans / r.lbm * 100), r.essentialOrgans),
        _tableRow('Bone Mineral Content',  _pct(r.bmc / r.lbm * 100), r.bmc),
        _tableRow('Skin & Connective',     _pct(r.skinConnective / r.lbm * 100), r.skinConnective),
        _tableRow('Non-Muscle Lean Fluids',_pct(r.nonMuscleFluid / r.lbm * 100), r.nonMuscleFluid),
      ]),
    );
  }

  Widget _tableHeader() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(flex: 5, child: Text('Layer', style: TextStyle(color: kTextMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6))),
      SizedBox(width: 60, child: Text('%', style: TextStyle(color: kTextMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6), textAlign: TextAlign.right)),
      SizedBox(width: 60, child: Text('kg', style: TextStyle(color: kTextMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6), textAlign: TextAlign.right)),
      SizedBox(width: 58, child: Text('lbs', style: TextStyle(color: kTextMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6), textAlign: TextAlign.right)),
    ]),
  );

  Widget _tableRow(String label, String pct, double kg, {bool bold = false, Color? accent}) {
    final lbs = kg * 2.20462;
    final textColor = accent ?? kTextPrimary;
    final style = TextStyle(color: textColor, fontSize: 12.5, fontWeight: bold ? FontWeight.w700 : FontWeight.w400);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(children: [
        Expanded(flex: 5, child: Row(children: [
          if (accent != null) Container(width: 3, height: 13, color: accent,
              margin: const EdgeInsets.only(right: 6)),
          Expanded(child: Text(label, style: style)),
        ])),
        SizedBox(width: 60, child: Text(pct, style: style, textAlign: TextAlign.right)),
        SizedBox(width: 60, child: Text(kg.toStringAsFixed(2), style: style, textAlign: TextAlign.right)),
        SizedBox(width: 58, child: Text(lbs.toStringAsFixed(2), style: TextStyle(color: kTextSecondary, fontSize: 11.5), textAlign: TextAlign.right)),
      ]),
    );
  }

  // ── Donut Charts Row ───────────────────────────────────────────────────────

  Widget _buildDonutRow(_BCA r) {
    return Row(children: [
      Expanded(child: _card(
        title: 'COMPOSITION %',
        child: Column(children: [
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _DonutPainter(segments: [
                _Seg(r.bfPercent,        kDanger, 'Body Fat'),
                _Seg(100 - r.bfPercent,  kAccent,                 'LBM'),
              ]),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${r.bfPercent.toStringAsFixed(1)}%',
                    style: TextStyle(color: kTextPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Body Fat', style: TextStyle(color: kTextSecondary, fontSize: 10)),
              ])),
            ),
          ),
          const SizedBox(height: 12),
          _legend(kDanger, 'Body Fat  ${r.bfPercent.toStringAsFixed(1)}%'),
          const SizedBox(height: 6),
          _legend(kAccent, 'LBM  ${(100 - r.bfPercent).toStringAsFixed(1)}%'),
        ]),
      )),
      const SizedBox(width: 12),
      Expanded(child: _card(
        title: 'LBM COMPONENTS',
        child: Column(children: [
          SizedBox(
            height: 140,
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
                    style: TextStyle(color: kTextPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Muscle', style: TextStyle(color: kTextSecondary, fontSize: 10)),
              ])),
            ),
          ),
          const SizedBox(height: 12),
          _legend(kExertion,                  'Muscle ${(r.tsm / r.lbm * 100).toStringAsFixed(0)}%'),
          const SizedBox(height: 4),
          _legend(kWarn, 'Organs ${(r.essentialOrgans / r.lbm * 100).toStringAsFixed(0)}%'),
          const SizedBox(height: 4),
          _legend(kViolet, 'Bone ${(r.bmc / r.lbm * 100).toStringAsFixed(0)}%'),
        ]),
      )),
    ]);
  }

  Widget _legend(Color color, String text) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(text, style: TextStyle(color: kTextSecondary, fontSize: 11)),
  ]);

  // ── Key Metrics Grid ───────────────────────────────────────────────────────

  Widget _buildMetricGrid(_BCA r) {
    final metrics = [
      _MetricData('Fat Percentage',       '${r.bfPercent.toStringAsFixed(1)}%', _gradeBF(r.bfPercent, r.isMale),
          'Composition balance', Icons.water_drop_rounded),
      _MetricData('FFMI',                 r.ffmi.toStringAsFixed(1),  _gradeFFMI(r.ffmi, r.isMale),
          'Fat-free mass index', Icons.fitness_center_rounded),
      _MetricData('Skeletal Muscle %',    '${r.smmPercent.toStringAsFixed(1)}%', _gradeSMM(r.smmPercent, r.isMale),
          'of total body weight', Icons.accessibility_new_rounded),
      _MetricData('Muscle Mass Index',    '${r.smi.toStringAsFixed(2)} kg/m²', _gradeSMI(r.smi, r.isMale),
          'Sarcopenia screening', Icons.monitor_heart_rounded),
      _MetricData('Relative ASM',         '${r.relativeAsm.toStringAsFixed(1)}%', _gradeRelASM(r.relativeAsm, r.isMale),
          'Functional limb muscle', Icons.directions_run_rounded),
      _MetricData('Muscle-Bone Ratio',    r.mbr.toStringAsFixed(1), _gradeMBR(r.mbr),
          'LBM / Bone mass', Icons.architecture_rounded),
      _MetricData('Appendicular Ratio',   '${r.appendicularToTotal.toStringAsFixed(1)}%', _gradeAppendicular(r.appendicularToTotal, r.isMale),
          'Limb muscle vs body', Icons.sports_handball_rounded),
      _MetricData('Axial Ratio',          '${r.axialToTotal.toStringAsFixed(1)}%', _gradeAxial(r.axialToTotal, r.isMale),
          'Core muscle vs body', Icons.self_improvement_rounded),
    ];

    return Column(children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Text('KEY METRICS & ANALYSIS', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: kTextSecondary, letterSpacing: 1.4)),
      ),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 10,
          mainAxisSpacing: 10, childAspectRatio: 1.2,
        ),
        itemCount: metrics.length,
        itemBuilder: (_, i) => _metricCard(metrics[i]),
      ),
    ]);
  }

  Widget _metricCard(_MetricData m) => Container(
    decoration: BoxDecoration(
      color: kCard, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kBorder),
    ),
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 30, height: 30,
          decoration: BoxDecoration(
            color: m.grade.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(m.icon, color: m.grade.color, size: 15),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: m.grade.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(m.grade.label,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: m.grade.color, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ]),
      const Spacer(),
      Text(m.value, style: TextStyle(
          color: kTextPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(m.name, style: TextStyle(
          color: kTextPrimary, fontSize: 11.5, fontWeight: FontWeight.w600)),
      Text(m.subtitle, style: TextStyle(color: kTextSecondary, fontSize: 10)),
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
      title: 'METRIC TRENDS · $readings READING${readings == 1 ? '' : 'S'} (BI-WEEKLY)',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Metric selector chips
        Wrap(spacing: 8, runSpacing: 8, children: List.generate(trends.length, (i) {
          final active = i == _trendIdx;
          final t = trends[i];
          return GestureDetector(
            onTap: () => setState(() => _trendIdx = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: active ? t.color.withValues(alpha: 0.16) : kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: active ? t.color : kBorder),
              ),
              child: Text(t.name,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: active ? t.color : kTextSecondary)),
            ),
          );
        })),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${last.toStringAsFixed(1)}${m.unit}',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: m.color, letterSpacing: -0.8)),
          const SizedBox(width: 10),
          if (!single)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(change == 0 ? Icons.remove_rounded : change > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 13, color: chgCol),
                const SizedBox(width: 2),
                Text('${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}${m.unit}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: chgCol)),
              ]),
            ),
        ]),
        const SizedBox(height: 4),
        Text(
          single
              ? 'First reading recorded · trend builds from your next analysis'
              : 'From ${first.toStringAsFixed(1)}${m.unit} at first reading · ${improved ? "On track" : "Needs attention"}',
          style: TextStyle(fontSize: 11, color: kTextSecondary),
        ),
        const SizedBox(height: 14),
        if (single)
          Container(
            height: 90,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Text('A chart appears once you have two or more readings',
                style: TextStyle(fontSize: 11, color: kTextMuted)),
          )
        else
          SizedBox(
            height: 170,
            child: CustomPaint(
              painter: _TrendChartPainter(values: m.values, dates: _trendDates, color: m.color),
              size: Size.infinite,
            ),
          ),
        const SizedBox(height: 6),
        Text('Follow-up every 2 weeks · tracks adaptation across the season',
            style: TextStyle(fontSize: 10, color: kTextMuted)),
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
      title: 'INTERPRETATION REPORT',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Overall impression
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: overallColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: overallColor.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Overall Profile', style: TextStyle(
                color: overallColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Text(overallLabel, style: TextStyle(
                color: overallColor, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 18),

        // Executive summary
        _sectionTitle('I. EXECUTIVE SUMMARY'),
        const SizedBox(height: 10),
        _interpretRow('Body Fat', '${r.bfPercent.toStringAsFixed(1)}%', bfGrade),
        const SizedBox(height: 8),
        _interpretRow('Skeletal Muscle', '${r.smmPercent.toStringAsFixed(1)}%', smmGrade),
        const SizedBox(height: 8),
        _interpretRow('Functional Limb Muscle', '${r.relativeAsm.toStringAsFixed(1)}%', relGrade),
        const SizedBox(height: 8),
        _interpretRow('Muscle-Bone Framework', r.mbr.toStringAsFixed(1), mbrGrade),
        const SizedBox(height: 18),

        // Diagnostic insights
        _sectionTitle('II. ANALYTICAL INSIGHTS'),
        const SizedBox(height: 10),
        _bullet('Muscle Efficiency',
            'FFMI of ${r.ffmi.toStringAsFixed(1)} kg/m² — ${_gradeFFMI(r.ffmi, r.isMale).label} muscularity relative to height.'),
        _bullet('Skeletal Support',
            'Muscle-to-Bone Ratio of ${r.mbr.toStringAsFixed(1)} — ${mbrGrade.label}. Skeleton is ${r.mbr >= 19 ? "adequately" : "insufficiently"} supported by current muscle mass.'),
        _bullet('Weight Distribution',
            '$weightDist body architecture (${r.appendicularToTotal.toStringAsFixed(1)}% limb / ${r.axialToTotal.toStringAsFixed(1)}% core muscle of BW).'),
        _bullet('Composition Balance',
            '${r.lbm.toStringAsFixed(1)} kg lean mass vs ${r.bfKg.toStringAsFixed(1)} kg fat mass. LBM constitutes ${(r.lbm / r.weightKg * 100).toStringAsFixed(1)}% of total weight.'),
        const SizedBox(height: 18),

        // Action plan
        _sectionTitle('III. SUGGESTIONS'),
        const SizedBox(height: 10),
        ...actions.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text('${e.key + 1}', style: TextStyle(
                  color: kAccent, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(e.value, style: TextStyle(
                color: kTextSecondary, fontSize: 12.5, height: 1.5))),
          ]),
        )),
      ]),
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: TextStyle(
      fontSize: 10, fontWeight: FontWeight.w700,
      color: kTextSecondary, letterSpacing: 1.2));

  Widget _interpretRow(String label, String value, _Grade grade) => Row(children: [
    Container(width: 4, height: 32, color: grade.color, margin: const EdgeInsets.only(right: 10)),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: kTextSecondary, fontSize: 11)),
      Text(value, style: TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
    ])),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: grade.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(grade.label, style: TextStyle(
          color: grade.color, fontSize: 10, fontWeight: FontWeight.w700)),
    ),
  ]);

  Widget _bullet(String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 5, height: 5,
        margin: const EdgeInsets.only(top: 5.5, right: 10),
        decoration: BoxDecoration(color: kAccent, shape: BoxShape.circle),
      ),
      Expanded(child: RichText(text: TextSpan(children: [
        TextSpan(text: '$title: ', style: TextStyle(
            color: kTextPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
        TextSpan(text: body, style: TextStyle(
            color: kTextSecondary, fontSize: 12.5, height: 1.5)),
      ]))),
    ]),
  );

  // ── Shared Helpers ─────────────────────────────────────────────────────────

  Widget _card({required String title, required Widget child}) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: kCard, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: kBorder),
    ),
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: kTextSecondary, letterSpacing: 1.4)),
      const SizedBox(height: 14),
      child,
    ]),
  );

  String _pct(double v) => '${v.toStringAsFixed(2)}%';
}

// ─── Data Helpers ──────────────────────────────────────────────────────────

class _MetricData {
  final String   name, value, subtitle;
  final _Grade   grade;
  final IconData icon;
  const _MetricData(this.name, this.value, this.grade, this.subtitle, this.icon);
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
    const bPad = 18.0, tPad = 10.0, lPad = 4.0, rPad = 4.0;
    final chartH = size.height - bPad - tPad;
    final chartW = size.width - lPad - rPad;

    double lo = values.reduce(min), hi = values.reduce(max);
    final pad = (hi - lo) * 0.18 + 0.5;
    lo -= pad; hi += pad;
    double yAt(double v) => tPad + chartH * (1 - (v - lo) / (hi - lo));
    double xAt(int i) => lPad + chartW * i / (n - 1);

    // Grid lines
    for (int g = 0; g <= 3; g++) {
      final y = tPad + chartH * g / 3;
      canvas.drawLine(Offset(lPad, y), Offset(size.width - rPad, y),
          Paint()..color = kTextPrimary.withValues(alpha: 0.06)..strokeWidth = 0.5);
    }

    final pts = List.generate(n, (i) => Offset(xAt(i), yAt(values[i])));

    // Area fill
    final fill = Path()..moveTo(pts.first.dx, size.height - bPad)..lineTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < n; i++) {
      fill.lineTo(pts[i].dx, pts[i].dy);
    }
    fill..lineTo(pts.last.dx, size.height - bPad)..close();
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

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
    canvas.drawPath(path, Paint()
      ..color = color..strokeWidth = 2.2
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    // Reading dots
    for (final p in pts) {
      canvas.drawCircle(p, 2.0, Paint()..color = color.withValues(alpha: 0.6));
    }
    // Latest highlighted
    canvas.drawCircle(pts.last, 4.5, Paint()..color = color);
    canvas.drawCircle(pts.last, 4.5, Paint()
      ..color = kTextPrimary.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // Date labels (every ~5th)
    final step = max(1, n ~/ 5);
    for (int i = 0; i < n; i += step) {
      final tp = TextPainter(
        text: TextSpan(text: dates[i], style: TextStyle(color: kGrid, fontSize: 7.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((xAt(i) - tp.width / 2).clamp(0.0, size.width - tp.width), size.height - bPad + 4));
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
    const strokeWidth = 22.0;
    const gap = 0.025; // radians gap between segments

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
        ..strokeCap = StrokeCap.round;

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
