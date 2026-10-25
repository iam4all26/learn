import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'kaida_loader.dart';

const Color kAuthPurpleDeep = Color(0xFF3A22C4);
const Color kAuthYellow = Color(0xFFFFC21A);

/// Shared layout for the Login and Register screens:
/// purple hero (logo, tagline, title) + white rounded sheet with the two tabs.
class AuthShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final int activeTab; // 0 = Sign In, 1 = Create Account
  final VoidCallback onSignInTab;
  final VoidCallback onSignUpTab;
  final VoidCallback? onBack;
  final bool loading;
  final Widget child;

  const AuthShell({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.activeTab,
    required this.onSignInTab,
    required this.onSignUpTab,
    required this.child,
    this.onBack,
    this.loading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;
    final screenH = MediaQuery.of(context).size.height;
    final heroH = topPad + 250.0;

    return Scaffold(
      backgroundColor: kAuthPurpleDeep,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // ---------------- Hero ----------------
                SizedBox(
                  height: heroH,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFF5B34F0), Color(0xFF3A22C4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        ),
                      ),
                      const Positioned.fill(child: CustomPaint(painter: _AuthHeroPainter())),
                      // Floating tiles
                      Positioned(right: 26, top: topPad + 40, child: _tile(Icons.play_arrow_rounded, 54, const Color(0xFF7B5CFF), Colors.white)),
                      Positioned(right: 96, top: topPad + 118, child: _tile(Icons.bar_chart_rounded, 58, const Color(0xFF4C2FE0), kAuthYellow, border: true)),
                      Positioned(right: 18, top: topPad + 128, child: _tile(Icons.school_rounded, 52, const Color(0xFF6B47F5), Colors.white)),
                      // Back arrow
                      if (onBack != null)
                        Positioned(
                          left: 8, top: topPad + 6,
                          child: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: onBack),
                        ),
                      // Texts
                      Positioned(
                        left: 24, right: 24, top: topPad + (onBack != null ? 50 : 22), bottom: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Image.asset('assets/kainuwa_academy_whitelogo.png', height: 44, fit: BoxFit.contain),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Kainuwa', style: TextStyle(color: Colors.white, fontSize: 22, height: 1.0, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                                    Text('Academy', style: TextStyle(color: kAuthYellow, fontSize: 22, height: 1.1, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(title, style: const TextStyle(color: Colors.white, fontSize: 32, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.62,
                              child: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.35)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ---------------- Sheet ----------------
                Container(
                  color: kAuthPurpleDeep,
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: screenH - heroH + 28),
                    transform: Matrix4.translationValues(0, -28, 0),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkBackgroundColor : Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _tab('Sign In', activeTab == 0, onSignInTab, isDark),
                            _tab('Create Account', activeTab == 1, onSignUpTab, isDark),
                          ],
                        ),
                        const SizedBox(height: 20),
                        child,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            Positioned.fill(
              child: Container(
                color: (isDark ? AppTheme.darkBackgroundColor : Colors.white).withOpacity(0.85),
                child: const Center(child: KaidaLoader()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: active ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(label, style: TextStyle(fontSize: 15.5, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? AppTheme.primaryColor : Colors.grey.shade600)),
            ),
            Container(height: active ? 3 : 1.5, color: active ? AppTheme.primaryColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, double size, Color bg, Color fg, {bool border = false}) {
    return Transform.rotate(
      angle: 0.12,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: border ? Border.all(color: kAuthYellow.withOpacity(0.7), width: 1.5) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Icon(icon, color: fg, size: size * 0.5),
      ),
    );
  }
}

class _AuthHeroPainter extends CustomPainter {
  const _AuthHeroPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Yellow blob top-right
    canvas.drawCircle(Offset(w * 1.02, h * 0.20), w * 0.34, Paint()..color = const Color(0xFFFFB020).withOpacity(0.95));
    canvas.drawCircle(Offset(w * 0.88, h * 0.78), w * 0.30, Paint()..color = Colors.white.withOpacity(0.06));
    // Yellow sweep bottom-left
    final sweep = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.90)
      ..quadraticBezierTo(w * 0.35, h * 0.80, w * 0.62, h)
      ..close();
    canvas.drawPath(sweep, Paint()..color = const Color(0xFFFFB020).withOpacity(0.9));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Boxed input used on Login and Register.
class AuthField extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final bool isPassword;
  final bool readOnly;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Widget? status;

  const AuthField({
    Key? key,
    required this.icon,
    required this.hint,
    required this.controller,
    this.label,
    this.obscure = false,
    this.onToggleObscure,
    this.isPassword = false,
    this.readOnly = false,
    this.keyboardType,
    this.onChanged,
    this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(14, label != null ? 8 : 2, 8, label != null ? 6 : 2),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey.shade800 : const Color(0xFFE3E0F5), width: 1.3),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null) Text(label!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E1E2D))),
                TextField(
                  controller: controller,
                  obscureText: obscure,
                  readOnly: readOnly,
                  onChanged: onChanged,
                  keyboardType: keyboardType,
                  style: TextStyle(color: readOnly ? Colors.grey : (isDark ? Colors.white : Colors.black), fontSize: 15.5, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: hint,
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14.5),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: label != null ? 4 : 15),
                  ),
                ),
              ],
            ),
          ),
          if (status != null) status!,
          if (isPassword)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade500, size: 21),
              onPressed: onToggleObscure,
            ),
        ],
      ),
    );
  }
}

/// Boxed row that opens a picker (language, country, state, city).
class AuthSelectRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final bool disabled;
  final VoidCallback onTap;

  const AuthSelectRow({Key? key, required this.icon, required this.label, required this.value, required this.placeholder, required this.onTap, this.disabled = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        decoration: BoxDecoration(
          color: disabled ? (isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8F7FD)) : (isDark ? AppTheme.darkSurfaceColor : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.grey.shade800 : const Color(0xFFE3E0F5), width: 1.3),
        ),
        child: Row(
          children: [
            Icon(icon, color: disabled ? Colors.grey.shade400 : AppTheme.primaryColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E1E2D))),
            ),
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF3F1FF), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(child: Text(value ?? placeholder, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: value == null ? Colors.grey.shade500 : (isDark ? Colors.white : Colors.black87)))),
                    Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const AuthPrimaryButton({Key? key, required this.label, required this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    return Row(
      children: [
        Expanded(child: Divider(color: c, thickness: 1.2)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('Or', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600))),
        Expanded(child: Divider(color: c, thickness: 1.2)),
      ],
    );
  }
}

class AuthGoogleButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget googleIcon;
  const AuthGoogleButton({Key? key, required this.onPressed, required this.googleIcon}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? AppTheme.darkSurfaceColor : Colors.white,
          side: BorderSide(color: isDark ? Colors.grey.shade800 : const Color(0xFFE3E0F5), width: 1.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            googleIcon,
            const SizedBox(width: 12),
            Text('Continue with Google', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E1E2D))),
          ],
        ),
      ),
    );
  }
}
