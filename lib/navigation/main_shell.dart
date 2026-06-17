import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../screens/home_tab.dart';
import '../screens/explore_tab.dart';
import '../screens/player_dashboard_screen.dart';
import '../screens/profile_tab.dart';
import '../screens/wellness_log_screen.dart';

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

  void _openLog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WellnessLogScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeTab(
        name:     widget.name,
        email:    widget.email,
        photoUrl: widget.photoUrl,
        onLogout: widget.onLogout,
      ),
      const ExploreTab(),
      const PlayerDashboardScreen(),
      ProfileTab(
        name:     widget.name,
        email:    widget.email,
        photoUrl: widget.photoUrl,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      backgroundColor: kBg,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        onTap:  (i) => setState(() => _currentIndex = i),
        onLog:  _openLog,
      ),
    );
  }
}

// ── Bottom Nav Bar ────────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onLog;

  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kBorder, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _tab(0, Icons.home_outlined,         Icons.home_rounded,         'Home'),
              _tab(1, Icons.explore_outlined,       Icons.explore_rounded,      'Explore'),
              // Centre Log button
              Expanded(
                child: GestureDetector(
                  onTap: onLog,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: kAccent,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: kAccent.withValues(alpha: 0.40),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded, size: 24, color: Colors.black),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'LOG',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: kAccent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _tab(2, Icons.dashboard_outlined,     Icons.dashboard_rounded,    'Dashboard'),
              _tab(3, Icons.person_outline_rounded,  Icons.person_rounded,       'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(int idx, IconData icon, IconData activeIcon, String label) {
    final active = currentIndex == idx;
    final col    = active ? kAccent : kTextMuted;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(idx),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(active ? activeIcon : icon, size: 22, color: col),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: col,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
