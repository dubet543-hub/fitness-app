import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../screens/subscription_page.dart';
import '../services/entitlements.dart';

// ── Feature gating UI ───────────────────────────────────────────────────────
//
// The backend already refuses locked API calls (requireFeature middleware);
// this layer keeps the app honest about it: gated entry points check the
// cached entitlements before navigating, and every gated screen is wrapped in
// a FeatureGuard so no navigation path — deep link, dashboard shortcut, or
// anything missed — can render a locked feature.

class FeatureGate {
  FeatureGate._();

  /// Navigate to a gated screen, or show the lock sheet if the athlete's plan
  /// doesn't include [feature].
  static Future<void> push(
    BuildContext context,
    String feature,
    Widget Function() builder,
  ) async {
    try {
      await EntitlementsService.load();
    } catch (_) {
      // Offline with no cached entitlements — fall through; has() returns
      // false and the sheet explains. The server would refuse anyway.
    }
    if (!context.mounted) return;
    if (EntitlementsService.has(feature)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => builder()));
    } else {
      showFeatureLockSheet(context, feature);
    }
  }
}

/// Human name for a feature key (server-provided vocabulary, with fallback).
String featureDisplayName(String feature) {
  final names = EntitlementsService.current?.featureNames ?? const {};
  return names[feature] ??
      feature.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

/// Bottom sheet shown when a locked feature is tapped.
void showFeatureLockSheet(BuildContext context, String feature) {
  final ent = EntitlementsService.current;
  // Cheapest active plan that would unlock this feature.
  PlanInfo? unlockPlan;
  for (final p in ent?.plans ?? const <PlanInfo>[]) {
    if (p.features.contains(feature) &&
        (unlockPlan == null || p.priceInr < unlockPlan.priceInr)) {
      unlockPlan = p;
    }
  }

  final message = switch (ent?.status) {
    'suspended' => 'Your subscription is suspended. Contact support to restore access.',
    'expired' || 'cancelled' =>
      'Your subscription has ended. All your data is safely retained — renew to pick up right where you left off.',
    'trial' || 'active' || 'grace' =>
      'This feature isn\'t included in your current plan.',
    _ => 'An active subscription is needed to use this feature.',
  };

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.lock_rounded, size: 34, color: kWarn),
          const SizedBox(height: 14),
          Text(
            '${featureDisplayName(feature)} is locked',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kTextPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: kTextSecondary, height: 1.5),
          ),
          if (unlockPlan != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kAccent.withValues(alpha: 0.35)),
              ),
              child: Text(
                'Included in ${unlockPlan.name} — ${formatInr(unlockPlan.priceInr)}/year',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kAccent),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SubscriptionPage()));
              },
              child: const Text('View plans'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Not now', style: TextStyle(color: kTextSecondary, fontSize: 13)),
          ),
        ],
      ),
    ),
  );
}

/// Wraps a gated screen (or embedded panel). Renders the child only when the
/// plan includes [feature]; otherwise shows a locked panel with a path to the
/// plans page. Defence in depth behind the tap-time gates.
class FeatureGuard extends StatelessWidget {
  final String feature;
  final Widget child;
  const FeatureGuard({super.key, required this.feature, required this.child});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Entitlements>(
      // Cached after first call — no per-screen network cost.
      future: EntitlementsService.load().catchError(
          (_) => EntitlementsService.current ??
              const Entitlements(
                status: 'none', plan: null, planName: null, features: {},
                expiresAt: null, trialEndsAt: null, graceEndsAt: null,
                complimentary: false, plans: [], featureNames: {},
              )),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            backgroundColor: kBg,
            body: Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2)),
          );
        }
        if (snap.data!.has(feature)) return child;
        return _LockedScreen(feature: feature);
      },
    );
  }
}

class _LockedScreen extends StatelessWidget {
  final String feature;
  const _LockedScreen({required this.feature});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: kBg,
      appBar: canPop
          ? AppBar(
              backgroundColor: kBg,
              elevation: 0,
              iconTheme: IconThemeData(color: kTextPrimary),
            )
          : null,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 44, color: kWarn),
              const SizedBox(height: 16),
              Text(
                '${featureDisplayName(feature)} is locked',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kTextPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Upgrade your plan to unlock this feature. Your existing data is '
                'safely retained and will be right here when you do.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kTextSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SubscriptionPage())),
                child: const Text('View plans'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ₹ with Indian digit grouping (₹20,000 / ₹1,00,000).
String formatInr(int amount) {
  final s = amount.toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '₹${parts.join(',')},$last3';
}
