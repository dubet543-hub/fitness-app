import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';

// ── Feature keys ────────────────────────────────────────────────────────────
// Must match utils/entitlements.js on the backend — the server is the source
// of truth; these constants only exist so gates can't typo a key.

abstract final class FeatureKeys {
  static const workloadMonitoring = 'workload_monitoring';
  static const recovery           = 'recovery';
  static const loadModulation     = 'load_modulation';
  static const bodyComposition    = 'body_composition';
  static const posture            = 'posture';
  static const corrective         = 'corrective';
  static const running            = 'running';
  static const bowling            = 'bowling';
}

/// A plan from the live catalogue (name/price/features are admin-editable
/// server-side, so nothing here is hard-coded).
class PlanInfo {
  final String key;
  final String name;
  final int priceInr;
  final int durationDays;
  final List<String> features;

  const PlanInfo({
    required this.key,
    required this.name,
    required this.priceInr,
    required this.durationDays,
    required this.features,
  });

  factory PlanInfo.fromJson(Map<String, dynamic> j) => PlanInfo(
        key: j['key'] as String,
        name: j['name'] as String,
        priceInr: (j['priceInr'] as num).toInt(),
        durationDays: (j['durationDays'] as num?)?.toInt() ?? 365,
        features: List<String>.from(j['features'] as List? ?? const []),
      );

  Map<String, dynamic> toJson() => {
        'key': key, 'name': name, 'priceInr': priceInr,
        'durationDays': durationDays, 'features': features,
      };
}

/// The athlete's effective access, as computed by the backend.
class Entitlements {
  final String status; // trial | active | grace | expired | suspended | cancelled | none
  final String? plan;
  final String? planName;
  final Set<String> features;
  final DateTime? expiresAt;
  final DateTime? trialEndsAt;
  final DateTime? graceEndsAt;
  final bool complimentary;
  final List<PlanInfo> plans;
  final Map<String, String> featureNames;

  /// Whether the server can take card payments (Razorpay configured). Buy
  /// buttons stay hidden when false.
  final bool paymentsEnabled;

  const Entitlements({
    required this.status,
    required this.plan,
    required this.planName,
    required this.features,
    required this.expiresAt,
    required this.trialEndsAt,
    required this.graceEndsAt,
    required this.complimentary,
    required this.plans,
    required this.featureNames,
    this.paymentsEnabled = false,
  });

  bool has(String feature) => features.contains(feature);

  /// Days until the current access window closes (trial end, expiry, or grace
  /// end, whichever applies). Null when there is no dated window.
  int? get daysRemaining {
    final until = switch (status) {
      'trial'  => trialEndsAt,
      'active' => expiresAt,
      'grace'  => graceEndsAt,
      _        => null,
    };
    if (until == null) return null;
    final d = until.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  factory Entitlements.fromApi(Map<String, dynamic> body) {
    final e = body['entitlements'] as Map<String, dynamic>? ?? const {};
    DateTime? d(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
    return Entitlements(
      status: (e['status'] ?? 'none').toString(),
      plan: e['plan'] as String?,
      planName: e['planName'] as String?,
      features: Set<String>.from(e['features'] as List? ?? const []),
      expiresAt: d(e['expiresAt']),
      trialEndsAt: d(e['trialEndsAt']),
      graceEndsAt: d(e['graceEndsAt']),
      complimentary: e['complimentary'] == true,
      plans: ((body['plans'] as List?) ?? const [])
          .map((p) => PlanInfo.fromJson(p as Map<String, dynamic>))
          .toList(),
      featureNames: Map<String, String>.from(body['featureNames'] as Map? ?? const {}),
      paymentsEnabled: (body['payments'] as Map?)?['enabled'] == true,
    );
  }
}

/// Fetches, caches, and answers "can this athlete use feature X".
///
/// The backend enforces every gate regardless (requireFeature middleware), so
/// this cache is purely how the UI decides what to show — a stale cache can
/// never unlock data the server refuses to serve.
class EntitlementsService {
  EntitlementsService._();

  static const _prefsKey = 'sc_entitlements';

  static Entitlements? _cache;
  static Future<Entitlements>? _inflight;

  /// Test seam: when set, gates read this instead of the network/cache so
  /// widget tests can pump gated screens without a backend.
  @visibleForTesting
  static Entitlements? debugOverride;

  /// Convenience for tests: entitlements with every feature unlocked.
  @visibleForTesting
  static Entitlements allFeaturesForTesting() => Entitlements(
        status: 'trial', plan: null, planName: null,
        features: const {
          FeatureKeys.workloadMonitoring, FeatureKeys.recovery,
          FeatureKeys.loadModulation, FeatureKeys.bodyComposition,
          FeatureKeys.posture, FeatureKeys.corrective,
          FeatureKeys.running, FeatureKeys.bowling,
        },
        expiresAt: null, trialEndsAt: null, graceEndsAt: null,
        complimentary: false, plans: const [], featureNames: const {},
      );

  /// Latest known entitlements (null before the first [load] of the session).
  static Entitlements? get current => debugOverride ?? _cache;

  /// Loads from the API, falling back to the persisted copy when offline so
  /// a flaky connection doesn't lock a paying athlete out of the UI.
  static Future<Entitlements> load({bool refresh = false}) {
    if (debugOverride != null) return Future.value(debugOverride);
    if (!refresh && _cache != null) return Future.value(_cache);
    return _inflight ??= _fetch().whenComplete(() => _inflight = null);
  }

  static Future<Entitlements> _fetch() async {
    try {
      final body = await ApiService.fetchSubscription();
      _cache = Entitlements.fromApi(body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(body));
      return _cache!;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        _cache = Entitlements.fromApi(jsonDecode(raw) as Map<String, dynamic>);
        return _cache!;
      }
      rethrow;
    }
  }

  /// Cached synchronous check — false while nothing is loaded yet.
  static bool has(String feature) => current?.has(feature) ?? false;

  /// Drop everything (sign-out / account switch).
  static Future<void> invalidate() async {
    _cache = null;
    _inflight = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
