import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../screens/subscription_page.dart';
import '../services/entitlements.dart';
import 'feature_gate.dart' show formatInr;

/// Popup shown once per app launch, right after the shell appears, until the
/// athlete owns a plan: trial countdown (or locked/renewal notice) plus the
/// two plans, with a path to the subscription page. Athletes on an active
/// plan — or under an admin suspension — never see it.
class TrialPlanDialog {
  TrialPlanDialog._();

  static bool _shownThisLaunch = false;

  /// Called when the shell is torn down (sign-out), so the next sign-in gets
  /// the dialog again.
  static void resetForNextSignIn() => _shownThisLaunch = false;

  static Future<void> maybeShow(BuildContext context) async {
    if (_shownThisLaunch) return;
    Entitlements ent;
    try {
      ent = await EntitlementsService.load();
    } catch (_) {
      return; // offline with no cache — don't block the app with a popup
    }
    if (ent.status == 'active' || ent.status == 'suspended') return;
    if (!context.mounted) return;
    _shownThisLaunch = true;

    final days = ent.daysRemaining;
    final (chip, chipColor, headline, body) = switch (ent.status) {
      'trial' => (
          'Free trial', kInfo,
          days == null
              ? 'Your free trial is active'
              : '$days day${days == 1 ? '' : 's'} left',
          'You have full access to every feature. Pick a plan below to keep '
          'training without interruption when the trial ends.',
        ),
      'grace' => (
          'Renewal due', kWarn,
          'Your plan has expired',
          'Access continues for a short grace period. Renew now to avoid '
          'losing access — all your data stays safe.',
        ),
      _ => (
          'Trial ended', kDanger,
          'Subscribe to continue',
          'Your free month is over and features are locked. Everything you '
          'logged is safely retained — choose a plan to pick up where you '
          'left off.',
        ),
    };

    // Bio Lab is held back from general release (see the
    // ExploreTab preview gate and subscription_page.dart) — don't
    // nudge trial users toward a plan for a feature set they can't
    // actually use yet.
    final plans = ent.plans.where((p) => p.key != 'solidcore_bio_lab').take(2).toList();

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status: a dot in the status colour + the word.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: chipColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(chip,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
                ],
              ),
              const SizedBox(height: 10),
              Semantics(
                header: true,
                child: Text(headline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                        color: kTextPrimary, letterSpacing: -0.4, height: 1.2)),
              ),
              const SizedBox(height: 8),
              Text(body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: kTextSecondary, height: 1.45)),
              const SizedBox(height: 20),

              if (plans.isNotEmpty) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(kRadiusSm),
                    border: Border.all(color: kBorder, width: 0.6),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < plans.length; i++) ...[
                        if (i > 0) const Divider(height: 0.6, thickness: 0.6, indent: 14, color: kBorder),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Expanded(
                                child: Text(plans[i].name,
                                    style: const TextStyle(fontSize: 15,
                                        fontWeight: FontWeight.w500, color: kTextPrimary)),
                              ),
                              Text.rich(TextSpan(children: [
                                TextSpan(
                                  text: formatInr(plans[i].priceInr),
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                                      color: kTextPrimary, letterSpacing: -0.4),
                                ),
                                const TextSpan(
                                  text: '/yr',
                                  style: TextStyle(fontSize: 13, color: kTextSecondary),
                                ),
                              ])),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              ElevatedButton(
                onPressed: () {
                  hapticConfirm();
                  Navigator.pop(ctx);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SubscriptionPage()));
                },
                child: const Text('View plans'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Maybe later',
                    style: TextStyle(color: kTextSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
