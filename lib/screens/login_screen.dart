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

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool    _loading  = false;
  bool    _obscure  = true;
  String? _error;
  bool    _remember = false;

  @override
  void initState() {
    super.initState();
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
                    child: Image.asset('assets/images/solidcore_logo.png', width: 190),
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

Widget _fieldLabel(String text) => Text(
  text,
  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.2),
);
