import 'package:flutter/material.dart';
import '../api_service.dart';
import '../core/theme.dart';
import '../navigation/main_shell.dart';
import '../services/dashboard_metrics.dart';
import '../services/entitlements.dart';
import '../services/local_log_store.dart';
import '../services/social_auth.dart';
import '../widgets/common_widgets.dart';
import 'legal_consent_gate.dart';
import 'legal_pages.dart';
import 'login_screen.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  ApiUser? _user;
  bool _checking = true;
  bool _showRegister = false;
  bool _showOtp = false;
  // Set when a restored session predates the current Terms & Privacy Policy —
  // sign-ins made through the login/register form accept there instead.
  bool _needsLegal = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await ApiService.getToken();
    ApiUser? user;
    if (token != null) {
      // Validate token with the backend; only a real 401/403 rejection logs
      // the user out. A network error (offline, backend momentarily down)
      // keeps the cached session instead of discarding valid credentials.
      try {
        user = await ApiService.verifyToken();
        if (user == null) await ApiService.clearSession();
      } catch (_) {
        user = await ApiService.getCachedUser();
      }
      if (user != null) EntitlementsService.load(refresh: true).ignore();
    }
    final accepted = await LocalLogStore.hasAcceptedLegal(kLegalVersion);
    if (mounted) {
      setState(() {
        _user       = user;
        _needsLegal = user != null && !accepted;
        _checking   = false;
      });
    }
  }

  Future<void> _signInWithEmail(String email, String password) async {
    final result = await ApiService.login(email: email, password: password);
    AthleteMetricsService.invalidate(); // drop any prior user's cached metrics
    await EntitlementsService.invalidate();
    EntitlementsService.load(refresh: true).ignore(); // prime plan gates
    if (mounted) setState(() { _user = result.user; _needsLegal = false; });
  }

  /// Runs a provider flow. Returns false when the user cancelled, so the
  /// caller knows not to record consent for a sign-in that never happened.
  Future<bool> _signInWithProvider(SocialProvider provider) async {
    final result = await SocialAuth.signIn(provider);
    if (result == null) return false;
    AthleteMetricsService.invalidate();
    await EntitlementsService.invalidate();
    EntitlementsService.load(refresh: true).ignore();
    if (mounted) setState(() { _user = result.user; _needsLegal = false; });
    return true;
  }

  Future<void> _register(String name, String email, String password, String? sport) async {
    final result = await ApiService.register(
      name: name, email: email, password: password, sport: sport);
    AthleteMetricsService.invalidate();
    await EntitlementsService.invalidate();
    EntitlementsService.load(refresh: true).ignore();
    if (mounted) {
      setState(() { _user = result.user; _needsLegal = false; _showRegister = false; });
    }
  }

  Future<void> _requestOtp(String email) => ApiService.requestOtp(email: email);

  /// Verifies the emailed code; the backend logs in if the account exists or
  /// creates one otherwise, so this mirrors _signInWithEmail either way.
  Future<void> _verifyOtpAndSignIn(String email, String code) async {
    final result = await ApiService.verifyOtp(email: email, code: code);
    AthleteMetricsService.invalidate();
    await EntitlementsService.invalidate();
    EntitlementsService.load(refresh: true).ignore();
    if (mounted) setState(() { _user = result.user; _needsLegal = false; _showOtp = false; });
  }

  Future<void> _signOut() async {
    await ApiService.clearSession();
    await SocialAuth.signOut(); // so the next Google sign-in re-shows the picker
    AthleteMetricsService.invalidate();
    await EntitlementsService.invalidate();
    if (mounted) setState(() { _user = null; _needsLegal = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const _SplashScreen();
    if (_user != null && _needsLegal) {
      return LegalConsentGate(
        onAccepted: () => setState(() => _needsLegal = false),
        onSignOut: _signOut,
      );
    }
    if (_user != null) {
      return MainShell(
        name:     _user!.name,
        email:    _user!.email,
        photoUrl: _user!.photoUrl,
        onLogout: _signOut,
      );
    }
    if (_showOtp) {
      return OtpScreen(
        onRequestOtp: _requestOtp,
        onVerifyOtp: _verifyOtpAndSignIn,
        onBack: () => setState(() => _showOtp = false),
      );
    }
    if (_showRegister) {
      return RegisterScreen(
        onRegister: _register,
        onBackToLogin: () => setState(() => _showRegister = false),
      );
    }
    return LoginScreen(
      onEmailSignIn: _signInWithEmail,
      onSocialSignIn: _signInWithProvider,
      onCreateAccount: () => setState(() => _showRegister = true),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(width: 200),
            const SizedBox(height: 28),
            CircularProgressIndicator(color: kAccent, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}
