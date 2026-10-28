import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import 'home_screen.dart';
import 'dashboard_screen.dart';
import 'wishlist_screen.dart';
import 'catalog_screen.dart';
import 'profile_screen.dart';
import 'ai_chat_screen.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex; 
  const MainLayout({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex; 
  }

  // Restored YOUR exact screen list, just removing Shop and Downloads
  int _wishlistRefresh = 0; // rebuilds the wishlist tab each time it is opened

  List<Widget> get _screens => [
    const HomeScreen(), // 0
    const CatalogScreen(actionType: 'courses', title: 'Explore Courses'), // 1
    const AiChatScreen(), // 2
    WishlistScreen(key: ValueKey('wishlist_$_wishlistRefresh')), // 3
    const ProfileScreen(), // 4
    const DashboardScreen(), // 5 (Learn dashboard, opened from notifications)
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBgColor = isDark ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final barColor = isDark ? AppTheme.darkSurfaceColor : Colors.white;
    final activeColor = AppTheme.primaryColor;
    final inactiveColor = isDark ? Colors.grey.shade500 : Colors.grey.shade500;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const barHeight = 66.0;
    final reserved = barHeight + 12 + bottomInset; // space the screens keep clear of the bar
    final aiSelected = _currentIndex == 2;

    return WillPopScope(
      // Back on another tab goes to Home first; on Home, press back twice to close the app
      onWillPop: () async {
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return false;
        }
        // On Home: press back twice (within 2 seconds) to close the app
        final now = DateTime.now();
        if (_lastBackPress != null && now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return false;
        }
        _lastBackPress = now;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Press back again to exit', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(60, 0, 60, reserved + 6),
            backgroundColor: const Color(0xFF2A1580),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        );
        return false;
      },
      child: Scaffold(
      backgroundColor: scaffoldBgColor,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            bottom: reserved - 8,
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),

          // Floating rounded bar
          Positioned(
            left: 12, right: 12, bottom: 10 + bottomInset,
            child: Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildNavItem(icon: Icons.home_rounded, label: 'Home', index: 0, activeColor: activeColor, inactiveColor: inactiveColor),
                  _buildNavItem(icon: Icons.menu_book_rounded, label: 'Courses', index: 1, activeColor: activeColor, inactiveColor: inactiveColor),
                  const Expanded(child: SizedBox()), // gap for the raised AI button
                  _buildNavItem(icon: Icons.favorite_rounded, label: 'Wishlist', index: 3, activeColor: activeColor, inactiveColor: inactiveColor),
                  _buildNavItem(icon: Icons.person_rounded, label: 'Profile', index: 4, activeColor: activeColor, inactiveColor: inactiveColor),
                ],
              ),
            ),
          ),

          // Raised, glowing AI button in the centre
          Positioned(
            bottom: 10 + bottomInset + 14,
            left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => setState(() => _currentIndex = 2),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B6CFF), Color(0xFF5B34F0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: barColor, width: 4),
                        boxShadow: [
                          BoxShadow(color: AppTheme.primaryColor.withOpacity(aiSelected ? 0.6 : 0.4), blurRadius: aiSelected ? 22 : 16, spreadRadius: aiSelected ? 2 : 0, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: const Center(child: CustomPaint(size: Size(36, 32), painter: _AiRobotPainter())),
                    ),
                    const SizedBox(height: 3),
                    Text('Kainuwa AI', style: TextStyle(color: aiSelected ? activeColor : inactiveColor, fontSize: 10, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index, required Color activeColor, required Color inactiveColor}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? activeColor : inactiveColor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          if (index == 3) _wishlistRefresh++;
          _currentIndex = index;
        }),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// The Kainuwa AI robot icon (white robot head with sparkles), drawn as vector.
class _AiRobotPainter extends CustomPainter {
  const _AiRobotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Designed on a 275 x 245 grid, scaled to the given size
    final sx = size.width / 275, sy = size.height / 245;
    Offset o(double x, double y) => Offset(x * sx, y * sy);
    Rect r(double l, double t, double rr, double b) => Rect.fromLTRB(l * sx, t * sy, rr * sx, b * sy);
    final white = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final purple = Paint()..color = const Color(0xFF5B34F0)..style = PaintingStyle.fill;

    // Antenna
    canvas.drawCircle(o(138, 22), 12 * sx, white);
    canvas.drawRRect(RRect.fromRectAndRadius(r(132, 28, 144, 85), Radius.circular(6 * sx)), white);
    // Head
    canvas.drawRRect(RRect.fromRectAndRadius(r(48, 80, 232, 165), Radius.circular(40 * sx)), white);
    canvas.drawRRect(RRect.fromRectAndRadius(r(68, 96, 212, 149), Radius.circular(26 * sx)), purple);
    // Eyes
    canvas.drawCircle(o(113, 122), 10 * sx, white);
    canvas.drawCircle(o(167, 122), 10 * sx, white);
    // Chin
    canvas.drawRRect(RRect.fromRectAndRadius(r(108, 213, 172, 233), Radius.circular(10 * sx)), white);
    // Sparkles
    _sparkle(canvas, o(32, 72), 16 * sx, white);
    _sparkle(canvas, o(18, 123), 19 * sx, white);
    _sparkle(canvas, o(257, 121), 17 * sx, white);
  }

  void _sparkle(Canvas canvas, Offset c, double rad, Paint paint) {
    final p = Path()
      ..moveTo(c.dx, c.dy - rad)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + rad, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + rad)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - rad, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - rad)
      ..close();
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}