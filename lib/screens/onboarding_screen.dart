import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';
import 'login_screen.dart';
import 'dart:io';
import '../services/onboarding_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // image = a file in assets/images (null = drawn icon illustration)
  final List<Map<String, dynamic>> _pages = [
    {
      'image': 'assets/images/onboarding_1.png',
      'black': 'Learn Digital Skills ',
      'accent': 'in Hausa & English',
      'subtitle': 'High-quality courses and practical skills in Hausa and English, on your phone, anywhere, anytime.',
    },
    {
      'image': 'assets/images/onboarding_2.png',
      'black': 'A Wide Range of ',
      'accent': 'Skills',
      'subtitle': 'Choose from Graphic Design, Web Development, Cryptocurrency, Digital Marketing, AI Tools and more.',
    },
    {
      'image': 'assets/images/onboarding_3.png',
      'black': 'Learn at ',
      'accent': 'Your Own Pace',
      'subtitle': 'Watch videos, read guides, download files and practise, all inside your phone.',
    },
    {
      'image': null,
      'black': 'Build a ',
      'accent': 'Brighter Future',
      'subtitle': 'Get digital skills for work, business or building your own thing in Nigeria and Africa.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAdminSlides();
  }

  // Admin-set slides: use what is saved on the phone at once, then check the server quietly for changes.
  // Empty text / empty picture = keep the built-in one for that slide.
  Future<void> _loadAdminSlides() async {
    _applySlides(await OnboardingService.loadSaved());
    if (await OnboardingService.refresh()) {
      _applySlides(await OnboardingService.loadSaved());
    }
  }

  void _applySlides(List<Map<String, String>> slides) {
    if (!mounted || slides.isEmpty) return;
    setState(() {
      for (int i = 0; i < slides.length && i < _pages.length; i++) {
        final s = slides[i];
        if ((s['black'] ?? '').isNotEmpty) _pages[i]['black'] = s['black'];
        if ((s['accent'] ?? '').isNotEmpty) _pages[i]['accent'] = s['accent'];
        if ((s['subtitle'] ?? '').isNotEmpty) _pages[i]['subtitle'] = s['subtitle'];
        _pages[i]['file'] = (s['file'] ?? '').isNotEmpty ? s['file'] : null;
      }
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_time_user', false);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  void _next() {
    if (_currentPage == _pages.length - 1) {
      _completeOnboarding();
    } else {
      _pageController.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeInOut);
    }
  }

  Widget _hero(Map<String, dynamic> page) {
    final localFile = page['file'] as String?;
    if (localFile != null && localFile.isNotEmpty) {
      return Image.file(
        File(localFile),
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, size: 120, color: Color(0xFF6B47F5)),
      );
    }
    final img = page['image'] as String?;
    if (img != null) {
      return Image.asset(
        img,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, size: 120, color: Color(0xFF6B47F5)),
      );
    }
    // Last page: drawn illustration
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(width: 230, height: 230, decoration: BoxDecoration(color: const Color(0xFF6B47F5).withOpacity(0.10), shape: BoxShape.circle)),
        const Icon(Icons.emoji_events_rounded, size: 120, color: Color(0xFFFFC21A)),
        Positioned(right: 40, top: 40, child: _chipIcon(Icons.trending_up_rounded, const Color(0xFF7B5CFF))),
        Positioned(left: 40, bottom: 60, child: _chipIcon(Icons.workspace_premium_rounded, const Color(0xFFFFC21A), dark: true)),
        Positioned(right: 50, bottom: 40, child: _chipIcon(Icons.work_rounded, const Color(0xFF4C2FE0))),
      ],
    );
  }

  Widget _chipIcon(IconData icon, Color bg, {bool dark = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Icon(icon, color: dark ? const Color(0xFF3A22C4) : Colors.white, size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final last = _currentPage == _pages.length - 1;
    final bg = isDark ? AppTheme.darkBackgroundColor : Colors.white;
    final ink = isDark ? Colors.white : const Color(0xFF16123A);
    const yellow = Color(0xFFFFC21A);
    const imageBottom = 318.0; // space kept for the text and button

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // soft purple light behind the picture; it fades out into the white page
          Positioned(
            left: 0, right: 0, top: 0, height: MediaQuery.of(context).size.height * 0.62,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 0.1),
                  radius: 0.95,
                  colors: [const Color(0xFF6B47F5).withOpacity(isDark ? 0.30 : 0.16), const Color(0xFFFFC21A).withOpacity(isDark ? 0.04 : 0.06), bg.withOpacity(0)],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          // hero images (swipe). The bottom of every picture fades into the page, so it never looks cut.
          Positioned(
            left: 0, right: 0, top: topPad + 64, bottom: imageBottom - 40,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.68, 1.0],
              ).createShader(rect),
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (p) => setState(() => _currentPage = p),
                itemBuilder: (_, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _hero(_pages[i])),
              ),
            ),
          ),
          // logo + skip
          Positioned(
            left: 20, right: 20, top: topPad + 12,
            child: Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 42,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text('Kainuwa Academy', style: TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 18)),
                ),
                const Spacer(),
                if (!last)
                  GestureDetector(
                    onTap: _completeOnboarding,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.10), borderRadius: BorderRadius.circular(20)),
                      child: const Text('Skip', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
              ],
            ),
          ),
          // text, dots and button, straight on the white page
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPad + 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Column(
                      key: ValueKey(_currentPage),
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.15, letterSpacing: -0.5, color: ink),
                            children: [
                              TextSpan(text: _pages[_currentPage]['black'] as String),
                              TextSpan(text: _pages[_currentPage]['accent'] as String, style: const TextStyle(color: AppTheme.primaryColor)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 72,
                          child: Text(
                            _pages[_currentPage]['subtitle'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w500, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == i ? 24 : 8,
                        decoration: BoxDecoration(color: _currentPage == i ? yellow : (isDark ? Colors.grey.shade700 : const Color(0xFFDCD6F7)), borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF4C2FE0), Color(0xFF7B5CFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: const Color(0xFF4C2FE0).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 8))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_currentPage == 0 || last ? 'Get Started' : 'Next', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 10),
                          Container(width: 26, height: 26, decoration: const BoxDecoration(color: yellow, shape: BoxShape.circle), child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF1E1E2D), size: 17)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 38,
                    child: last
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('I already have an account  ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5)),
                              GestureDetector(
                                onTap: _completeOnboarding,
                                child: const Text('Sign In', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 14)),
                              ),
                            ],
                          )
                        : null,
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
