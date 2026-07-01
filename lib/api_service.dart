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

class _ConfigLoader {
  static Future<void> load() async {
    // Prefer runtime .env (flutter_dotenv) when available.
    try {
      final envUrl = dotenv.env['API_BASE_URL'];
      if (envUrl != null && envUrl.isNotEmpty) {
        _baseUrl = envUrl;
        return;
      }
    } catch (_) {}

    // Fallback to assets/config.json if present.
    try {
      final raw = await rootBundle.loadString('assets/config.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final url = map['API_BASE_URL'] as String?;
      if (url != null && url.isNotEmpty) {
        _baseUrl = url;
      }
    } catch (_) {
      // ignore: no-op — use defaults if asset missing or invalid
    }
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

class ApiService {
  /// Call at app startup to load runtime config from `assets/config.json`.
  static Future<void> loadConfig() => _ConfigLoader.load();
  static const _tokenKey = 'sc_token';
  static const _userKey  = 'sc_user';

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

  static Map<String, dynamic> _body(http.Response r) {
    final decoded = jsonDecode(r.body);
    return decoded as Map<String, dynamic>;
  }

  // ── Auth ───────────────────────────────────────────────────────────────

  /// Called after Firebase Google Sign-In. Sends the verified Google email
  /// to the backend to get an app JWT (returns null if not pre-registered).
  static Future<({ApiUser user, String token})?> authenticateWithGoogle({
    required String email,
    String? name,
    String? photoUrl,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'name': name, 'photoUrl': photoUrl}),
    );
    if (res.statusCode == 403) return null; // not registered
    if (res.statusCode != 200) throw Exception(_body(res)['error'] ?? 'Auth failed');
    final data = _body(res);
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
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        if (sport != null && sport.isNotEmpty) 'sport': sport,
      }),
    );
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
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
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
    final res = await http.post(
      Uri.parse('$_baseUrl/sessions'),
      headers: await _authHeaders(),
      body: jsonEncode(payload),
    );
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
    final res = await http.get(uri, headers: await _authHeaders());
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
      final res = await http.post(
        Uri.parse('$_baseUrl/body-composition'),
        headers: await _authHeaders(),
        body: jsonEncode(payload),
      );
      if (res.statusCode != 201) return null;
      return _body(res);
    } catch (_) {
      return null;
    }
  }

  /// GET /api/body-composition — own body-composition history (newest first).
  static Future<List<Map<String, dynamic>>> fetchBodyComposition() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/body-composition'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) return [];
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  // ── Account management ──────────────────────────────────────────────────

  /// PATCH /api/auth/me — update own profile; refreshes the cached user.
  static Future<ApiUser> updateProfile({String? name, String? sport}) async {
    final res = await http.patch(
      Uri.parse('$_baseUrl/auth/me'),
      headers: await _authHeaders(),
      body: jsonEncode({
        if (name != null)  'name': name,
        if (sport != null) 'sport': sport,
      }),
    );
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
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/change-password'),
      headers: await _authHeaders(),
      body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword}),
    );
    if (res.statusCode != 200)
      throw Exception(_body(res)['error'] ?? 'Failed to change password');
  }

  /// DELETE /api/auth/me — permanently delete the account, then clear the session.
  static Future<void> deleteAccount() async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/auth/me'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200)
      throw Exception(_body(res)['error'] ?? 'Failed to delete account');
    await clearSession();
  }

  /// GET /api/auth/me — verify token is still valid; returns null on 401/error.
  static Future<ApiUser?> verifyToken() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: await _authHeaders(),
      );
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
    final res = await http.delete(
      Uri.parse('$_baseUrl/sessions/$id'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200)
      throw Exception(_body(res)['error'] ?? 'Failed to delete');
  }
}
