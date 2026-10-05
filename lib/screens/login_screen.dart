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
  final VoidCallback? onOtpSignIn;
  const LoginScreen({
    super.key,
    required this.onEmailSignIn,
    this.onSocialSignIn,
    this.onCreateAccount,
    this.onOtpSignIn,
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
      backgroundColor: kBg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(kGutter, 24, kGutter, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _AuthHeader(
                    title: 'Welcome back',
                    subtitle: 'Sign in to your account',
                  ),
                  const SizedBox(height: 32),

                  ..._buildForm(),

                  if (widget.onCreateAccount != null) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: widget.onCreateAccount,
                        child: const Text.rich(
                          TextSpan(
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: kTextSecondary),
                            children: [
                              TextSpan(text: "Don't have an account? "),
                              TextSpan(
                                text: 'Create one',
                                style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
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

  List<Widget> _buildForm() {
    return [
      if (_error != null) ...[
        _ErrorBanner(message: _error!),
        const SizedBox(height: 20),
      ],

      const _FieldLabel('Email'),
      TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        style: _kInputText,
        decoration: const InputDecoration(hintText: 'you@example.com'),
      ),
      const SizedBox(height: 16),

      const _FieldLabel('Password'),
      TextField(
        controller: _passCtrl,
        obscureText: _obscure,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        style: _kInputText,
        decoration: InputDecoration(
          hintText: '••••••••',
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Show password' : 'Hide password',
            icon: Icon(
              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20, color: kTextSecondary,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      if (widget.onOtpSignIn != null)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: widget.onOtpSignIn,
            style: TextButton.styleFrom(
              foregroundColor: kTextSecondary,
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            child: const Text('Forgot password?'),
          ),
        )
      else
        const SizedBox(height: 10),
      const SizedBox(height: 4),

      // ── Remember me ───────────────────────────────────────────────────
      // Same tick box as the consent rows below, so the three read as one group.
      ConsentTickBox(
        value: _remember,
        onChanged: (v) => setState(() => _remember = v),
        label: const Text(
          'Remember my email & password',
          style: TextStyle(fontSize: 14, color: kTextSecondary, height: 1.45),
        ),
      ),
      const SizedBox(height: 4),

      // ── Terms, Privacy & tracking consent ─────────────────────────────
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
        const SizedBox(height: 4),
        TrackingConsentCheckbox(
          value: _trackingConsent,
          onChanged: (v) => setState(() => _trackingConsent = v),
        ),
      ],
      const SizedBox(height: 24),

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
              : const Text('Sign In'),
        ),
      ),

      if (widget.onOtpSignIn != null) ...[
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: widget.onOtpSignIn,
            child: const Text('Or sign in with a one-time code'),
          ),
        ),
      ],

      ..._buildSocialSection(),
    ];
  }

  // ── Google / Apple sign-in ──────────────────────────────────────────────
  // Each button is shown only when its OAuth client is configured for this
  // build, so an unconfigured provider is absent rather than broken.

  List<Widget> _buildSocialSection() {
    if (widget.onSocialSignIn == null) return const [];
    final showGoogle = SocialAuth.googleAvailable;
    if (!showGoogle && !_appleAvailable) return const [];

    return [
      const SizedBox(height: 24),
      const Row(children: [
        Expanded(child: Divider(height: 0.6, thickness: 0.6, color: kBorder)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text('or', style: TextStyle(fontSize: 13, color: kTextMuted)),
        ),
        Expanded(child: Divider(height: 0.6, thickness: 0.6, color: kBorder)),
      ]),
      const SizedBox(height: 24),
      if (showGoogle) ...[
        _SocialButton(
          label: 'Continue with Google',
          icon: const _GoogleGlyph(),
          busy: _socialBusy == SocialProvider.google,
          enabled: _agreedLegal && _socialBusy == null && !_loading,
          onTap: () => _submitSocial(SocialProvider.google),
        ),
        if (_appleAvailable) const SizedBox(height: 12),
      ],
      if (_appleAvailable)
        _SocialButton(
          label: 'Continue with Apple',
          icon: const Icon(Icons.apple, size: 22, color: kTextPrimary),
          busy: _socialBusy == SocialProvider.apple,
          enabled: _agreedLegal && _socialBusy == null && !_loading,
          onTap: () => _submitSocial(SocialProvider.apple),
        ),
    ];
  }
}

const TextStyle _kInputText = TextStyle(color: kTextPrimary, fontSize: 16);

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

/// Label above a text field.
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextSecondary),
    ),
  );
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

/// Neutral outlined provider button, the same height as the Sign In button.
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
        height: 52,
        child: OutlinedButton(
          onPressed: enabled ? onTap : null,
          child: busy
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(color: kTextSecondary, strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 22, child: Center(child: icon)),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kTextPrimary),
                      ),
                    ),
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
