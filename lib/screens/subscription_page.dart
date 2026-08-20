import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../api_service.dart';
import '../core/theme.dart';
import '../services/entitlements.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? const Color(0xFF14532D) : null,
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
                    _PlanCard(
                      plan: plan,
                      ent: _ent!,
                      busy: _buyingPlan == plan.key,
                      anyBusy: _buyingPlan != null,
                      onBuy: () => _buy(plan),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_useAppleIap() && _ent!.appleEnabled) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        onPressed: () => _iap.restorePurchases(),
                        child: Text('Restore Purchases',
                            style: TextStyle(fontSize: 13, color: kAccent)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
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
          '${days != null ? ' — $days day${days == 1 ? '' : 's'} left' : ''}. '
          'Buy a plan below any time; it starts right away.',
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
      _ => ('NO SUBSCRIPTION', kTextMuted, 'Choose a plan below to get started.'),
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
          if (canBuy) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: isCurrent
                  ? OutlinedButton(
                      onPressed: anyBusy ? null : onBuy,
                      style: OutlinedButton.styleFrom(
                        // The card's SizedBox sets the height; the global 18px
                        // vertical button padding would clip the label inside it.
                        padding: EdgeInsets.zero,
                        side: BorderSide(color: kAccent.withValues(alpha: 0.6)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                      ),
                      child: busy
                          ? SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: kAccent, strokeWidth: 2))
                          : Text(buyLabel,
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kAccent)),
                    )
                  : ElevatedButton(
                      onPressed: anyBusy ? null : onBuy,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero, // height comes from the SizedBox
                        disabledBackgroundColor: kAccent.withValues(alpha: 0.25),
                      ),
                      child: busy
                          ? SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: kOnAccent, strokeWidth: 2))
                          : Text(buyLabel,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
