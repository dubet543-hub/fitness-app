import 'package:flutter/material.dart';
import '../core/theme.dart';

class LoginScreen extends StatefulWidget {
  final Future<void> Function(String email, String password) onEmailSignIn;
  const LoginScreen({super.key, required this.onEmailSignIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool    _loading = false;
  bool    _obscure = true;
  String? _error;
  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
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
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned(
            top: -100, left: -80,
            child: Container(
              width: 350, height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [kAccent.withValues(alpha: 0.12), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 72, height: 72,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: kBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: kAccent.withValues(alpha: 0.15),
                                  blurRadius: 30, spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Image.asset('assets/images/solidcore_logo.png'),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'SolidCore',
                            style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800,
                              color: kTextPrimary, letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: kAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: kAccent.withValues(alpha: 0.25)),
                            ),
                            child: const Text(
                              'Performance Analytics Platform',
                              style: TextStyle(fontSize: 12, color: kAccent, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        _FeaturePill(icon: Icons.accessibility_new_rounded, label: 'Posture'),
                        SizedBox(width: 8),
                        _FeaturePill(icon: Icons.bar_chart_rounded, label: 'Training'),
                        SizedBox(width: 8),
                        _FeaturePill(icon: Icons.directions_run_rounded, label: 'Running'),
                      ],
                    ),
                    const SizedBox(height: 44),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700,
                              color: kTextPrimary, letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Sign in to your account',
                            style: TextStyle(fontSize: 13, color: kTextSecondary),
                          ),
                          const SizedBox(height: 24),
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.08),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded, size: 15, color: Colors.red.shade300),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(color: Colors.red.shade300, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                          _fieldLabel('Email address'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: kTextPrimary, fontSize: 14),
                            decoration: _inputDecor('you@example.com', Icons.mail_outline_rounded),
                          ),
                          const SizedBox(height: 16),
                          _fieldLabel('Password'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            style: const TextStyle(color: kTextPrimary, fontSize: 14),
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
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Your account is created by your coach or admin.\nContact them if you need access.',
                      style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.7),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecor(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kTextMuted, fontSize: 14),
    prefixIcon: Icon(icon, size: 18, color: kTextSecondary),
  );
}

Widget _fieldLabel(String text) => Text(
  text,
  style: const TextStyle(
    fontSize: 12, fontWeight: FontWeight.w600,
    color: kTextSecondary, letterSpacing: 0.2,
  ),
);

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: kAccent),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
