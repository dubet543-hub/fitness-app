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

// ── Nav bar ───────────────────────────────────────────────────────────────────
// Minimal tab bar: every tab always shows icon + label, the active tab is
// bright, and the centre Log button is a plain filled circle. Haptic on change.

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
    void select(int i) {
      if (i != currentIndex) hapticSelect();
      onTap(i);
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: kBg,
        border: Border(top: BorderSide(color: kBorder, width: 0.6)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _MagicTab(active: currentIndex == 0, icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', onTap: () => select(0)),
              _MagicTab(active: currentIndex == 1, icon: Icons.center_focus_weak_rounded, activeIcon: Icons.center_focus_strong_rounded, label: 'Motion', onTap: () => select(1)),
              _LogButton(onTap: () { hapticConfirm(); onLog(); }),
              _MagicTab(active: currentIndex == 2, icon: Icons.insert_chart_outlined_rounded, activeIcon: Icons.insert_chart_rounded, label: 'Dashboard', onTap: () => select(2)),
              _MagicTab(active: currentIndex == 3, icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile', onTap: () => select(3)),
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

  @override
  Widget build(BuildContext context) {
    final color = active ? kTextPrimary : kTextMuted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: '$label tab',
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          highlightShape: BoxShape.circle,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Icon(active ? activeIcon : icon, key: ValueKey(active), size: 24, color: color),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: color, letterSpacing: 0),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Log Menu Sheet ────────────────────────────────────────────────────────────
// Tapping the centre Log (+) button opens this picker so the user can choose
// which kind of entry to log.

class _LogMenuSheet extends StatelessWidget {
  final void Function(String feature, Widget Function() builder) onSelect;
  const _LogMenuSheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kBorder, width: 0.6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: kBorderBright, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('New log', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.3)),
              ),
            ),
            _LogMenuItem(
              icon: Icons.fitness_center_rounded,
              title: 'Training load',
              subtitle: 'Sessions, RPE and skill workload',
              onTap: () => onSelect(FeatureKeys.loadModulation, () => const TrainingLoadScreen()),
            ),
            const _ItemDivider(),
            _LogMenuItem(
              icon: Icons.favorite_border_rounded,
              title: 'Wellness',
              subtitle: 'Sleep, soreness, fatigue and mood',
              onTap: () => onSelect(FeatureKeys.recovery, () => const WellnessLogScreen()),
            ),
            const _ItemDivider(),
            _LogMenuItem(
              icon: Icons.monitor_weight_outlined,
              title: 'Body composition',
              subtitle: 'Weight and body measurements',
              onTap: () => onSelect(FeatureKeys.bodyComposition, () => const BodyCompositionScreen()),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _ItemDivider extends StatelessWidget {
  const _ItemDivider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(left: 64),
    child: Divider(height: 0.6, color: kBorder),
  );
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () { hapticSelect(); onTap(); },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              SizedBox(width: 36, child: Icon(icon, size: 24, color: kTextPrimary)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kTextPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: kTextMuted),
            ],
          ),
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
      child: Semantics(
        button: true,
        label: 'New log',
        excludeSemantics: true,
        child: Center(
          child: Material(
            color: kAccent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: const SizedBox(
                width: 46,
                height: 46,
                child: Icon(Icons.add_rounded, size: 26, color: kOnAccent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
