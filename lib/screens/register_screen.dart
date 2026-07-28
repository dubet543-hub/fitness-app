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
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: kTextPrimary),
          onPressed: _loading ? null : widget.onBackToLogin,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: BrandLogo(width: 150),
              ),
              const SizedBox(height: 8),
              Text('Create your account',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                      color: kTextPrimary, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text('Sign up to start tracking your performance',
                  style: TextStyle(fontSize: 13, color: kTextSecondary)),
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

              _field(_nameCtrl,    'Full name',        Icons.person_outline_rounded),
              const SizedBox(height: 12),
              _field(_emailCtrl,   'Email',            Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _field(_sportCtrl,   'Sport (optional)', Icons.sports_rounded),
              const SizedBox(height: 12),
              _field(_passCtrl,    'Password',         Icons.lock_outline_rounded,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 18, color: kTextSecondary),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )),
              const SizedBox(height: 12),
              _field(_confirmCtrl, 'Confirm password', Icons.lock_outline_rounded,
                  obscure: _obscure),
              const SizedBox(height: 20),

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
              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading || !_agreedLegal ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: kAccent.withValues(alpha: 0.25),
                    disabledForegroundColor: kOnAccent.withValues(alpha: 0.5),
                  ),
                  child: _loading
                      ? SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kOnAccent))
                      : const Text('Create Account',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : widget.onBackToLogin,
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 13, color: kTextSecondary),
                      children: [
                        const TextSpan(text: 'Already have an account?  '),
                        TextSpan(text: 'Sign in',
                            style: TextStyle(color: kAccent, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.onOtpSignIn != null)
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : widget.onOtpSignIn,
                    child: Text('Or create an account with a one-time code',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kAccent)),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool obscure = false, TextInputType? keyboardType, Widget? suffix}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(color: kTextPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: kTextSecondary, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: kAccent.withValues(alpha: 0.65)),
        suffixIcon: suffix,
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
