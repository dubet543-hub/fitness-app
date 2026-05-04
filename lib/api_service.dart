import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Change this to your backend host when deploying.
// For local dev with Android emulator use http://10.0.2.2:3000
// For iOS simulator use http://localhost:3000
const String _baseUrl = 'http://172.16.17.241:3000/api';

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

  /// Web-style email/password login (for admin web page; not used in Flutter).
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
