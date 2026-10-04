import 'dart:convert';
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

    final response = await _inner.send(request);

    // 401 from our server = the login is no longer valid (expired, logged out elsewhere, banned...)
    if (isOurServer && response.statusCode == 401) {
      _sendToLogin();
    }
    return response;
  }

  static Future<void> _sendToLogin() async {
    if (_handlingExpiredLogin) return;
    _handlingExpiredLogin = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
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
  }
}