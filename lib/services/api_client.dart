import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../screens/login_screen.dart';

/// One navigator key for the whole app. It lets the app send the user back to the login screen from
/// anywhere (for example when the server says the login has expired).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Adds the login token to EVERY request that goes to academy.kainuwa.africa.
/// It is installed once in main.dart with http.runWithClient, so all the existing
/// http.get / http.post calls in the app get the token automatically.
class KaidaHttpClient extends http.BaseClient {
  final http.Client _inner = IOClient();
  static bool _handlingExpiredLogin = false;

  // Read-only endpoints whose last good answer is saved on the phone, so the app still opens offline.
  static const Set<String> _cacheableFiles = {
    'dashboard_data.php', 'my_courses.php', 'my_downloads.php', 'catalog.php', 'categories.php',
    'get_wishlist.php', 'get_profile_details.php', 'user_profile.php', 'course_lessons.php',
    'course_details.php', 'product_details.php', 'get_instructor.php', 'help_center_data.php',
  };

  /// A key for answers worth saving, or null when the request must never be cached (anything that changes data).
  String? _cacheKey(http.BaseRequest request, String userId) {
    if (request is! http.Request) return null;
    final path = request.url.path;
    final file = path.split('/').last;
    final body = request.body;
    bool ok = _cacheableFiles.contains(file);
    if (!ok && file == 'notifications_api.php') ok = request.bodyFields['action'] == 'get';
    if (!ok && file == 'ai_chat.php') {
      final act = request.url.queryParameters['action'];
      ok = request.method == 'GET' && (act == 'get_sessions' || act == 'get_history');
    }
    if (!ok) return null;
    // The user id is part of the key, so one person's saved answers are never shown to another.
    return 'kcache|$userId|${request.method}|${request.url}|$body';
  }

  /// Forget every saved answer (used when the user logs out).
  static Future<void> clearSavedAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith('kcache|')).toList()) {
      await prefs.remove(k);
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bool isOurServer = request.url.host == 'academy.kainuwa.africa';

    if (isOurServer) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      // Only real server tokens are sent. Very old saved tokens (random text) are not.
      if (token != null && token.startsWith('kd1_')) {
        request.headers['X-Kaida-Token'] = token;
        request.headers['Authorization'] = 'Bearer $token';
      }
    }

    // Saved-answer path: used for read-only data on our server
    if (isOurServer) {
      final prefs = await SharedPreferences.getInstance();
      final uid = (prefs.getInt('user_id') ?? 0).toString();
      final key = uid == '0' ? null : _cacheKey(request, uid);
      if (key != null) {
        try {
          final live = await _inner.send(request).timeout(const Duration(seconds: 10));
          if (live.statusCode == 401) { _sendToLogin(); return live; }
          final bytes = await live.stream.toBytes();
          if (live.statusCode == 200) {
            final text = utf8.decode(bytes, allowMalformed: true);
            if (text.contains('"status":"success"') || text.contains('"status": "success"')) {
              await prefs.setString(key, text);
            }
          } else if (live.statusCode >= 500) {
            final saved = prefs.getString(key);
            if (saved != null) return _fromSaved(saved, request);
          }
          return http.StreamedResponse(http.ByteStream.fromBytes(bytes), live.statusCode,
              contentLength: bytes.length, request: request, headers: live.headers, reasonPhrase: live.reasonPhrase);
        } on SocketException catch (_) {
          final saved = prefs.getString(key);
          if (saved != null) return _fromSaved(saved, request);
          rethrow;
        } on TimeoutException catch (_) {
          final saved = prefs.getString(key);
          if (saved != null) return _fromSaved(saved, request);
          rethrow;
        } on http.ClientException catch (_) {
          final saved = prefs.getString(key);
          if (saved != null) return _fromSaved(saved, request);
          rethrow;
        }
      }
    }

    final response = await _inner.send(request);

    // 401 from our server = the login is no longer valid (expired, logged out elsewhere, banned...)
    if (isOurServer && response.statusCode == 401) {
      _sendToLogin();
    }
    return response;
  }

  http.StreamedResponse _fromSaved(String text, http.BaseRequest request) {
    final bytes = utf8.encode(text);
    return http.StreamedResponse(http.ByteStream.fromBytes(bytes), 200,
        contentLength: bytes.length, request: request,
        headers: {'content-type': 'application/json; charset=utf-8', 'x-kaida-from-saved': '1'});
  }

  static Future<void> _sendToLogin() async {
    if (_handlingExpiredLogin) return;
    _handlingExpiredLogin = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await clearSavedAnswers();
      final nav = appNavigatorKey.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } finally {
      // allow it to run again after a few seconds
      Future.delayed(const Duration(seconds: 5), () => _handlingExpiredLogin = false);
    }
  }
}

class ApiClient {
  /// Returns a link that opens a page of the website inside the app's WebView, already signed in.
  /// New app login  -> a one-time link from the server (works once, 60 seconds).
  /// Old saved login -> the old link (works only until the server leaves "legacy mode").
  /// Returns null when a link could not be created.
  static Future<String?> webviewUrl(String redirectPath) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    if (token.startsWith('kd1_')) {
      try {
        final response = await http
            .post(Uri.parse(ApiConfig.webviewTicket), body: {'redirect': redirectPath})
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'success' && data['url'] != null) {
            return data['url'].toString();
          }
        }
      } catch (_) {}
      return null;
    }

    final userId = prefs.getInt('user_id');
    if (userId == null) return null;
    return '${ApiConfig.baseUrl}/webview_auth.php?user_id=$userId&redirect=${Uri.encodeComponent(redirectPath)}';
  }

  /// Tells the server to stop accepting this device's token.
  static Future<void> logoutOnServer() async {
    try {
      await http.post(Uri.parse(ApiConfig.logout)).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Offline is fine: the app clears its own copy anyway
    }
    await KaidaHttpClient.clearSavedAnswers();
  }
}