import 'package:flutter/material.dart';
import '../api_service.dart';
import '../core/theme.dart';
import '../navigation/main_shell.dart';
import '../services/dashboard_metrics.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await ApiService.getToken();
    ApiUser? user;
    if (token != null) {
      // Validate token with the backend; fall back to login if expired/invalid.
      user = await ApiService.verifyToken();
      if (user == null) await ApiService.clearSession();
    }
    if (mounted) {
      setState(() {
        _user     = user;
        _checking = false;
      });
    }
  }

  Future<void> _signInWithEmail(String email, String password) async {
    final result = await ApiService.login(email: email, password: password);
    AthleteMetricsService.invalidate(); // drop any prior user's cached metrics
    if (mounted) setState(() => _user = result.user);
  }

  Future<void> _register(String name, String email, String password, String? sport) async {
    final result = await ApiService.register(
      name: name, email: email, password: password, sport: sport);
    AthleteMetricsService.invalidate();
    if (mounted) setState(() { _user = result.user; _showRegister = false; });
  }

  Future<void> _signOut() async {
    await ApiService.clearSession();
    AthleteMetricsService.invalidate();
    if (mounted) setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const _SplashScreen();
    if (_user != null) {
      return MainShell(
        name:     _user!.name,
        email:    _user!.email,
        photoUrl: _user!.photoUrl,
        onLogout: _signOut,
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
