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
          'FREE TRIAL', kSky,
          days == null
              ? 'Your free trial is active'
              : '$days day${days == 1 ? '' : 's'} left',
          'You have full access to every feature. Pick a plan below to keep '
          'training without interruption when the trial ends.',
        ),
      'grace' => (
          'RENEWAL DUE', kWarn,
          'Your plan has expired',
          'Access continues for a short grace period. Renew now to avoid '
          'losing access — all your data stays safe.',
        ),
      _ => (
          'TRIAL ENDED', kDanger,
          'Subscribe to continue',
          'Your free month is over and features are locked. Everything you '
          'logged is safely retained — choose a plan to pick up where you '
          'left off.',
        ),
    };

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: kBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: chipColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(chip,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                            letterSpacing: 1.2, color: chipColor)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: kTextPrimary, letterSpacing: -0.3)),
              const SizedBox(height: 8),
              Text(body,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: kTextSecondary, height: 1.5)),
              const SizedBox(height: 16),

              // Bio Lab is held back from general release (see the
              // ExploreTab preview gate and subscription_page.dart) — don't
              // nudge trial users toward a plan for a feature set they can't
              // actually use yet.
              for (final plan in ent.plans.where((p) => p.key != 'solidcore_bio_lab').take(2)) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(plan.name,
                            style: TextStyle(fontSize: 13.5,
                                fontWeight: FontWeight.w700, color: kTextPrimary)),
                      ),
                      Text('${formatInr(plan.priceInr)}/yr',
                          style: TextStyle(fontSize: 13.5,
                              fontWeight: FontWeight.w800, color: kAccent)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 6),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SubscriptionPage()));
                  },
                  style: ElevatedButton.styleFrom(
                    // Height comes from the SizedBox; the theme's 18px vertical
                    // padding would clip the label inside 48px.
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('View plans'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Maybe later',
                    style: TextStyle(color: kTextSecondary, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
