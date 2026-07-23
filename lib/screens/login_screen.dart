import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/local_log_store.dart';
import '../services/social_auth.dart';
import '../widgets/common_widgets.dart';
import '../widgets/legal_consent.dart';
import 'legal_pages.dart';

class LoginScreen extends StatefulWidget {
  final Future<void> Function(String email, String password) onEmailSignIn;

  /// Runs a federated provider flow (Google/Apple) and reports whether it
  /// produced a session — false means the user cancelled.
  final Future<bool> Function(SocialProvider provider)? onSocialSignIn;
  final VoidCallback? onCreateAccount;
  const LoginScreen({
    super.key,
    required this.onEmailSignIn,
    this.onSocialSignIn,
    this.onCreateAccount,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool    _loading  = false;
  bool    _obscure  = true;
  String? _error;
  bool    _remember = false;

  // Legal acceptance is one-time: once the current [kLegalVersion] has been
  // accepted the tick box is replaced by a compact "accepted" line, and sign-in
  // is no longer gated on it.
  bool      _agreedLegal   = false;
  bool      _alreadyAgreed = false;
  DateTime? _agreedAt;
  bool      _trackingConsent = false;

  // Provider buttons are hidden unless their OAuth client is configured, so a
  // half-set-up build never shows a button that can only fail.
  bool           _appleAvailable = false;
  SocialProvider? _socialBusy;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _loadConsentState();
    _loadAppleAvailability();
  }

  Future<void> _loadAppleAvailability() async {
    if (widget.onSocialSignIn == null) return;
    final available = await SocialAuth.appleAvailable();
    if (mounted) setState(() => _appleAvailable = available);
  }

  Future<void> _loadSavedCredentials() async {
    final creds = await LocalLogStore.savedCredentials();
    if (creds == null || !mounted) return;
    setState(() {
      _emailCtrl.text = creds.email;
      _passCtrl.text  = creds.password;
      _remember       = true;
    });
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

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    if (!_agreedLegal) {
      setState(() => _error =
          'Please accept the Terms & Conditions and Privacy Policy to continue.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onEmailSignIn(email, pass);
      await _recordConsent();
      if (_remember) {
        await LocalLogStore.saveCredentials(email, pass);
      } else {
        await LocalLogStore.clearCredentials();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Recorded only once a sign-in actually succeeds, so a failed attempt never
  /// leaves an acceptance behind for someone who never got in.
  Future<void> _recordConsent() async {
    await LocalLogStore.setLegalAccepted(kLegalVersion);
    if (!_alreadyAgreed) {
      await LocalLogStore.setDailyLogsConsent(_trackingConsent);
    }
  }

  Future<void> _submitSocial(SocialProvider provider) async {
    // The provider sheet bypasses the form, so the same acceptance gate has to
    // be enforced here or it could be used to sign in without agreeing.
    if (!_agreedLegal) {
      setState(() => _error =
          'Please accept the Terms & Conditions and Privacy Policy to continue.');
      return;
    }
    setState(() { _socialBusy = provider; _error = null; });
    try {
      final signedIn = await widget.onSocialSignIn!(provider);
      if (signedIn) await _recordConsent();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _socialBusy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [

          // ── Background bloom ─────────────────────────────────────────────
          Positioned(
            top: -80, left: 0, right: 0,
            height: 460,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 0.85,
                  colors: [
                    kAccent.withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 28),

                  // ── Logo ─────────────────────────────────────────────────
                  Center(
                    child: BrandLogo(width: 190),
                  ),
                  const SizedBox(height: 34),

                  _buildForm(),
                  const SizedBox(height: 18),
                  if (widget.onCreateAccount != null)
                    Center(
                      child: TextButton(
                        onPressed: widget.onCreateAccount,
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 13, color: kTextSecondary),
                            children: [
                              const TextSpan(text: "Don't have an account?  "),
                              TextSpan(
                                text: 'Create one',
                                style: TextStyle(color: kAccent, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kAccent.withValues(alpha: 0.38), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: kAccent.withValues(alpha: 0.13),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome back',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text('Sign in to your account', style: TextStyle(fontSize: 13, color: kTextSecondary)),
          const SizedBox(height: 24),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 15, color: Colors.red.shade300),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade300, fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          _fieldLabel('EMAIL'),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: kTextPrimary, fontSize: 14),
            decoration: _inputDecor('you@example.com', Icons.mail_outline_rounded),
          ),
          const SizedBox(height: 16),

          _fieldLabel('PASSWORD'),
          const SizedBox(height: 8),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: TextStyle(color: kTextPrimary, fontSize: 14),
            decoration: _inputDecor('••••••••', Icons.lock_outline_rounded).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18, color: kTextSecondary,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Remember me ───────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _remember = !_remember),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: _remember ? kAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _remember ? kAccent : kTextSecondary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: _remember
                      ? Icon(Icons.check_rounded, size: 14, color: kOnAccent)
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  'Remember my email & password',
                  style: TextStyle(fontSize: 13, color: kTextSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Terms, Privacy & tracking consent ─────────────────────
          // Asked once. After the current version has been accepted the
          // tick boxes give way to a one-line confirmation.
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
          const SizedBox(height: 20),

          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _loading || !_agreedLegal ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                disabledBackgroundColor: kAccent.withValues(alpha: 0.25),
                disabledForegroundColor: kOnAccent.withValues(alpha: 0.5),
                foregroundColor: kOnAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 8,
                shadowColor: kAccent.withValues(alpha: 0.55),
              ),
              child: _loading
                  ? SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: kOnAccent, strokeWidth: 2.5))
                  : const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
            ),
          ),

          ..._buildSocialSection(),
        ],
      ),
    );
  }

  // ── Google / Apple sign-in ──────────────────────────────────────────────
  // Each button is shown only when its OAuth client is configured for this
  // build, so an unconfigured provider is absent rather than broken.

  List<Widget> _buildSocialSection() {
    if (widget.onSocialSignIn == null) return const [];
    final showGoogle = SocialAuth.googleAvailable;
    if (!showGoogle && !_appleAvailable) return const [];

    return [
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: Divider(color: kBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: kTextMuted, letterSpacing: 1.2)),
        ),
        Expanded(child: Divider(color: kBorder)),
      ]),
      const SizedBox(height: 16),
      if (showGoogle) ...[
        _SocialButton(
          label: 'Continue with Google',
          icon: const _GoogleGlyph(),
          busy: _socialBusy == SocialProvider.google,
          enabled: _agreedLegal && _socialBusy == null && !_loading,
          onTap: () => _submitSocial(SocialProvider.google),
        ),
        if (_appleAvailable) const SizedBox(height: 10),
      ],
      if (_appleAvailable)
        _SocialButton(
          label: 'Continue with Apple',
          icon: Icon(Icons.apple, size: 21, color: kTextPrimary),
          busy: _socialBusy == SocialProvider.apple,
          enabled: _agreedLegal && _socialBusy == null && !_loading,
          onTap: () => _submitSocial(SocialProvider.apple),
        ),
    ];
  }

  InputDecoration _inputDecor(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: kTextMuted, fontSize: 14),
    prefixIcon: Icon(icon, size: 18, color: kAccent.withValues(alpha: 0.65)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: kAccent.withValues(alpha: 0.28)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: kAccent, width: 1.5),
    ),
    filled: true,
    fillColor: const Color(0xFF0A0A14),
  );
}

Widget _fieldLabel(String text) => Text(
  text,
  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.2),
);

/// Outlined provider button, sized and shaped to match the Sign In button.
class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final bool   busy;
  final bool   enabled;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SizedBox(
        height: 50,
        child: OutlinedButton(
          onPressed: enabled ? onTap : null,
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFF0A0A14),
            side: BorderSide(color: kBorderBright),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: busy
              ? SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: kTextSecondary, strokeWidth: 2.2))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    const SizedBox(width: 10),
                    Text(label, style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w600, color: kTextPrimary)),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Google's four-colour "G", drawn rather than shipped as an asset.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) => Container(
    width: 20, height: 20,
    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    alignment: Alignment.center,
    child: const Text('G', style: TextStyle(
      fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4285F4), height: 1.15)),
  );
}
