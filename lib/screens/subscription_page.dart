import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../api_service.dart';
import '../core/theme.dart';
import '../services/entitlements.dart';
import '../widgets/common_widgets.dart' show SectionHeader;
import '../widgets/feature_gate.dart' show formatInr;

/// Apple requires digital subscriptions bought inside an iOS app to go
/// through StoreKit, not a third-party processor (Guideline 3.1.1) — so iOS
/// buys through Apple IAP while Android keeps the existing Razorpay flow.
bool _useAppleIap() => !kIsWeb && Platform.isIOS;

/// Current plan status + the live plan catalogue. Prices, features, and plan
/// names come from the backend, so admin edits show up here without an app
/// update.
///
/// Plans can be purchased in-app through Razorpay in every self-serve state —
/// including mid-trial — the checkout signature is verified server-side and
/// the plan activates the moment verification passes. Buy buttons hide
/// themselves when the server has no payment credentials configured.
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  Entitlements? _ent;
  String? _error;

  late final Razorpay _razorpay;
  String? _buyingPlan;   // plan key mid-checkout (spinner on that card)
  String? _pendingOrder; // Razorpay order id awaiting verification

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _iapSub;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    if (_useAppleIap()) {
      _iapSub = _iap.purchaseStream.listen(_onIapUpdate,
          onError: (_) {}); // errors surface per-purchase in the list itself
    }
    _load();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _iapSub?.cancel();
    super.dispose();
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

  void _snack(String msg, {bool ok = false}) {
    if (!mounted) return;
    // The theme's snackbar is light-on-dark; success adds a check mark rather
    // than a coloured background (which would clash with the dark label).
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: ok
          ? Row(children: [
              const Icon(Icons.check_circle_rounded, size: 18, color: kBg),
              const SizedBox(width: 10),
              Expanded(child: Text(msg)),
            ])
          : Text(msg),
      duration: const Duration(seconds: 4),
    ));
  }

  // ── Purchase ──────────────────────────────────────────────────────────────

  Future<void> _buy(PlanInfo plan) {
    return _useAppleIap() ? _buyApple(plan) : _buyRazorpay(plan);
  }

  Future<void> _buyRazorpay(PlanInfo plan) async {
    setState(() => _buyingPlan = plan.key);
    try {
      final order = await ApiService.createPlanOrder(plan.key);
      final user = await ApiService.getCachedUser();
      _pendingOrder = order['orderId'] as String;
      _razorpay.open({
        'key': order['keyId'],
        'order_id': order['orderId'],
        'amount': order['amountPaise'],
        'currency': 'INR',
        'name': 'SolidCore AMS',
        'description': '${order['planName']} — annual plan',
        if (user != null) 'prefill': {'email': user.email},
        'theme': {'color': '#00CF74'},
        // UPI first, with the intent flow (tap-through to GPay/PhonePe/Paytm)
        // ahead of collect/QR; the default blocks keep cards, netbanking, and
        // wallets available below it.
        'method': {'upi': true},
        'config': {
          'display': {
            'blocks': {
              'upi': {
                'name': 'Pay using UPI',
                'instruments': [
                  {
                    'method': 'upi',
                    'flows': ['intent', 'collect', 'qr'],
                  },
                ],
              },
            },
            'sequence': ['block.upi'],
            'preferences': {'show_default_blocks': true},
          },
        },
      });
      // _buyingPlan stays set while the checkout sheet is up; cleared in the
      // success/error callbacks below.
    } catch (e) {
      if (mounted) setState(() => _buyingPlan = null);
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse r) async {
    try {
      await ApiService.verifyPlanPayment(
        orderId: r.orderId ?? _pendingOrder ?? '',
        paymentId: r.paymentId ?? '',
        signature: r.signature ?? '',
      );
      await _load(); // pull the newly-activated entitlements
      _snack('Payment successful — your plan is active!', ok: true);
    } catch (e) {
      // Paid but not verified (e.g. connection dropped) — the money is with
      // Razorpay and support can activate manually from the payment id.
      _snack('Payment received but verification failed: '
          '${e.toString().replaceFirst('Exception: ', '')} '
          'Contact support with payment ID ${r.paymentId ?? 'unknown'}.');
    } finally {
      _pendingOrder = null;
      if (mounted) setState(() => _buyingPlan = null);
    }
  }

  void _onPaymentError(PaymentFailureResponse r) {
    _pendingOrder = null;
    if (mounted) setState(() => _buyingPlan = null);
    // Code 2 is the user closing the sheet — not an error worth alarming over.
    if (r.code == Razorpay.PAYMENT_CANCELLED) {
      _snack('Payment cancelled.');
    } else {
      _snack(r.message?.isNotEmpty == true
          ? r.message!
          : 'Payment failed. You have not been charged beyond this attempt.');
    }
  }

  void _onExternalWallet(ExternalWalletResponse r) {
    _snack('Continue in ${r.walletName ?? 'your wallet app'} to finish paying.');
  }

  // ── Apple IAP purchase (iOS only) ───────────────────────────────────────

  Future<void> _buyApple(PlanInfo plan) async {
    final productId = plan.appleProductId;
    if (productId == null || productId.isEmpty) {
      _snack('This plan is not available on iOS yet.');
      return;
    }
    setState(() => _buyingPlan = plan.key);
    try {
      if (!await _iap.isAvailable()) {
        throw Exception('In-app purchases are not available on this device.');
      }
      final response = await _iap.queryProductDetails({productId});
      if (response.productDetails.isEmpty) {
        throw Exception('This plan is not available for purchase right now.');
      }
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: response.productDetails.first),
      );
      if (!started) throw Exception('Could not start the purchase.');
      // _buyingPlan stays set until the purchase stream resolves it below.
    } catch (e) {
      if (mounted) setState(() => _buyingPlan = null);
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _onIapUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyApplePurchase(p);
          break;
        case PurchaseStatus.canceled:
          if (mounted) setState(() => _buyingPlan = null);
          _snack('Payment cancelled.');
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
        case PurchaseStatus.error:
          if (mounted) setState(() => _buyingPlan = null);
          _snack(p.error?.message ??
              'Payment failed. You have not been charged beyond this attempt.');
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
      }
    }
  }

  Future<void> _verifyApplePurchase(PurchaseDetails p) async {
    try {
      final matches = _ent?.plans.where((pl) => pl.appleProductId == p.productID) ?? const [];
      final planKey = matches.isEmpty ? '' : matches.first.key;
      await ApiService.verifyApplePayment(
        receipt: p.verificationData.serverVerificationData,
        plan: planKey,
      );
      await _load();
      _snack('Payment successful — your plan is active!', ok: true);
    } catch (e) {
      // Apple purchases have no separate human-readable payment id the way
      // Razorpay does — the transaction is already inside the receipt/App
      // Store purchase history, so point to support without inventing one.
      _snack('Payment received but verification failed: '
          '${e.toString().replaceFirst('Exception: ', '')} '
          'Contact support if this persists.');
    } finally {
      if (mounted) setState(() => _buyingPlan = null);
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('Subscription')),
      body: _ent == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 40, color: kTextMuted),
                          const SizedBox(height: 14),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: kTextSecondary, fontSize: 14, height: 1.45)),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () { hapticSelect(); _load(); },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
            )
          : RefreshIndicator(
              color: kAccent,
              backgroundColor: kCard,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 40),
                children: [
                  _StatusCard(ent: _ent!),
                  const SizedBox(height: 28),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: SectionHeader('Plans'),
                  ),
                  // Bio Lab is held back from general release (see the
                  // ExploreTab preview gate) — don't sell a plan for a
                  // feature set almost nobody can use yet. Athletes already
                  // on this plan keep their entitlements; it just isn't
                  // offered as something new to buy.
                  for (final plan in _ent!.plans.where((p) => p.key != 'solidcore_bio_lab')) ...[
                    _PlanCard(
                      plan: plan,
                      ent: _ent!,
                      busy: _buyingPlan == plan.key,
                      anyBusy: _buyingPlan != null,
                      onBuy: () => _buy(plan),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_useAppleIap() && _ent!.appleEnabled) ...[
                    Center(
                      child: TextButton(
                        onPressed: () { hapticSelect(); _iap.restorePurchases(); },
                        child: const Text('Restore purchases'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      // The active provider on this platform, not the generic
                      // paymentsEnabled flag — otherwise this can claim a
                      // payment method is available while every Buy button on
                      // the page above is actually hidden.
                      !(_useAppleIap() ? _ent!.appleEnabled : _ent!.razorpayEnabled)
                          ? 'To start, change, or renew a plan, contact your '
                            'SolidCore administrator or email '
                            'support@solidcoreats.com. Changing plans never '
                            'deletes your data.'
                          : _useAppleIap()
                              ? 'Payments are processed securely by the App Store. '
                                'Changing plans never deletes your data — locked '
                                'features keep all their history, restored the '
                                'moment you upgrade. For help, email '
                                'support@solidcoreats.com.'
                              : 'Payments are processed securely by Razorpay. Changing '
                                'plans never deletes your data — locked features keep '
                                'all their history, restored the moment you upgrade. '
                                'For help, email support@solidcoreats.com.',
                      style: const TextStyle(fontSize: 13, color: kTextMuted, height: 1.5),
                    ),
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
          'Free trial', kInfo,
          'All features unlocked${ent.trialEndsAt != null ? ' until ${_fmt(ent.trialEndsAt!)}' : ''}'
          '${days != null ? ' — $days day${days == 1 ? '' : 's'} left' : ''}. '
          'Buy a plan below any time; it starts right away.',
        ),
      'active' => (
          ent.planName ?? 'Active', kSuccess,
          '${ent.complimentary ? 'Complimentary access' : 'Active'}'
          '${ent.expiresAt != null ? ' until ${_fmt(ent.expiresAt!)}' : ''}.',
        ),
      'grace' => (
          'Renewal due', kWarn,
          'Your ${ent.planName ?? 'plan'} has expired. Access continues until '
          '${ent.graceEndsAt != null ? _fmt(ent.graceEndsAt!) : 'the grace period ends'} — renew to avoid interruption.',
        ),
      'suspended' => ('Suspended', kDanger, 'Access is paused. Contact support to restore it.'),
      'cancelled' => ('Cancelled', kDanger, 'Your subscription has been cancelled. Your data is retained.'),
      'expired' => ('Expired', kDanger,
          'Your access has ended. Renew to unlock your data again — nothing has been deleted.'),
      _ => ('No subscription', kTextMuted, 'Choose a plan below to get started.'),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kBorder, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                        color: kTextPrimary, letterSpacing: -0.2)),
              ),
              if (ent.complimentary) ...[
                const SizedBox(width: 8),
                const Icon(Icons.card_giftcard_rounded, size: 18, color: kTextSecondary,
                    semanticLabel: 'Complimentary'),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(detail, style: const TextStyle(fontSize: 14, color: kTextSecondary, height: 1.45)),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanInfo plan;
  final Entitlements ent;
  final bool busy;    // this plan's checkout is in flight
  final bool anyBusy; // some checkout is in flight (disables the others)
  final VoidCallback onBuy;
  const _PlanCard({
    required this.plan,
    required this.ent,
    required this.busy,
    required this.anyBusy,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = ent.plan == plan.key && (ent.status == 'active' || ent.status == 'grace');
    final names = ent.featureNames;

    // Purchasable in every self-serve state; suspension is an admin hold.
    // On iOS a plan also needs its Apple product configured before it's buyable.
    final providerEnabled = _useAppleIap()
        ? ent.appleEnabled && plan.appleProductId != null
        : ent.razorpayEnabled;
    final canBuy = providerEnabled && ent.status != 'suspended';
    final buyLabel = isCurrent
        ? 'Renew — ${formatInr(plan.priceInr)} for 1 more year'
        : 'Buy for ${formatInr(plan.priceInr)}/year';

    final VoidCallback? onPressed = anyBusy ? null : () { hapticConfirm(); onBuy(); };
    final Widget buttonChild = busy
        ? const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(color: kTextPrimary, strokeWidth: 2))
        : FittedBox(fit: BoxFit.scaleDown, child: Text(buyLabel, maxLines: 1));

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadius),
        // Current plan: a 1px bright outline plus the "Current plan" label.
        border: Border.all(
          color: isCurrent ? kTextPrimary : kBorder,
          width: isCurrent ? 1 : 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(plan.name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                        color: kTextPrimary, letterSpacing: -0.2)),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorderBright, width: 0.6),
                  ),
                  child: const Text('Current plan',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextPrimary)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: formatInr(plan.priceInr),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700,
                    color: kTextPrimary, letterSpacing: -1, height: 1.1),
              ),
              const TextSpan(
                text: '  / year',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextSecondary),
              ),
            ]),
          ),
          if (plan.features.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 0.6, thickness: 0.6, color: kBorder),
            const SizedBox(height: 14),
          ],
          for (final f in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.check_rounded, size: 18, color: kTextSecondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(names[f] ?? f,
                        style: const TextStyle(fontSize: 15, color: kTextPrimary, height: 1.3)),
                  ),
                ],
              ),
            ),
          if (canBuy) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: isCurrent
                  ? OutlinedButton(onPressed: onPressed, child: buttonChild)
                  : ElevatedButton(onPressed: onPressed, child: buttonChild),
            ),
          ],
        ],
      ),
    );
  }
}
