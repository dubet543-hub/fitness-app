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
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(kGutter, 24, kGutter, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: BrandLogo(width: 132)),
              const SizedBox(height: 28),
              Semantics(
                header: true,
                child: const Text('Before you continue',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700,
                        color: kTextPrimary, letterSpacing: -0.6, height: 1.15)),
              ),
              const SizedBox(height: 8),
              const Text(
                'We have updated our Terms & Conditions and Privacy Policy. '
                'Please review and accept them to keep using SolidCore.',
                style: TextStyle(fontSize: 15, color: kTextSecondary, height: 1.45),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(kRadius),
                  border: Border.all(color: kBorder, width: 0.6),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.medical_information_outlined, size: 20, color: kTextSecondary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('Not medical advice',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                                color: kTextPrimary)),
                      ),
                    ]),
                    SizedBox(height: 8),
                    Text(
                      'SolidCore is a recording and analytical tool for sports '
                      'performance. Its scores, workload ratios, and fatigue '
                      'metrics are not a diagnosis and do not replace advice from '
                      'your physician or physiotherapist, and using it does not '
                      'create a clinician-patient relationship.',
                      style: TextStyle(fontSize: 14, color: kTextSecondary, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              LegalAgreementCheckbox(
                value: _agreedLegal,
                onChanged: (v) => setState(() => _agreedLegal = v),
              ),
              const SizedBox(height: 8),
              TrackingConsentCheckbox(
                value: _trackingConsent,
                onChanged: (v) => setState(() => _trackingConsent = v),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _agreedLegal && !_saving ? () { hapticConfirm(); _accept(); } : null,
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kTextPrimary))
                    : const Text('Accept & Continue'),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : widget.onSignOut,
                  child: const Text('Sign out instead',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kTextSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
