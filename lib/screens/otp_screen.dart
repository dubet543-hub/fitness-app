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
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: kTextPrimary),
          onPressed: _loading
              ? null
              : (onCode
                  ? () => setState(() { _stage = _OtpStage.email; _error = null; })
                  : widget.onBack),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(child: BrandLogo(width: 150)),
              const SizedBox(height: 8),
              Text(
                onCode ? 'Enter your code' : 'Sign in with a code',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                    color: kTextPrimary, letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              Text(
                onCode
                    ? 'Enter the 6-digit code sent to $_email'
                    : "We'll email you a 6-digit code — no password needed.",
                style: TextStyle(fontSize: 13, color: kTextSecondary),
              ),
              const SizedBox(height: 24),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline_rounded, size: 15, color: Colors.red.shade300),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: TextStyle(color: Colors.red.shade300, fontSize: 13))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              if (!onCode) ...[
                _field(_emailCtrl, 'Email', Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 20),

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
                  const SizedBox(height: 12),
                  TrackingConsentCheckbox(
                    value: _trackingConsent,
                    onChanged: (v) => setState(() => _trackingConsent = v),
                  ),
                ],
                const SizedBox(height: 24),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading || !_agreedLegal ? null : _sendCode,
                    style: ElevatedButton.styleFrom(
                      disabledBackgroundColor: kAccent.withValues(alpha: 0.25),
                      disabledForegroundColor: kOnAccent.withValues(alpha: 0.5),
                    ),
                    child: _loading
                        ? SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: kOnAccent))
                        : const Text('Send code',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  ),
                ),
              ] else ...[
                _field(_codeCtrl, '6-digit code', Icons.pin_outlined,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 20),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      disabledBackgroundColor: kAccent.withValues(alpha: 0.25),
                      disabledForegroundColor: kOnAccent.withValues(alpha: 0.5),
                    ),
                    child: _loading
                        ? SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: kOnAccent))
                        : const Text('Verify',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: (_loading || _resendSeconds > 0) ? null : _sendCode,
                    child: Text(
                      _resendSeconds > 0 ? 'Resend code in ${_resendSeconds}s' : 'Resend code',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: _resendSeconds > 0 ? kTextMuted : kAccent),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(color: kTextPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: kTextSecondary, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: kAccent.withValues(alpha: 0.65)),
        filled: true,
        fillColor: const Color(0xFF0F0F18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: kAccent.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}
