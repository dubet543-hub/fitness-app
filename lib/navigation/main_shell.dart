import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../screens/home_tab.dart';
import '../screens/explore_tab.dart';
import '../screens/player_dashboard_screen.dart';
import '../screens/profile_tab.dart';
import '../screens/wellness_log_screen.dart';
import '../screens/body_composition_screen.dart';
import '../training_load_screen.dart';
import '../services/entitlements.dart';
import '../widgets/feature_gate.dart';
import '../widgets/trial_plan_dialog.dart';

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
  void initState() {
    super.initState();
    // Trial/plan popup on app open, until the athlete owns a plan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TrialPlanDialog.maybeShow(context);
    });
  }

  @override
  void dispose() {
    TrialPlanDialog.resetForNextSignIn(); // sign-out → next sign-in sees it again
    super.dispose();
  }

  void _openLog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _LogMenuSheet(
        onSelect: (feature, builder) {
          Navigator.pop(sheetContext);
          // Locked features show the upgrade sheet instead of the log screen.
          FeatureGate.push(context, feature, builder);
        },
      ),
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
        // Tapping the app-bar avatar selects the Profile tab rather than
        // pushing a second copy of it over the shell.
        onOpenProfile: () => setState(() => _currentIndex = 3),
      ),
      // NOT const. The palette in theme.dart is mutable globals read at build
      // time, so a screen only picks up a light/dark switch if it actually
      // rebuilds. Flutter's updateChild skips the subtree when the new widget
      // is identical to the old one, which is exactly what a const constructor
      // guarantees — so `const` here leaves these two tabs stuck on the old
      // palette while the parameterised tabs repaint correctly.
      ExploreTab(),               // ignore: prefer_const_constructors
      PlayerDashboardScreen(),    // ignore: prefer_const_constructors
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
      decoration: BoxDecoration(
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
                icon: Icons.center_focus_weak_rounded,
                activeIcon: Icons.center_focus_strong_rounded,
                label: 'Motion',
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
                  color: active ? kOnAccent : kTextMuted,
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
                    style: TextStyle(
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

// ── Log Menu Sheet ────────────────────────────────────────────────────────────
// Tapping the centre LOG (+) button opens this picker so the user can choose
// which kind of entry to log.

class _LogMenuSheet extends StatelessWidget {
  final void Function(String feature, Widget Function() builder) onSelect;
  const _LogMenuSheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: kTextMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(8, 12, 8, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'NEW LOG',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kTextSecondary,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
            _LogMenuItem(
              icon: Icons.fitness_center_rounded,
              title: 'Training Load Log',
              subtitle: 'Sessions, RPE & skill workload',
              onTap: () => onSelect(FeatureKeys.loadModulation, () => const TrainingLoadScreen()),
            ),
            _LogMenuItem(
              icon: Icons.favorite_rounded,
              title: 'Wellness Log',
              subtitle: 'Sleep, soreness, fatigue & mood',
              onTap: () => onSelect(FeatureKeys.recovery, () => const WellnessLogScreen()),
            ),
            _LogMenuItem(
              icon: Icons.monitor_weight_rounded,
              title: 'Body Composition',
              subtitle: 'Weight, skinfolds & measurements',
              onTap: () => onSelect(FeatureKeys.bodyComposition, () => const BodyCompositionScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogMenuItem extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  const _LogMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: kAccent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: kTextSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: kTextMuted),
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
              child: Icon(Icons.add_rounded, size: 24, color: kOnAccent),
            ),
            const SizedBox(height: 4),
            Text(
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
