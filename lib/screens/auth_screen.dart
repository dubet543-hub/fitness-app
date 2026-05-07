import 'package:flutter/material.dart';
import '../api_service.dart';
import '../core/theme.dart';
import '../navigation/main_shell.dart';
import 'login_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  ApiUser? _user;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final user  = await ApiService.getCachedUser();
    final token = await ApiService.getToken();
    if (mounted) {
      setState(() {
        _user     = (user != null && token != null) ? user : null;
        _checking = false;
      });
    }
  }

  Future<void> _signInWithEmail(String email, String password) async {
    final result = await ApiService.login(email: email, password: password);
    if (mounted) setState(() => _user = result.user);
  }

  Future<void> _signOut() async {
    await ApiService.clearSession();
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
    return LoginScreen(onEmailSignIn: _signInWithEmail);
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: CircularProgressIndicator(color: kAccent, strokeWidth: 2),
      ),
    );
  }
}
