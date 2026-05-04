import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'posture_screen.dart';
import 'training_load_screen.dart';
import 'running_analysis_screen.dart';
import 'bowling_analysis_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load environment variables from .env (preferred), then assets/config.json.
  await dotenv.load(fileName: '.env');
  await ApiService.loadConfig();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D1117),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const FitnessApp());
}

// ── Palette ────────────────────────────────────────────────────────────────────
const Color kBg            = Color(0xFF080B10);
const Color kSurface       = Color(0xFF0F1318);
const Color kCard          = Color(0xFF141923);
const Color kCardAlt       = Color(0xFF1A2130);
const Color kAccent        = Color(0xFFFF6B35);
const Color kAccentSoft    = Color(0xFFFF8C5A);
const Color kBorder        = Color(0xFF1F2937);
const Color kBorderBright  = Color(0xFF2D3748);
const Color kTextPrimary   = Color(0xFFF1F5F9);
const Color kTextSecondary = Color(0xFF64748B);
const Color kTextMuted     = Color(0xFF3D4F63);

// ── App ────────────────────────────────────────────────────────────────────────
class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SolidCore',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        fontFamily: 'SF Pro Display',
        colorScheme: const ColorScheme.dark(
          primary: kAccent,
          secondary: kAccent,
          surface: kSurface,
          onPrimary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: kTextPrimary),
          titleTextStyle: TextStyle(
            color: kTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kCard,
          labelStyle: const TextStyle(color: kTextSecondary, fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kAccent, width: 1.5),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: kCardAlt,
          contentTextStyle: const TextStyle(color: kTextPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
        useMaterial3: false,
      ),
      home: const AuthScreen(),
    );
  }
}

// ── Auth ───────────────────────────────────────────────────────────────────────
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
    if (mounted) setState(() {
      _user     = (user != null && token != null) ? user : null;
      _checking = false;
    });
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
    return _LoginScreen(onEmailSignIn: _signInWithEmail);
  }
}

// ── Splash ─────────────────────────────────────────────────────────────────────
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

// ── Login ──────────────────────────────────────────────────────────────────────
class _LoginScreen extends StatefulWidget {
  final Future<void> Function(String email, String password) onEmailSignIn;
  const _LoginScreen({required this.onEmailSignIn});
  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool    _loading = false;
  bool    _obscure = true;
  String? _error;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

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
          // Ambient glow top
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
                    // Logo block
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
                                BoxShadow(color: kAccent.withValues(alpha: 0.15), blurRadius: 30, spreadRadius: 2),
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

                    // Feature pills
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

                    // Card container
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

                          _FieldLabel('Email address'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: kTextPrimary, fontSize: 14),
                            decoration: _inputDecor('you@example.com', Icons.mail_outline_rounded),
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel('Password'),
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
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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

Widget _FieldLabel(String text) => Text(
  text,
  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary, letterSpacing: 0.2),
);

// ── Main Shell with Bottom Nav ─────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  final String  name;
  final String  email;
  final String? photoUrl;
  final VoidCallback onLogout;

  const MainShell({
    super.key,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.onLogout,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeTab(name: widget.name, email: widget.email, photoUrl: widget.photoUrl, onLogout: widget.onLogout),
      const ExploreTab(),
      const AnalyticsTab(),
      ProfileTab(name: widget.name, email: widget.email, photoUrl: widget.photoUrl, onLogout: widget.onLogout),
    ];

    return Scaffold(
      backgroundColor: kBg,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── Bottom Nav Bar ─────────────────────────────────────────────────────────────
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.grid_view_rounded,       activeIcon: Icons.grid_view_rounded,         label: 'Home'),
      _NavItem(icon: Icons.explore_outlined,         activeIcon: Icons.explore_rounded,            label: 'Explore'),
      _NavItem(icon: Icons.analytics_outlined,       activeIcon: Icons.analytics_rounded,          label: 'Analytics'),
      _NavItem(icon: Icons.person_outline_rounded,   activeIcon: Icons.person_rounded,             label: 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        border: const Border(top: BorderSide(color: kBorder, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: isActive ? kAccent.withValues(alpha: 0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isActive ? items[i].activeIcon : items[i].icon,
                            size: 22,
                            color: isActive ? kAccent : kTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          items[i].label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                            color: isActive ? kAccent : kTextSecondary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

// ── Home Tab ───────────────────────────────────────────────────────────────────
class HomeTab extends StatelessWidget {
  final String  name;
  final String  email;
  final String? photoUrl;
  final VoidCallback onLogout;

  const HomeTab({super.key, required this.name, required this.email, required this.photoUrl, required this.onLogout});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _firstName => name.split(' ').first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          // ── Custom App Bar ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            snap: true,
            backgroundColor: kSurface,
            elevation: 0,
            centerTitle: false,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Image.asset('assets/images/solidcore_logo.png', height: 28),
                const SizedBox(width: 10),
                const Text(
                  'SolidCore',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.5),
                ),
              ],
            ),
            actions: [
              // Notification bell
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                ),
                child: Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, size: 20, color: kTextSecondary),
                      onPressed: () {},
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: kBorder),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greeting, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              _firstName,
                              style: const TextStyle(
                                fontSize: 32, fontWeight: FontWeight.w800,
                                color: kTextPrimary, letterSpacing: -0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _AvatarWidget(name: name, photoUrl: photoUrl, radius: 24),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Quick stats strip
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kAccent.withValues(alpha: 0.15), kAccent.withValues(alpha: 0.05)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kAccent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: kAccent, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Weekly Streak', style: TextStyle(fontSize: 11, color: kTextSecondary)),
                              Text('5 days active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: kAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('View', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Section header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Features',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.3),
                      ),
                      Text(
                        'See all',
                        style: TextStyle(fontSize: 13, color: kAccent, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          // Feature grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              delegate: SliverChildListDelegate([
                _FeatureCard(
                  icon: Icons.accessibility_new_rounded,
                  title: 'Posture\nAnalysis',
                  subtitle: 'Check body alignment',
                  accentColor: const Color(0xFF38BDF8),
                  gradientColors: const [Color(0xFF0C2A4A), Color(0xFF071829)],
                  onTap: () => Navigator.push(context, _route(const PostureGuideScreen())),
                ),
                _FeatureCard(
                  icon: Icons.bar_chart_rounded,
                  title: 'Training\nLoad',
                  subtitle: 'Monitor workload',
                  accentColor: const Color(0xFF34D399),
                  gradientColors: const [Color(0xFF063A20), Color(0xFF032513)],
                  onTap: () => Navigator.push(context, _route(const TrainingLoadScreen())),
                ),
                _FeatureCard(
                  icon: Icons.directions_run_rounded,
                  title: 'Running\nAnalysis',
                  subtitle: 'Improve running form',
                  accentColor: const Color(0xFFFB923C),
                  gradientColors: const [Color(0xFF4A1500), Color(0xFF2E0D00)],
                  onTap: () => Navigator.push(context, _route(const RunningAnalysisScreen())),
                ),
                _FeatureCard(
                  icon: Icons.sports_cricket_rounded,
                  title: 'Bowling\nAnalysis',
                  subtitle: 'Perfect technique',
                  accentColor: const Color(0xFFC084FC),
                  gradientColors: const [Color(0xFF2D0A52), Color(0xFF1C0635)],
                  onTap: () => Navigator.push(context, _route(const BowlingAnalysisScreen())),
                ),
              ]),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.88,
              ),
            ),
          ),

          // Recent sessions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Sessions',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.3),
                  ),
                  Text('All', style: TextStyle(fontSize: 13, color: kAccent, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _RecentSessionCard(
                  icon: Icons.directions_run_rounded,
                  color: const Color(0xFFFB923C),
                  title: 'Running Analysis',
                  subtitle: 'Stride length · Cadence · Ground contact',
                  time: '2h ago',
                  score: '87',
                ),
                const SizedBox(height: 10),
                _RecentSessionCard(
                  icon: Icons.accessibility_new_rounded,
                  color: const Color(0xFF38BDF8),
                  title: 'Posture Check',
                  subtitle: 'Shoulder · Spine · Hip alignment',
                  time: 'Yesterday',
                  score: '92',
                ),
                const SizedBox(height: 10),
                _RecentSessionCard(
                  icon: Icons.bar_chart_rounded,
                  color: const Color(0xFF34D399),
                  title: 'Training Load',
                  subtitle: 'Volume · Intensity · Recovery',
                  time: '2d ago',
                  score: '78',
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Route _route(Widget screen) =>
      MaterialPageRoute(builder: (_) => screen);
}

// ── Explore Tab ────────────────────────────────────────────────────────────────
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        title: const Text('Explore', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary)),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: kBorder)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Container(
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
              ),
              child: const TextField(
                style: TextStyle(color: kTextPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search exercises, drills...',
                  hintStyle: TextStyle(color: kTextMuted, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: kTextSecondary, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),

            const _SectionHeader('Categories'),
            const SizedBox(height: 14),
            SizedBox(
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  _CategoryChip(icon: Icons.fitness_center_rounded,      label: 'Strength',   color: Color(0xFF38BDF8)),
                  _CategoryChip(icon: Icons.directions_run_rounded,       label: 'Cardio',     color: Color(0xFFFB923C)),
                  _CategoryChip(icon: Icons.self_improvement_rounded,     label: 'Mobility',   color: Color(0xFF34D399)),
                  _CategoryChip(icon: Icons.sports_cricket_rounded,       label: 'Cricket',    color: Color(0xFFC084FC)),
                  _CategoryChip(icon: Icons.sports_soccer_rounded,        label: 'Football',   color: Color(0xFFFBBF24)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const _SectionHeader('Trending Drills'),
            const SizedBox(height: 14),
            ...[
              _DrillCard(title: 'Hip Hinge Pattern', category: 'Mobility', level: 'Intermediate', color: const Color(0xFF34D399)),
              const SizedBox(height: 10),
              _DrillCard(title: 'Sprint Acceleration', category: 'Cardio', level: 'Advanced', color: const Color(0xFFFB923C)),
              const SizedBox(height: 10),
              _DrillCard(title: 'Thoracic Rotation', category: 'Strength', level: 'Beginner', color: const Color(0xFF38BDF8)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Analytics Tab ──────────────────────────────────────────────────────────────
class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        title: const Text('Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kCard, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: kTextSecondary),
                SizedBox(width: 6),
                Text('This Week', style: TextStyle(fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w500)),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: kTextSecondary),
              ],
            ),
          ),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: kBorder)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats row
            Row(
              children: [
                Expanded(child: _StatCard(label: 'Sessions', value: '12', icon: Icons.play_circle_outline_rounded, color: const Color(0xFF38BDF8))),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(label: 'Avg Score', value: '85', icon: Icons.stars_rounded, color: kAccent)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(label: 'Hours', value: '8.5', icon: Icons.timer_outlined, color: const Color(0xFF34D399))),
              ],
            ),
            const SizedBox(height: 24),

            const _SectionHeader('Performance Overview'),
            const SizedBox(height: 14),
            _PerformanceChart(),
            const SizedBox(height: 24),

            const _SectionHeader('Breakdown by Feature'),
            const SizedBox(height: 14),
            _BreakdownItem(label: 'Running Analysis', percent: 0.87, color: const Color(0xFFFB923C)),
            const SizedBox(height: 10),
            _BreakdownItem(label: 'Posture Analysis', percent: 0.92, color: const Color(0xFF38BDF8)),
            const SizedBox(height: 10),
            _BreakdownItem(label: 'Training Load', percent: 0.74, color: const Color(0xFF34D399)),
            const SizedBox(height: 10),
            _BreakdownItem(label: 'Bowling Analysis', percent: 0.68, color: const Color(0xFFC084FC)),
          ],
        ),
      ),
    );
  }
}

// ── Profile Tab ────────────────────────────────────────────────────────────────
class ProfileTab extends StatelessWidget {
  final String  name;
  final String  email;
  final String? photoUrl;
  final VoidCallback onLogout;

  const ProfileTab({super.key, required this.name, required this.email, required this.photoUrl, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        title: const Text('Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary)),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: kBorder)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile header
            Container(
              color: kSurface,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              child: Row(
                children: [
                  Stack(
                    children: [
                      _AvatarWidget(name: name, photoUrl: photoUrl, radius: 36),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: kAccent, shape: BoxShape.circle,
                            border: Border.all(color: kSurface, width: 2),
                          ),
                          child: const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.4),
                        ),
                        const SizedBox(height: 4),
                        Text(email, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: kAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: kAccent.withValues(alpha: 0.25)),
                          ),
                          child: const Text('Athlete', style: TextStyle(fontSize: 11, color: kAccent, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: kBorder),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: [
                      _ProfileStat(value: '47', label: 'Sessions'),
                      _vDivider(),
                      _ProfileStat(value: '12', label: 'This Month'),
                      _vDivider(),
                      _ProfileStat(value: '89', label: 'Avg Score'),
                    ],
                  ),
                  const SizedBox(height: 28),

                  const _SectionHeader('Account'),
                  const SizedBox(height: 10),
                  _ProfileMenuGroup(items: [
                    _ProfileMenuItem(icon: Icons.person_outline_rounded,       label: 'Personal Info',      trailing: true),
                    _ProfileMenuItem(icon: Icons.notifications_outlined,       label: 'Notifications',      trailing: true),
                    _ProfileMenuItem(icon: Icons.lock_outline_rounded,         label: 'Privacy & Security', trailing: true),
                  ]),
                  const SizedBox(height: 20),

                  const _SectionHeader('Preferences'),
                  const SizedBox(height: 10),
                  _ProfileMenuGroup(items: [
                    _ProfileMenuItem(icon: Icons.dark_mode_outlined,           label: 'Appearance',         trailing: true),
                    _ProfileMenuItem(icon: Icons.language_outlined,            label: 'Language',           trailing: true, value: 'English'),
                    _ProfileMenuItem(icon: Icons.straighten_rounded,           label: 'Units',              trailing: true, value: 'Metric'),
                  ]),
                  const SizedBox(height: 20),

                  const _SectionHeader('Support'),
                  const SizedBox(height: 10),
                  _ProfileMenuGroup(items: [
                    _ProfileMenuItem(icon: Icons.help_outline_rounded,         label: 'Help Center',        trailing: true),
                    _ProfileMenuItem(icon: Icons.feedback_outlined,            label: 'Send Feedback',      trailing: true),
                    _ProfileMenuItem(icon: Icons.info_outline_rounded,         label: 'About SolidCore',    trailing: true),
                  ]),
                  const SizedBox(height: 20),

                  // Sign out
                  GestureDetector(
                    onTap: onLogout,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded, size: 18, color: Colors.red.shade400),
                          const SizedBox(width: 12),
                          Text('Sign Out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red.shade400)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('v1.0.0 · SolidCore Performance', style: TextStyle(fontSize: 11, color: kTextMuted), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 36, color: kBorder, margin: const EdgeInsets.symmetric(horizontal: 8));
}

// ── Reusable Sub-Widgets ───────────────────────────────────────────────────────

class _AvatarWidget extends StatelessWidget {
  final String  name;
  final String? photoUrl;
  final double  radius;
  const _AvatarWidget({required this.name, required this.photoUrl, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: kAccent,
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
      child: photoUrl == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: radius * 0.65),
            )
          : null,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.2),
  );
}

class _RecentSessionCard extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   subtitle;
  final String   time;
  final String   score;

  const _RecentSessionCard({
    required this.icon, required this.color, required this.title,
    required this.subtitle, required this.time, required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: kTextSecondary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8),
                ),
                child: Text(score, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
              ),
              const SizedBox(height: 4),
              Text(time, style: const TextStyle(fontSize: 11, color: kTextMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _CategoryChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _DrillCard extends StatelessWidget {
  final String title, category, level;
  final Color  color;
  const _DrillCard({required this.title, required this.category, required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.play_arrow_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(category, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
                    const Text(' · ', style: TextStyle(fontSize: 11, color: kTextMuted)),
                    Text(level, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kTextMuted),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String   label, value;
  final IconData icon;
  final Color    color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
        ],
      ),
    );
  }
}

class _PerformanceChart extends StatelessWidget {
  final List<double> data = const [0.6, 0.75, 0.65, 0.88, 0.82, 0.91, 0.87];
  final List<String> days = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final isToday = i == 6;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: data[i] * 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              colors: isToday
                                  ? [kAccent, kAccent.withValues(alpha: 0.5)]
                                  : [kBorderBright, kBorder],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(7, (i) => Expanded(
              child: Text(days[i], textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: i == 6 ? kAccent : kTextMuted, fontWeight: i == 6 ? FontWeight.w700 : FontWeight.w400)),
            )),
          ),
        ],
      ),
    );
  }
}

class _BreakdownItem extends StatelessWidget {
  final String label;
  final double percent;
  final Color  color;
  const _BreakdownItem({required this.label, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextPrimary)),
              Text('${(percent * 100).round()}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent, minHeight: 6, backgroundColor: kBorder,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value, label;
  const _ProfileStat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.5)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
      ],
    ),
  );
}

class _ProfileMenuGroup extends StatelessWidget {
  final List<_ProfileMenuItem> items;
  const _ProfileMenuGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Icon(item.icon, size: 18, color: kTextSecondary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(item.label, style: const TextStyle(fontSize: 14, color: kTextPrimary, fontWeight: FontWeight.w500))),
                    if (item.value != null)
                      Text(item.value!, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
                    if (item.trailing) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: kTextMuted),
                    ],
                  ],
                ),
              ),
              if (i < items.length - 1) const Divider(height: 1, color: kBorder, indent: 46),
            ],
          );
        }),
      ),
    );
  }
}

class _ProfileMenuItem {
  final IconData icon;
  final String   label;
  final bool     trailing;
  final String?  value;
  const _ProfileMenuItem({required this.icon, required this.label, this.trailing = false, this.value});
}

// ── Feature Card ───────────────────────────────────────────────────────────────
class _FeatureCard extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final String       subtitle;
  final Color        accentColor;
  final List<Color>  gradientColors;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon, required this.title, required this.subtitle,
    required this.accentColor, required this.gradientColors, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(color: accentColor.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95), fontWeight: FontWeight.w800,
                fontSize: 15, height: 1.2, letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text('Open', style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 3),
                      Icon(Icons.arrow_forward_rounded, size: 11, color: accentColor),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feature Pills (Login Screen) ───────────────────────────────────────────────
class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder),
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