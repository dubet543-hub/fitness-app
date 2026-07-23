import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/entitlements.dart';
import '../widgets/feature_gate.dart' show formatInr;

/// Current plan status + the live plan catalogue. Prices, features, and plan
/// names come from the backend, so admin edits show up here without an app
/// update. Plans are activated by the SolidCore team — there is no in-app
/// payment flow.
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  Entitlements? _ent;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ent = await EntitlementsService.load(refresh: true);
      if (mounted) setState(() { _ent = ent; _error = null; });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        iconTheme: IconThemeData(color: kTextPrimary),
        title: Text('SUBSCRIPTION',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: kTextSecondary, letterSpacing: 1.4)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: _ent == null
          ? Center(
              child: _error == null
                  ? CircularProgressIndicator(color: kAccent, strokeWidth: 2)
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: kTextSecondary, fontSize: 13)),
                          const SizedBox(height: 14),
                          TextButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    ),
            )
          : RefreshIndicator(
              color: kAccent,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  _StatusCard(ent: _ent!),
                  const SizedBox(height: 24),
                  Text('PLANS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 1.4, color: kTextSecondary)),
                  const SizedBox(height: 10),
                  for (final plan in _ent!.plans) ...[
                    _PlanCard(plan: plan, ent: _ent!),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'To start, change, or renew a plan, contact your SolidCore '
                    'administrator or email support@solidcoreats.com. Changing '
                    'plans never deletes your data — locked features keep all '
                    'their history and records, restored the moment you upgrade.',
                    style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.55),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final Entitlements ent;
  const _StatusCard({required this.ent});

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final days = ent.daysRemaining;
    final (label, color, detail) = switch (ent.status) {
      'trial' => (
          'FREE TRIAL', kSky,
          'All features unlocked${ent.trialEndsAt != null ? ' until ${_fmt(ent.trialEndsAt!)}' : ''}'
          '${days != null ? ' — $days day${days == 1 ? '' : 's'} left' : ''}.',
        ),
      'active' => (
          ent.planName?.toUpperCase() ?? 'ACTIVE', kAccent,
          '${ent.complimentary ? 'Complimentary access' : 'Active'}'
          '${ent.expiresAt != null ? ' until ${_fmt(ent.expiresAt!)}' : ''}.',
        ),
      'grace' => (
          'RENEWAL DUE', kWarn,
          'Your ${ent.planName ?? 'plan'} has expired. Access continues until '
          '${ent.graceEndsAt != null ? _fmt(ent.graceEndsAt!) : 'the grace period ends'} — renew to avoid interruption.',
        ),
      'suspended' => ('SUSPENDED', kDanger, 'Access is paused. Contact support to restore it.'),
      'cancelled' => ('CANCELLED', kDanger, 'Your subscription has been cancelled. Your data is retained.'),
      'expired' => ('EXPIRED', kDanger,
          'Your access has ended. Renew to unlock your data again — nothing has been deleted.'),
      _ => ('NO SUBSCRIPTION', kTextMuted, 'Contact SolidCore to activate a plan.'),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        letterSpacing: 1.1, color: color)),
              ),
              if (ent.complimentary) ...[
                const SizedBox(width: 8),
                Icon(Icons.card_giftcard_rounded, size: 16, color: kViolet),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(detail, style: TextStyle(fontSize: 13, color: kTextSecondary, height: 1.5)),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanInfo plan;
  final Entitlements ent;
  const _PlanCard({required this.plan, required this.ent});

  @override
  Widget build(BuildContext context) {
    final isCurrent = ent.plan == plan.key && (ent.status == 'active' || ent.status == 'grace');
    final names = ent.featureNames;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent ? kAccent : kBorder,
          width: isCurrent ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(plan.name,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text('CURRENT',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                          letterSpacing: 1, color: kAccent)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatInr(plan.priceInr),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kAccent)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('/ year', style: TextStyle(fontSize: 12, color: kTextSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final f in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 15, color: kAccent.withValues(alpha: 0.8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(names[f] ?? f,
                        style: TextStyle(fontSize: 13, color: kTextPrimary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
