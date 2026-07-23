import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/local_log_store.dart';
import '../widgets/common_widgets.dart';
import '../widgets/legal_consent.dart';
import 'legal_pages.dart';

/// Blocking acceptance screen for users who are already signed in when the
/// Terms & Privacy Policy are first introduced — or updated to a new
/// [kLegalVersion]. New sign-ins accept on the login/register form instead, so
/// this is only ever seen once per document version.
class LegalConsentGate extends StatefulWidget {
  /// Called after acceptance has been recorded, so the app can continue in.
  final VoidCallback onAccepted;

  /// Escape hatch for a user who does not want to accept.
  final VoidCallback onSignOut;

  const LegalConsentGate({super.key, required this.onAccepted, required this.onSignOut});

  @override
  State<LegalConsentGate> createState() => _LegalConsentGateState();
}

class _LegalConsentGateState extends State<LegalConsentGate> {
  bool _agreedLegal     = false;
  bool _trackingConsent = false;
  bool _saving          = false;

  @override
  void initState() {
    super.initState();
    _loadTrackingConsent();
  }

  Future<void> _loadTrackingConsent() async {
    final tracking = await LocalLogStore.dailyLogsConsent();
    if (mounted) setState(() => _trackingConsent = tracking);
  }

  Future<void> _accept() async {
    setState(() => _saving = true);
    await LocalLogStore.setLegalAccepted(kLegalVersion);
    await LocalLogStore.setDailyLogsConsent(_trackingConsent);
    if (mounted) widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: BrandLogo(width: 160)),
              const SizedBox(height: 28),
              Text('Before you continue',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                      color: kTextPrimary, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text(
                'We have updated our Terms & Conditions and Privacy Policy. '
                'Please review and accept them to keep using SolidCore.',
                style: TextStyle(fontSize: 13, color: kTextSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.medical_information_outlined, size: 16, color: kWarn),
                      const SizedBox(width: 8),
                      Text('Not medical advice',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      'SolidCore is a recording and analytical tool for sports '
                      'performance. Its scores, workload ratios, and fatigue '
                      'metrics are not a diagnosis and do not replace advice from '
                      'your physician or physiotherapist, and using it does not '
                      'create a clinician-patient relationship.',
                      style: TextStyle(fontSize: 12.5, color: kTextSecondary, height: 1.55),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              LegalAgreementCheckbox(
                value: _agreedLegal,
                onChanged: (v) => setState(() => _agreedLegal = v),
              ),
              const SizedBox(height: 14),
              TrackingConsentCheckbox(
                value: _trackingConsent,
                onChanged: (v) => setState(() => _trackingConsent = v),
              ),
              const SizedBox(height: 26),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _agreedLegal && !_saving ? _accept : null,
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: kAccent.withValues(alpha: 0.25),
                    disabledForegroundColor: kOnAccent.withValues(alpha: 0.5),
                  ),
                  child: const Text('Accept & Continue'),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : widget.onSignOut,
                  child: Text('Sign out instead',
                      style: TextStyle(fontSize: 13, color: kTextSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
