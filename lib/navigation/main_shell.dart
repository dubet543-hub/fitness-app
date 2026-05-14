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

  static const _items = [
    _NavItem(icon: Icons.home_outlined,          activeIcon: Icons.home_rounded,       label: 'Home'),
    _NavItem(icon: Icons.explore_outlined,        activeIcon: Icons.explore_rounded,    label: 'Explore'),
    _NavItem(icon: Icons.show_chart_rounded,      activeIcon: Icons.show_chart_rounded, label: 'Analytics'),
    _NavItem(icon: Icons.person_outline_rounded,  activeIcon: Icons.person_rounded,     label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kBorder, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (i) {
              final active = i == currentIndex;
              final col    = active ? kAccent : kTextMuted;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          active ? _items[i].activeIcon : _items[i].icon,
                          size: 22,
                          color: col,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _items[i].label.toUpperCase(),
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
