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
      final response = await http.get(Uri.parse(ApiConfig.appSettings)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          String latestVersion = data['data']['latest_app_version'] ?? '1.0.0';
          bool forceUpdate = data['data']['force_update'] == '1';
          String updateUrl = data['data']['share_url'] ?? "https://play.google.com/store/apps/details?id=com.kainuwa.academy";

          if (_installedVersion.isNotEmpty && _isUpdateRequired(_installedVersion, latestVersion)) {
            _showUpdateDialog(forceUpdate, updateUrl);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("Splash settings fetch error: $e");
    }
    
    await Future.delayed(const Duration(milliseconds: 1500));
    _routeUser();
  }

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
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF5B34F0), Color(0xFF3A22C4), Color(0xFF2A1580)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
          ),
          const CustomPaint(painter: _SplashBackdropPainter()),

          // Logo, name, tagline and the loading bar
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/kainuwa_academy_whitelogo.png',
                    width: MediaQuery.of(context).size.width * 0.38,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/logo.png',
                      width: MediaQuery.of(context).size.width * 0.3,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text('Kainuwa', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -0.5)),
                  const Text('Academy', style: TextStyle(color: Color(0xFFFFC21A), fontSize: 40, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -0.5)),
                  const SizedBox(height: 14),
                  Text('Learn Skills. Build Your Future.', style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 15.5, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.36,
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (context, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: Curves.easeInOut.transform(_progress.value),
                          minHeight: 6,
                          backgroundColor: Colors.white.withOpacity(0.22),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFC21A)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The soft circles and the yellow glow arcs behind the logo
class _SplashBackdropPainter extends CustomPainter {
  const _SplashBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // faint purple circles
    canvas.drawCircle(Offset(w * 0.2, -h * 0.04), w * 0.85, Paint()..color = const Color(0xFF8B6BFF).withOpacity(0.16));
    canvas.drawCircle(Offset(w * 1.12, h * 0.5), w * 0.6, Paint()..color = const Color(0xFF8B6BFF).withOpacity(0.14));

    // yellow glow arc, top left
    final glow = Paint()
      ..color = const Color(0xFFFFC21A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final line = Paint()
      ..color = const Color(0xFFFFE27A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final topRect = Rect.fromCircle(center: Offset(-w * 0.1, -h * 0.17), radius: w * 0.62);
    canvas.drawArc(topRect, 0.05, 1.0, false, glow);
    canvas.drawArc(topRect, 0.05, 1.0, false, line);

    // big yellow circle, bottom right
    final bottomCenter = Offset(w * 1.02, h * 1.1);
    final bottomRadius = w * 0.66;
    canvas.drawCircle(
      bottomCenter,
      bottomRadius,
      Paint()..shader = const LinearGradient(colors: [Color(0xFFFFE066), Color(0xFFFFB800)], begin: Alignment.topLeft, end: Alignment.bottomRight)
          .createShader(Rect.fromCircle(center: bottomCenter, radius: bottomRadius)),
    );
    final bottomRect = Rect.fromCircle(center: bottomCenter, radius: bottomRadius + 6);
    canvas.drawArc(bottomRect, 3.7, 0.9, false, glow);
    canvas.drawArc(bottomRect, 3.7, 0.9, false, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
