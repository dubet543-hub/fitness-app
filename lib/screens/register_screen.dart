import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/local_log_store.dart';
import '../widgets/common_widgets.dart';
import '../widgets/legal_consent.dart';
import 'legal_pages.dart';

class RegisterScreen extends StatefulWidget {
  final Future<void> Function(String name, String email, String password, String? sport) onRegister;
  final VoidCallback onBackToLogin;
  final VoidCallback? onOtpSignIn;
  const RegisterScreen({
    super.key,
    required this.onRegister,
    required this.onBackToLogin,
    this.onOtpSignIn,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _sportCtrl   = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  // A new account is a new person, so acceptance is always asked for here even
  // if a previous user of this device already accepted.
  bool _agreedLegal     = false;
  bool _trackingConsent = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _sportCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name    = _nameCtrl.text.trim();
    final email   = _emailCtrl.text.trim();
    final pass    = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in name, email and password.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (!_agreedLegal) {
      setState(() => _error =
          'Please accept the Terms & Conditions and Privacy Policy to continue.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await widget.onRegister(name, email, pass, _sportCtrl.text.trim());
      await LocalLogStore.setLegalAccepted(kLegalVersion);
      await LocalLogStore.setDailyLogsConsent(_trackingConsent);
      // On success the AuthScreen swaps to the main app; nothing more to do here.
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.adaptive.arrow_back),
          onPressed: _loading ? null : widget.onBackToLogin,
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
                  const _AuthHeader(
                    title: 'Create your account',
                    subtitle: 'Sign up to start tracking your performance',
                  ),
                  const SizedBox(height: 32),

                  if (_error != null) ...[
                    _ErrorBanner(message: _error!),
                    const SizedBox(height: 20),
                  ],

                  _field(_nameCtrl, 'Full name'),
                  const SizedBox(height: 16),
                  _field(_emailCtrl, 'Email', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _field(_sportCtrl, 'Sport (optional)'),
                  const SizedBox(height: 16),
                  _field(_passCtrl, 'Password',
                      obscure: _obscure,
                      suffix: IconButton(
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20, color: kTextSecondary,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      )),
                  const SizedBox(height: 16),
                  _field(_confirmCtrl, 'Confirm password', obscure: _obscure),
                  const SizedBox(height: 24),

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
                  const SizedBox(height: 22),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading || !_agreedLegal
                          ? null
                          : () {
                              hapticConfirm();
                              _submit();
                            },
                      child: _loading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: kTextSecondary),
                            )
                          : const Text('Create Account'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _loading ? null : widget.onBackToLogin,
                      child: const Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: kTextSecondary),
                          children: [
                            TextSpan(text: 'Already have an account? '),
                            TextSpan(
                              text: 'Sign in',
                              style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (widget.onOtpSignIn != null)
                    Center(
                      child: TextButton(
                        onPressed: _loading ? null : widget.onOtpSignIn,
                        child: const Text('Or create an account with a one-time code'),
                      ),
                    ),
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
      {bool obscure = false, TextInputType? keyboardType, Widget? suffix}) {
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
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(color: kTextPrimary, fontSize: 16),
          decoration: InputDecoration(suffixIcon: suffix),
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
