import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Change this to your backend host when deploying.
// For local dev with Android emulator use http://10.0.2.2:3000
// For iOS simulator use http://localhost:3000
// API base URL. It can be provided at build time with `--dart-define=API_BASE_URL=...`
// or at runtime by placing `assets/config.json` with { "API_BASE_URL": "http://host:port/api" }.
String _baseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000/api');

/// Everything loaded from `.env` / `assets/config.json`, so settings that are
/// not the API host — the OAuth client IDs used by Google and Apple sign-in —
/// can be read the same way. See [AppConfig].
final Map<String, String> _config = {};

class _ConfigLoader {
  static Future<void> load() async {
    // Prefer runtime .env (flutter_dotenv) when available.
    try {
      // Empty values are dropped so a blank .env entry still falls through to
      // config.json rather than shadowing it.
      dotenv.env.forEach((k, v) { if (v.isNotEmpty) _config[k] = v; });
    } catch (_) {}

    // Fallback to assets/config.json for anything .env did not provide.
    try {
      final raw = await rootBundle.loadString('assets/config.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in map.entries) {
        final v = e.value?.toString();
        if (v != null && v.isNotEmpty) _config.putIfAbsent(e.key, () => v);
      }
    } catch (_) {
      // ignore: no-op — use defaults if asset missing or invalid
    }

    final url = _config['API_BASE_URL'];
    if (url != null && url.isNotEmpty) _baseUrl = url;
  }
}

class ApiUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? sport;
  final String? photoUrl;

  const ApiUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.sport,
    this.photoUrl,
  });

  factory ApiUser.fromJson(Map<String, dynamic> j) => ApiUser(
        id:       j['id']       as String,
        name:     j['name']     as String,
        email:    j['email']    as String,
        role:     j['role']     as String,
        sport:    j['sport']    as String?,
        photoUrl: j['photoUrl'] as String?,
      );
}

/// Read-only view of the runtime configuration loaded at startup, for settings
/// that are not API calls — the OAuth client IDs behind Google/Apple sign-in.
class AppConfig {
  AppConfig._();

  /// The configured value for [key], or null when it was never provided. A null
  /// OAuth client ID is what hides the corresponding sign-in button.
  static String? get(String key) {
    final v = _config[key];
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Google OAuth **web** client ID. Doubles as the `serverClientId` that makes
  /// Android return an ID token, and as the audience the backend checks.
  static String? get googleServerClientId => get('GOOGLE_SERVER_CLIENT_ID');

  /// Google OAuth iOS client ID — required on iOS, which has no
  /// GoogleService-Info.plist in this project.
  static String? get googleIosClientId => get('GOOGLE_IOS_CLIENT_ID');

  /// Apple Services ID, used only for the web-based flow on Android.
  static String? get appleServiceId => get('APPLE_SERVICE_ID');

  /// Where Apple posts back to during the Android web flow. Must match the
  /// Return URL registered against the Services ID.
  static String? get appleRedirectUri => get('APPLE_REDIRECT_URI');
}

class ApiService {
  /// Call at app startup to load runtime config from `assets/config.json`.
  static Future<void> loadConfig() => _ConfigLoader.load();
  static const _tokenKey = 'sc_token';
  static const _userKey  = 'sc_user';
  static const _requestTimeout = Duration(seconds: 15);
  // Bulk history fetches (e.g. "All time" export) can legitimately take
  // longer than the standard timeout, especially on a cold-started backend.
  static const _bulkRequestTimeout = Duration(seconds: 60);
  // Sign-in is usually the first request of the session, so it is the one that
  // pays for waking a backend that has spun down after being idle — on a free
  // Render instance that alone can take ~50s. Failing at 15s would reject a
  // perfectly good sign-in as "could not reach the server".
  static const _authTimeout = Duration(seconds: 75);

  /// Bounds every network call so a dead/unreachable backend fails fast with
  /// a clear message instead of hanging on the OS-level TCP timeout (which
  /// can be 60s+ and otherwise stalls the splash/login screen).
  static Future<http.Response> _send(Future<http.Response> request, {Duration? timeout}) {
    return request.timeout(
      timeout ?? _requestTimeout,
      onTimeout: () => throw Exception(
          'Could not reach the server. Check your connection and try again.'),
    );
  }

  // ── Subscription ───────────────────────────────────────────────────────

  /// GET /api/subscription/me — the athlete's effective entitlements plus the
  /// live plan catalogue (names, prices, features) for the subscription page.
  static Future<Map<String, dynamic>> fetchSubscription() async {
    final res = await _send(http.get(
      Uri.parse('$_baseUrl/subscription/me'),
      headers: await _authHeaders(),
    ));
    if (res.statusCode != 200) {
      throw Exception(_body(res)['error'] ?? 'Could not load subscription');
    }
    return _body(res);
  }

  // ── Token storage ──────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveUser(ApiUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode({
      'id': user.id, 'name': user.name, 'email': user.email,
      'role': user.role, 'sport': user.sport, 'photoUrl': user.photoUrl,
    }));
  }

  static Future<ApiUser?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return ApiUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  // ── Shared request helpers ─────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Decodes a JSON response body. A backend that is down, misrouted, or behind
  /// a proxy replies with an HTML error page instead of JSON — surface that as
  /// something readable rather than a raw "Unexpected character" parse failure.
  static Map<String, dynamic> _body(http.Response r) {
    try {
      final decoded = jsonDecode(r.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // fall through to the message below
    }
    // A 200 whose body is HTML is the backend's SPA catch-all answering for an
    // API route it doesn't have — i.e. the server predates this endpoint.
    final looksLikeHtml = r.body.trimLeft().startsWith('<');
    throw Exception(switch (r.statusCode) {
      404 => 'This feature is not available on the server yet (404). '
          'The backend may need updating.',
      200 when looksLikeHtml =>
        'This feature is not available on the server yet. The backend may need updating.',
      502 || 503 || 504 => 'The server is unavailable right now. Please try again.',
      _ => 'Unexpected response from the server (${r.statusCode}).',
    });
  }

  // ── Auth ───────────────────────────────────────────────────────────────

  /// Exchanges a Google ID token for an app session. The backend verifies the
  /// token's signature against Google's published keys, so nothing here is
  /// trusted client-side; an account is created on first sign-in.
  static Future<({ApiUser user, String token})> authenticateWithGoogle({
    required String idToken,
  }) => _federatedSignIn('google', {'idToken': idToken});

  /// Exchanges an Apple identity token for an app session. [name] is only ever
  /// available on the user's very first authorisation — Apple never sends it
  /// again — so it is passed through to be stored at account creation.
  static Future<({ApiUser user, String token})> authenticateWithApple({
    required String identityToken,
    String? name,
  }) => _federatedSignIn('apple', {
        'identityToken': identityToken,
        if (name != null && name.isNotEmpty) 'name': name,
      });

  static Future<({ApiUser user, String token})> _federatedSignIn(
      String provider, Map<String, dynamic> body) async {
    final res = await _send(http.post(
      Uri.parse('$_baseUrl/auth/$provider'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ), timeout: _authTimeout);
    if (res.statusCode != 200) {
      throw Exception(_body(res)['error'] ?? 'Sign-in failed');
    }
    final data  = _body(res);
    final user  = ApiUser.fromJson(data['user'] as Map<String, dynamic>);
    final token = data['token'] as String;
    await saveToken(token);
    await saveUser(user);
    return (user: user, token: token);
  }

  /// Public self-signup — creates an athlete account and signs in.
  static Future<({ApiUser user, String token})> register({
    required String name,
    required String email,
    required String password,
    String? sport,
  }) async {
    final res = await _send(http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        if (sport != null && sport.isNotEmpty) 'sport': sport,
      }),
    ), timeout: _authTimeout);
    if (res.statusCode != 201)
      throw Exception(_body(res)['error'] ?? 'Sign up failed');
    final data = _body(res);
    final user  = ApiUser.fromJson(data['user'] as Map<String, dynamic>);
    final token = data['token'] as String;
    await saveToken(token);
    await saveUser(user);
    return (user: user, token: token);
  }

  /// Email/password login.
  static Future<({ApiUser user, String token})> login({
    required String email,
    required String password,
  }) async {
    final res = await _send(http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ), timeout: _authTimeout);
    if (!res.statusCode.toString().startsWith('2'))
      throw Exception(_body(res)['error'] ?? 'Login failed');
    final data = _body(res);
    final user  = ApiUser.fromJson(data['user'] as Map<String, dynamic>);
    final token = data['token'] as String;
    await saveToken(token);
    await saveUser(user);
    return (user: user, token: token);
  }

  // ── Sessions ───────────────────────────────────────────────────────────

  /// POST /api/sessions — log a new training session.
  static Future<Map<String, dynamic>> submitSession(
      Map<String, dynamic> payload) async {
    final res = await _send(http.post(
      Uri.parse('$_baseUrl/sessions'),
      headers: await _authHeaders(),
      body: jsonEncode(payload),
    ));
    if (res.statusCode != 201)
      throw Exception(_body(res)['error'] ?? 'Failed to save session');
    return _body(res);
  }

  /// GET /api/sessions — fetch own sessions with optional date range.
  static Future<List<Map<String, dynamic>>> fetchSessions({
    DateTime? from,
    DateTime? to,
    String? date, // single day, yyyy-MM-dd
    int limit = 100,
    int skip = 0,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'skip': '$skip',
      if (date != null) 'date': date,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null)   'to':   to.toIso8601String(),
    };
    final uri = Uri.parse('$_baseUrl/sessions').replace(queryParameters: params);
    final res = await _send(http.get(uri, headers: await _authHeaders()), timeout: _bulkRequestTimeout);
    if (res.statusCode != 200)
      throw Exception(_body(res)['error'] ?? 'Failed to fetch sessions');
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  // ── Body composition ────────────────────────────────────────────────────

  /// POST /api/body-composition — sync a computed estimate so coaches/admins
  /// can review it. Best-effort: returns null on failure (e.g. offline / not
  /// logged into the backend) so the on-device result is never blocked.
  static Future<Map<String, dynamic>?> submitBodyComposition(
      Map<String, dynamic> payload) async {
    try {
      final token = await getToken();
      if (token == null) return null; // not signed in to backend — skip sync
      final res = await _send(http.post(
        Uri.parse('$_baseUrl/body-composition'),
        headers: await _authHeaders(),
        body: jsonEncode(payload),
      ));
      if (res.statusCode != 201) return null;
      return _body(res);
    } catch (_) {
      return null;
    }
  }

  /// GET /api/body-composition — own body-composition history (newest first).
  static Future<List<Map<String, dynamic>>> fetchBodyComposition() async {
    final res = await _send(http.get(
      Uri.parse('$_baseUrl/body-composition'),
      headers: await _authHeaders(),
    ), timeout: _bulkRequestTimeout);
    if (res.statusCode != 200) return [];
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  // ── Account management ──────────────────────────────────────────────────

  /// PATCH /api/auth/me — update own profile; refreshes the cached user.
  static Future<ApiUser> updateProfile({String? name, String? sport}) async {
    final res = await _send(http.patch(
      Uri.parse('$_baseUrl/auth/me'),
      headers: await _authHeaders(),
      body: jsonEncode({
        if (name != null)  'name': name,
        if (sport != null) 'sport': sport,
      }),
    ));
    if (res.statusCode != 200)
      throw Exception(_body(res)['error'] ?? 'Failed to update profile');
    final user = ApiUser.fromJson(_body(res));
    await saveUser(user);
    return user;
  }

  /// POST /api/auth/change-password
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await _send(http.post(
      Uri.parse('$_baseUrl/auth/change-password'),
      headers: await _authHeaders(),
      body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword}),
    ));
    if (res.statusCode != 200)
      throw Exception(_body(res)['error'] ?? 'Failed to change password');
  }

  /// DELETE /api/auth/me/data — erase recorded training data, keep the account
  /// and session intact.
  static Future<void> deleteMyData() async {
    final res = await _send(http.delete(
      Uri.parse('$_baseUrl/auth/me/data'),
      headers: await _authHeaders(),
    ));
    if (res.statusCode != 200)
      throw Exception(_body(res)['error'] ?? 'Failed to delete your data');
  }

  /// DELETE /api/auth/me — permanently delete the account, then clear the session.
  static Future<void> deleteAccount() async {
    final res = await _send(http.delete(
      Uri.parse('$_baseUrl/auth/me'),
      headers: await _authHeaders(),
    ));
    if (res.statusCode != 200)
      throw Exception(_body(res)['error'] ?? 'Failed to delete account');
    await clearSession();
  }

  /// GET /api/auth/me — verify token is still valid; returns null on 401/error.
  static Future<ApiUser?> verifyToken() async {
    try {
      final res = await _send(http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: await _authHeaders(),
      ), timeout: _authTimeout);
      if (res.statusCode == 200) {
        return ApiUser.fromJson(_body(res));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// DELETE /api/sessions/:id
  static Future<void> deleteSession(String id) async {
    final res = await _send(http.delete(
      Uri.parse('$_baseUrl/sessions/$id'),
      headers: await _authHeaders(),
    ));
    if (res.statusCode != 200)
      throw Exception(_body(res)['error'] ?? 'Failed to delete');
  }
}
