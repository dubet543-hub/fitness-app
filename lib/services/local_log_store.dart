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

  static const Duration bcaInterval = Duration(days: 14);

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

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
}
