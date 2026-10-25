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

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  // FIX: the version used to be typed here as "1.0.0", so EVERY installed copy of the app (even 3.0.2) thought it was
  // 1.0.0 and showed "Update Required" as soon as latest_app_version on the server was higher than 1.0.0.
  // Now the real installed version is read from the app itself (the "version:" line in pubspec.yaml).
  String _installedVersion = '';

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: const Color(0xFF3A22C4),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF5B34F0), Color(0xFF3A22C4), Color(0xFF2A1580)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
          ),
          // Soft curves and glow lines
          const CustomPaint(painter: _SplashBackdropPainter()),

          // Centre content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: [
                      BoxShadow(color: Colors.white.withOpacity(0.22), blurRadius: 40, spreadRadius: 2),
                      BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 12)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: Image.asset('assets/kainuwa_logo.png', width: 128, height: 128, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Kainuwa', style: TextStyle(fontSize: 44, height: 1.0, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.2)),
                const SizedBox(height: 2),
                const Text('Academy', style: TextStyle(fontSize: 44, height: 1.05, fontWeight: FontWeight.w900, color: Color(0xFFFFC21A), letterSpacing: -1.2)),
                const SizedBox(height: 14),
                const Text('Learn Skills. Build Your Future.', style: TextStyle(fontSize: 15.5, color: Colors.white, fontWeight: FontWeight.w500, letterSpacing: 0.2)),
                const SizedBox(height: 34),
                // Progress bar
                SizedBox(
                  width: 130,
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (context, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: Curves.easeInOut.transform(_progress.value),
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.18),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFFFC21A)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Decorative background: faint circles, a mortarboard, glowing orange lines and a yellow wave.
class _SplashBackdropPainter extends CustomPainter {
  const _SplashBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Big faint circles
    canvas.drawCircle(Offset(w * 0.1, h * 0.05), w * 0.55, Paint()..color = Colors.white.withOpacity(0.04));
    canvas.drawCircle(Offset(w * 0.95, h * 0.62), w * 0.7, Paint()..color = Colors.white.withOpacity(0.035));

    // Faint mortarboard (top right)
    final cap = Path()
      ..moveTo(w * 0.60, h * 0.115)
      ..lineTo(w * 0.86, h * 0.145)
      ..lineTo(w * 1.02, h * 0.19)
      ..lineTo(w * 0.80, h * 0.235)
      ..close();
    canvas.drawPath(cap, Paint()..color = Colors.white.withOpacity(0.07));
    final crown = Path()
      ..moveTo(w * 0.67, h * 0.17)
      ..lineTo(w * 0.67, h * 0.215)
      ..quadraticBezierTo(w * 0.78, h * 0.25, w * 0.89, h * 0.215)
      ..lineTo(w * 0.89, h * 0.19)
      ..close();
    canvas.drawPath(crown, Paint()..color = Colors.white.withOpacity(0.06));
    canvas.drawLine(Offset(w * 0.94, h * 0.19), Offset(w * 0.95, h * 0.28), Paint()..color = Colors.white.withOpacity(0.08)..strokeWidth = 5..strokeCap = StrokeCap.round);

    // Glowing orange line (top left)
    final topLine = Path()
      ..moveTo(0, h * 0.19)
      ..quadraticBezierTo(w * 0.28, h * 0.15, w * 0.45, h * 0.03)
      ..lineTo(w * 0.47, h * 0.05)
      ..quadraticBezierTo(w * 0.30, h * 0.18, 0, h * 0.205)
      ..close();
    canvas.drawPath(topLine, Paint()..shader = const LinearGradient(colors: [Color(0xFFFFC21A), Color(0x00FFC21A)]).createShader(Rect.fromLTWH(0, 0, w * 0.5, h * 0.2))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // Yellow wave (bottom right)
    final wave = Path()
      ..moveTo(w * 0.36, h)
      ..quadraticBezierTo(w * 0.62, h * 0.88, w, h * 0.865)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(wave, Paint()..shader = const LinearGradient(colors: [Color(0xFFFFB020), Color(0xFFFFD84D)], begin: Alignment.bottomLeft, end: Alignment.topRight).createShader(Rect.fromLTWH(0, h * 0.85, w, h * 0.15)));
    // Glow line above the wave
    final glow = Path()
      ..moveTo(w * 0.33, h)
      ..quadraticBezierTo(w * 0.62, h * 0.875, w, h * 0.835);
    canvas.drawPath(glow, Paint()..color = const Color(0xFFFFC21A).withOpacity(0.85)..style = PaintingStyle.stroke..strokeWidth = 3..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
