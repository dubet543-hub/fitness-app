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
      bottomNavigationBar: _MagicNavBar(
        currentIndex: _currentIndex,
        onTap:  (i) => setState(() => _currentIndex = i),
        onLog:  _openLog,
      ),
    );
  }
}

// ── Magic Nav Bar ─────────────────────────────────────────────────────────────
// Active icon lifts into a floating accent circle with a glowing dot beneath it
// and a label that slides in — inspired by the "magic navigation" CSS effect.

class _MagicNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onLog;

  const _MagicNavBar({
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
          height: 76,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MagicTab(
                active: currentIndex == 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                onTap: () => onTap(0),
              ),
              _MagicTab(
                active: currentIndex == 1,
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore_rounded,
                label: 'Explore',
                onTap: () => onTap(1),
              ),
              _LogButton(onTap: onLog),
              _MagicTab(
                active: currentIndex == 2,
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
                label: 'Dashboard',
                onTap: () => onTap(2),
              ),
              _MagicTab(
                active: currentIndex == 3,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MagicTab extends StatelessWidget {
  final bool active;
  final IconData icon, activeIcon;
  final String label;
  final VoidCallback onTap;

  const _MagicTab({
    required this.active,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  static const _dur   = Duration(milliseconds: 420);
  static const _curve = Curves.easeOutBack;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Lifting accent circle holding the icon.
            AnimatedAlign(
              duration: _dur,
              curve: _curve,
              alignment: active ? const Alignment(0, -0.55) : Alignment.center,
              child: AnimatedContainer(
                duration: _dur,
                curve: Curves.easeOut,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? kAccent : Colors.transparent,
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: kAccent.withValues(alpha: 0.45),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  active ? activeIcon : icon,
                  size: 22,
                  color: active ? Colors.black : kTextMuted,
                ),
              ),
            ),

            // Label fades/slides in below the lifted icon.
            Positioned(
              bottom: 14,
              child: AnimatedSlide(
                duration: _dur,
                curve: Curves.easeOut,
                offset: active ? Offset.zero : const Offset(0, 0.6),
                child: AnimatedOpacity(
                  duration: _dur,
                  opacity: active ? 1 : 0,
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: kAccent,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),

            // Glowing dot indicator at the bottom.
            Positioned(
              bottom: 6,
              child: AnimatedContainer(
                duration: _dur,
                curve: Curves.easeOut,
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? kAccent : kTextMuted.withValues(alpha: 0.4),
                  boxShadow: active
                      ? [
                          BoxShadow(color: kAccent, blurRadius: 6, spreadRadius: 1),
                          BoxShadow(color: kAccent.withValues(alpha: 0.6), blurRadius: 14, spreadRadius: 2),
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
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
    );
  }
}
