import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/local_log_store.dart';

class LoginScreen extends StatefulWidget {
  final Future<void> Function(String email, String password) onEmailSignIn;
  final VoidCallback? onCreateAccount;
  const LoginScreen({super.key, required this.onEmailSignIn, this.onCreateAccount});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool    _loading  = false;
  bool    _obscure  = true;
  String? _error;
  bool    _lampOn   = false;
  bool    _remember = false;

  late final AnimationController _revealCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double>   _revealAnim;
  late final Animation<double>   _glowAnim;

  @override
  void initState() {
    super.initState();

    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _revealAnim = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOutCubic);

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);

    _loadSavedCredentials();
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

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _revealCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _toggleLamp() {
    setState(() => _lampOn = !_lampOn);
    if (_lampOn) {
      _revealCtrl.forward();
      _glowCtrl.repeat(reverse: true);
    } else {
      _revealCtrl.reverse();
      _glowCtrl.stop();
      _glowCtrl.value = 0;
    }
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onEmailSignIn(email, pass);
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
            child: AnimatedBuilder(
              animation: Listenable.merge([_revealAnim, _glowAnim]),
              builder: (_, __) => Opacity(
                opacity: _revealAnim.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      radius: 0.85,
                      colors: [
                        kAccent.withValues(alpha: 0.20 + 0.10 * _glowAnim.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
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
                    child: Image.asset('assets/images/solidcore_logo.png', width: 190),
                  ),
                  const SizedBox(height: 20),

                  // ── Lamp ─────────────────────────────────────────────────
                  Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_revealAnim, _glowAnim]),
                      builder: (_, __) => _LampWidget(
                        isOn:   _lampOn,
                        glow:   _glowAnim.value,
                        reveal: _revealAnim.value,
                        onTap:  _toggleLamp,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Hint ─────────────────────────────────────────────────
                  AnimatedOpacity(
                    opacity: _lampOn ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 400),
                    child: const Center(
                      child: Text(
                        'Pull the cord to sign in',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0x55FFFFFF),
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),

                  // ── Form reveal ───────────────────────────────────────────
                  FadeTransition(
                    opacity: _revealAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.06),
                        end:   Offset.zero,
                      ).animate(_revealAnim),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 14),
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
                        ],
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
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
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
          const SizedBox(height: 20),

          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 8,
                shadowColor: kAccent.withValues(alpha: 0.55),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                  : const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
            ),
          ),
        ],
      ),
    );
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

// ── Lamp Widget ───────────────────────────────────────────────────────────────
// StatefulWidget so the cord AnimationController lives here, not in the parent.
// This guarantees the animation fires immediately on tap with no prop-passing lag.

class _LampWidget extends StatefulWidget {
  final bool         isOn;
  final double       glow;
  final double       reveal;
  final VoidCallback onTap;

  const _LampWidget({
    required this.isOn,
    required this.glow,
    required this.reveal,
    required this.onTap,
  });

  @override
  State<_LampWidget> createState() => _LampWidgetState();
}

class _LampWidgetState extends State<_LampWidget>
    with SingleTickerProviderStateMixin {

  late final AnimationController _cordCtrl;
  late final Animation<double>   _cordAnim;
  double _cordAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _cordCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _cordAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0,  end:  0.65), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.65, end: -0.40), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.40, end:  0.22), weight: 22),
      TweenSequenceItem(tween: Tween(begin:  0.22, end: -0.10), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.10, end:  0.0),  weight: 18),
    ]).animate(_cordCtrl);

    // addListener+setState is the most reliable animation approach on Android —
    // no AnimatedBuilder indirection that could be dropped on widget rebuild.
    _cordCtrl.addListener(() {
      if (mounted) setState(() => _cordAngle = _cordAnim.value);
    });
  }

  @override
  void dispose() {
    _cordCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap();
    _cordCtrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 180,
        height: 240,
        child: _buildLamp(_cordAngle),
      ),
    );
  }

  Widget _buildLamp(double cordRad) {
    final isOn       = widget.isOn;
    final glow       = widget.glow;
    final reveal     = widget.reveal;
    final shadeColor = isOn
        ? Color.lerp(const Color(0xFFF5F0E0), Colors.white, glow * 0.4)!
        : const Color(0xFF6A6050);

    return Stack(
      alignment: Alignment.topCenter,
      children: [

        // ── Light cone ─────────────────────────────────────────────────
        if (reveal > 0)
          Positioned(
            top: 82, left: 15, right: 15,
            child: Opacity(
              opacity: reveal,
              child: ClipPath(
                clipper: _ConeClipper(),
                child: Container(
                  height: 155,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end:   Alignment.bottomCenter,
                      colors: [
                        kAccent.withValues(alpha: 0.28 + 0.10 * glow),
                        kAccent.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // ── Shade ──────────────────────────────────────────────────────
        Positioned(
          top: 0,
          child: Container(
            width: 152,
            height: 90,
            decoration: BoxDecoration(
              color: shadeColor,
              borderRadius: const BorderRadius.only(
                topLeft:  Radius.circular(76),
                topRight: Radius.circular(76),
              ),
              boxShadow: isOn
                  ? [
                      BoxShadow(
                        color: kAccent.withValues(alpha: 0.48 + 0.22 * glow),
                        blurRadius: 42 + 18 * glow,
                        spreadRadius: 5,
                        offset: const Offset(0, 22),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.18 + 0.12 * glow),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft:  Radius.circular(76),
                  topRight: Radius.circular(76),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: isOn ? 0.60 + 0.20 * glow : 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Neck ───────────────────────────────────────────────────────
        Positioned(
          top: 87,
          child: Container(
            width: 12,
            height: 98,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end:   Alignment.centerRight,
                colors: [Color(0xFF5A5040), Color(0xFF3A3025)],
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 6),
              ],
            ),
          ),
        ),

        // ── Cord line — single Container rotated around its top-center ──
        // Pivot point in stack coords: x=108 (90+18), y=88
        Positioned(
          top: 88,
          left: 108 - 1.5, // center the 3px cord at pivot x
          child: Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.rotationZ(cordRad),
            child: Container(
              width: 3,
              height: 65,
              decoration: BoxDecoration(
                color: const Color(0xFFD8D8D8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),

        // ── Bead — computed position via sin/cos, no transform needed ───
        Positioned(
          top:  88 + cos(cordRad) * 76 - 11,
          left: 108 + sin(cordRad) * 76 - 11,
          child: Container(
            width:  22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOn ? kAccent : Color(0xFFCC9900),
              boxShadow: isOn
                  ? [
                      BoxShadow(
                        color: kAccent.withValues(alpha: 0.85 + 0.15 * glow),
                        blurRadius: 16 + 8 * glow,
                        spreadRadius: 4,
                      ),
                    ]
                  : [
                      BoxShadow(color: Colors.amber.withValues(alpha: 0.35), blurRadius: 8),
                      BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
            ),
          ),
        ),

        // ── Base ───────────────────────────────────────────────────────
        Positioned(
          bottom: 4,
          child: Container(
            width: 96,
            height: 13,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5A5040), Color(0xFF3A3025)],
              ),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),

      ],
    );
  }
}

// ── Cone Clipper ──────────────────────────────────────────────────────────────

class _ConeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * 0.28, 0)
    ..lineTo(size.width * 0.72, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(_) => false;
}


Widget _fieldLabel(String text) => Text(
  text,
  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.2),
);
