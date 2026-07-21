import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local, on-device persistence for log-gating rules that the backend does not
/// enforce:
///  • Recovery (wellness/sleep) log — once per calendar day (re-enables at the
///    next 00:00 midnight).
///  • Body composition analysis — once every 2 weeks, with a stored history of
///    measurements so each metric can be charted against its real date.
class LocalLogStore {
  LocalLogStore._();

  static const _kRecoveryDate   = 'recovery_last_logged_date'; // yyyy-MM-dd
  static const _kBcaHistory     = 'bca_history_json';          // List<Map>
  static const _kSavedEmail     = 'saved_login_email';
  static const _kSavedPassword  = 'saved_login_password';
  static const _kRememberLogin  = 'remember_login';
  static const _kConsentDailyLogs = 'consent_daily_logs';      // bool
  static const _kConsentCamera    = 'consent_camera_features'; // bool
  static const _kConsentBca       = 'consent_body_composition';// bool

  static const Duration bcaInterval = Duration(days: 14);

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ── Privacy consent gates ──────────────────────────────────────────────────
  // User-controlled consent for data-collecting features. Both default to true
  // so existing users are unaffected; toggled from Privacy & Security settings.
  // When a consent is off, the related feature refuses to run.

  /// Whether the user consents to saving daily wellness/recovery logs.
  static Future<bool> dailyLogsConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kConsentDailyLogs) ?? true;
  }

  static Future<void> setDailyLogsConsent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kConsentDailyLogs, value);
  }

  /// Whether the user consents to camera-based analysis (posture, running,
  /// bowling — all processed on-device).
  static Future<bool> cameraConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kConsentCamera) ?? true;
  }

  static Future<void> setCameraConsent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kConsentCamera, value);
  }

  /// Whether the user has acknowledged the body-composition estimate
  /// disclaimer. Defaults to false so the disclaimer is shown once before the
  /// first analysis, then remembered.
  static Future<bool> bcaConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kConsentBca) ?? false;
  }

  static Future<void> setBcaConsent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kConsentBca, value);
  }

  // ── Recovery log gate ──────────────────────────────────────────────────────

  /// True when a recovery log has already been saved today (local time).
  static Future<bool> recoveryLoggedToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRecoveryDate) == _dayKey(DateTime.now());
  }

  /// Records that the recovery log was saved now. It stays gated until the next
  /// midnight, when [recoveryLoggedToday] naturally returns false again.
  static Future<void> markRecoveryLogged() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRecoveryDate, _dayKey(DateTime.now()));
  }

  // ── Body composition history & gate ────────────────────────────────────────

  /// All stored body-composition measurements, oldest first. Each entry:
  /// { date: ISO8601, isMale, weight, height, neck, abdomen, hip }
  static Future<List<Map<String, dynamic>>> bcaHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBcaHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      list.sort((a, b) => DateTime.parse(a['date'] as String)
          .compareTo(DateTime.parse(b['date'] as String)));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> addBcaEntry(Map<String, dynamic> entry) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await bcaHistory();
    history.add(entry);
    await prefs.setString(_kBcaHistory, jsonEncode(history));
  }

  /// Wipes the locally-cached body-composition history and sync bookkeeping.
  /// Paired with a server-side data deletion so nothing lingers on-device.
  static Future<void> clearBcaHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBcaHistory);
    await prefs.remove(_kBcaSyncedDates);
  }

  // ── Backend sync tracking ──────────────────────────────────────────────────
  // Records the ISO dates of BCA entries already pushed to the server so the
  // backfill sync never uploads the same reading twice.

  static const _kBcaSyncedDates = 'bca_synced_dates';

  static Future<Set<String>> bcaSyncedDates() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kBcaSyncedDates) ?? const []).toSet();
  }

  static Future<void> markBcaSynced(String isoDate) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_kBcaSyncedDates) ?? <String>[]).toSet();
    set.add(isoDate);
    await prefs.setStringList(_kBcaSyncedDates, set.toList());
  }

  /// The most recent analysis date, or null if none recorded.
  static Future<DateTime?> lastBcaDate() async {
    final history = await bcaHistory();
    if (history.isEmpty) return null;
    return DateTime.parse(history.last['date'] as String);
  }

  /// Earliest moment a new analysis is allowed (last + 2 weeks), or null when
  /// no analysis exists yet.
  static Future<DateTime?> bcaNextAvailable() async {
    final last = await lastBcaDate();
    return last?.add(bcaInterval);
  }

  /// True when a new measurement-based analysis is currently locked.
  static Future<bool> bcaLocked() async {
    final next = await bcaNextAvailable();
    if (next == null) return false;
    return DateTime.now().isBefore(next);
  }

  // ── Saved login credentials ("Remember me") ─────────────────────────────────
  // NOTE: stored in plaintext via SharedPreferences. Fine for a convenience
  // "remember me" on a personal device; swap to flutter_secure_storage if the
  // password needs to be encrypted at rest.

  /// Whether the user opted to keep their login saved.
  static Future<bool> rememberLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kRememberLogin) ?? false;
  }

  /// The saved credentials, or null when "remember me" is off / nothing stored.
  static Future<({String email, String password})?> savedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_kRememberLogin) ?? false)) return null;
    final email = prefs.getString(_kSavedEmail);
    final pass  = prefs.getString(_kSavedPassword);
    if (email == null || pass == null) return null;
    return (email: email, password: pass);
  }

  /// Persist credentials so the login form can auto-fill next launch.
  static Future<void> saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRememberLogin, true);
    await prefs.setString(_kSavedEmail, email);
    await prefs.setString(_kSavedPassword, password);
  }

  /// Forget any saved credentials (when "remember me" is unchecked).
  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRememberLogin, false);
    await prefs.remove(_kSavedEmail);
    await prefs.remove(_kSavedPassword);
  }
}
