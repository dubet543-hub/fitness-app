import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/local_log_store.dart';
import '../widgets/common_widgets.dart';
import '../widgets/legal_consent.dart';
import 'legal_pages.dart';

enum _OtpStage { email, code }

/// One flow for both sign-in and sign-up: request a code for an email, then
/// enter it. The backend logs in if the account exists or creates one
/// otherwise, so this screen never needs to ask which the user means.
class OtpScreen extends StatefulWidget {
  final Future<void> Function(String email) onRequestOtp;
  final Future<void> Function(String email, String code) onVerifyOtp;
  final VoidCallback onBack;

  const OtpScreen({
    super.key,
    required this.onRequestOtp,
    required this.onVerifyOtp,
    required this.onBack,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl  = TextEditingController();
  _OtpStage _stage = _OtpStage.email;
  bool    _loading = false;
  String? _error;
  int     _resendSeconds = 0;
  Timer?  _resendTimer;

  // Same one-time acceptance pattern as login/register — this flow can create
  // a brand-new account, so it must gate on the same consent.
  bool      _agreedLegal   = false;
  bool      _alreadyAgreed = false;
  DateTime? _agreedAt;
  bool      _trackingConsent = false;

  @override
  void initState() {
    super.initState();
    _loadConsentState();
  }

  Future<void> _loadConsentState() async {
    final accepted = await LocalLogStore.hasAcceptedLegal(kLegalVersion);
    final at       = await LocalLogStore.legalAcceptedAt();
    final tracking = await LocalLogStore.dailyLogsConsent();
    if (!mounted) return;
    setState(() {
      _alreadyAgreed   = accepted;
      _agreedLegal     = accepted;
      _agreedAt        = at;
      _trackingConsent = tracking;
    });
  }

  Future<void> _recordConsent() async {
    await LocalLogStore.setLegalAccepted(kLegalVersion);
    if (!_alreadyAgreed) {
      await LocalLogStore.setDailyLogsConsent(_trackingConsent);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  String get _email => _emailCtrl.text.trim();

  Future<void> _sendCode() async {
    final email = _email;
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (!_agreedLegal) {
      setState(() => _error =
          'Please accept the Terms & Conditions and Privacy Policy to continue.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onRequestOtp(email);
      if (mounted) setState(() => _stage = _OtpStage.code);
      _startResendCooldown();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _resendSeconds -= 1);
      if (_resendSeconds <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onVerifyOtp(_email, code);
      await _recordConsent();
      // On success the AuthScreen swaps to the main app; nothing more to do here.
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onCode = _stage == _OtpStage.code;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.adaptive.arrow_back),
          onPressed: _loading
              ? null
              : (onCode
                  ? () => setState(() { _stage = _OtpStage.email; _error = null; })
                  : widget.onBack),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AuthHeader(
                    title: onCode ? 'Enter your code' : 'Sign in with a code',
                    subtitle: onCode
                        ? 'Enter the 6-digit code sent to $_email'
                        : "We'll email you a 6-digit code — no password needed.",
                  ),
                  const SizedBox(height: 32),

                  if (_error != null) ...[
                    _ErrorBanner(message: _error!),
                    const SizedBox(height: 20),
                  ],

                  if (!onCode) ...[
                    _field(_emailCtrl, 'Email', keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 24),

                    if (_alreadyAgreed)
                      LegalAcceptedNotice(acceptedAt: _agreedAt)
                    else ...[
                      LegalAgreementCheckbox(
                        value: _agreedLegal,
                        onChanged: (v) => setState(() {
                          _agreedLegal = v;
                          if (v) _error = null;
                        }),
                      ),
                      const SizedBox(height: 4),
                      TrackingConsentCheckbox(
                        value: _trackingConsent,
                        onChanged: (v) => setState(() => _trackingConsent = v),
                      ),
                    ],
                    const SizedBox(height: 22),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading || !_agreedLegal
                            ? null
                            : () {
                                hapticConfirm();
                                _sendCode();
                              },
                        child: _loading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: kTextSecondary),
                              )
                            : const Text('Send code'),
                      ),
                    ),
                  ] else ...[
                    _field(_codeCtrl, '6-digit code',
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: kTextPrimary, fontSize: 22, fontWeight: FontWeight.w600,
                          letterSpacing: 4,
                          fontFeatures: [FontFeature.tabularFigures()],
                        )),
                    const SizedBox(height: 24),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () {
                                hapticConfirm();
                                _verify();
                              },
                        child: _loading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: kTextSecondary),
                              )
                            : const Text('Verify'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: (_loading || _resendSeconds > 0) ? null : _sendCode,
                        child: Text(
                          _resendSeconds > 0 ? 'Resend code in ${_resendSeconds}s' : 'Resend code',
                          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A labelled text field: label above, theme-styled input below.
  Widget _field(TextEditingController ctrl, String label,
      {TextInputType? keyboardType, TextStyle? style}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextSecondary),
          ),
        ),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: style ?? const TextStyle(color: kTextPrimary, fontSize: 16),
        ),
      ],
    );
  }
}

/// Logo, large title and a one-line subtitle — the top of every auth screen.
class _AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _AuthHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BrandLogo(width: 132),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w700, color: kTextPrimary,
              letterSpacing: -0.6, height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: kTextSecondary, height: 1.4),
        ),
      ],
    );
  }
}

/// Inline form error: a neutral card with a red status icon.
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(kRadiusSm),
          border: Border.all(color: kBorder, width: 0.6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.error_outline_rounded, size: 18, color: kDanger),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, color: kTextPrimary, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
