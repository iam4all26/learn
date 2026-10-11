import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import 'login_screen.dart';
import 'main_layout.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // FIX: the version used to be typed here as "1.0.0", so EVERY installed copy of the app (even 3.0.2) thought it was
  // 1.0.0 and showed "Update Required" as soon as latest_app_version on the server was higher than 1.0.0.
  // Now the real installed version is read from the app itself (the "version:" line in pubspec.yaml).
  String _installedVersion = '';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _installedVersion = info.version;   // e.g. "3.0.3" (the part before the + in pubspec.yaml)
    } catch (e) {
      debugPrint("Could not read the app version: $e");
    }

    try {
      final response = await http.get(Uri.parse(ApiConfig.appSettings)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          String latestVersion = data['data']['latest_app_version'] ?? '1.0.0';
          bool forceUpdate = data['data']['force_update'] == '1';
          String updateUrl = data['data']['share_url'] ?? "https://play.google.com/store/apps/details?id=com.kainuwa.academy";

          // If the installed version could not be read, never block the user with an update message
          if (_installedVersion.isNotEmpty && _isUpdateRequired(_installedVersion, latestVersion)) {
            _showUpdateDialog(forceUpdate, updateUrl);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("Splash settings fetch error: $e");
    }
    
    // Add a slight artificial delay so the minimalist text stays on screen just long enough to be read
    await Future.delayed(const Duration(milliseconds: 1500));
    _routeUser();
  }

  // True only when the server's latest version is HIGHER than the installed one.
  // Works with "3.0.3", "3.1" and "4" (missing parts count as 0).
  bool _isUpdateRequired(String current, String latest) {
    try {
      List<int> parse(String v) {
        final parts = v.trim().split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
        while (parts.length < 3) {
          parts.add(0);
        }
        return parts;
      }

      final currParts = parse(current);
      final latestParts = parse(latest);
      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currParts[i]) return true;
        if (latestParts[i] < currParts[i]) return false;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  void _showUpdateDialog(bool forceUpdate, String url) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !forceUpdate,
        child: AlertDialog(
          title: const Text('Update Required'),
          content: const Text('A new version of Kainuwa Academy is available. Please update to continue learning.'),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _routeUser();
                },
                child: const Text('Later'),
              ),
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _routeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userId = prefs.getInt('user_id');

    if (!mounted) return;

    if (token != null && userId != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const MainLayout()));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Text(
          'Kainuwa Academy', 
          style: TextStyle(
            fontSize: 32, 
            fontWeight: FontWeight.w900, 
            color: Colors.white, 
            letterSpacing: -0.5
          )
        ),
      ),
    );
  }
}