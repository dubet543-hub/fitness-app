import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../screens/home_tab.dart';
import '../screens/explore_tab.dart';
import '../screens/analytics_tab.dart';
import '../screens/profile_tab.dart';

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

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(icon: Icons.grid_view_rounded,     activeIcon: Icons.grid_view_rounded,   label: 'Home'),
      _NavItem(icon: Icons.explore_outlined,       activeIcon: Icons.explore_rounded,     label: 'Explore'),
      _NavItem(icon: Icons.analytics_outlined,     activeIcon: Icons.analytics_rounded,   label: 'Analytics'),
      _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,      label: 'Profile'),
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
  final String   label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}
