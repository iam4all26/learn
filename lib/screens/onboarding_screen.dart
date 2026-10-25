import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';
import 'login_screen.dart';

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
      'accent': 'in Hausa',
      'subtitle': 'High-quality courses and practical skills you can learn on your phone, anywhere, anytime.',
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
    final img = page['image'] as String?;
    if (img != null) {
      return Image.asset(
        img,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, size: 120, color: Colors.white54),
      );
    }
    // Last page: drawn illustration
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(width: 230, height: 230, decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), shape: BoxShape.circle)),
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
    final last = _currentPage == _pages.length - 1;
    final sheetColor = isDark ? AppTheme.darkSurfaceColor : Colors.white;

    return Scaffold(
      backgroundColor: const Color(0xFF3A22C4),
      body: Stack(
        children: [
          // purple gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF3A22C4), Color(0xFF6B47F5)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            ),
          ),
          // hero images (swipe)
          Positioned(
            left: 0, right: 0, top: topPad + 70, bottom: 330,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (p) => setState(() => _currentPage = p),
              itemBuilder: (_, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _hero(_pages[i])),
            ),
          ),
          // logo + skip
          Positioned(
            left: 20, right: 20, top: topPad + 12,
            child: Row(
              children: [
                Image.asset('assets/kainuwa_academy_whitelogo.png', height: 44, fit: BoxFit.contain),
                const Spacer(),
                if (!last)
                  GestureDetector(
                    onTap: _completeOnboarding,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
                      child: const Text('Skip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
              ],
            ),
          ),
          // white bottom sheet
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(24, 28, 24, MediaQuery.of(context).padding.bottom + 22),
              decoration: BoxDecoration(color: sheetColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(34))),
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
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.15, letterSpacing: -0.5, color: isDark ? Colors.white : const Color(0xFF16123A)),
                            children: [
                              TextSpan(text: _pages[_currentPage]['black'] as String),
                              TextSpan(text: _pages[_currentPage]['accent'] as String, style: const TextStyle(color: AppTheme.primaryColor)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
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
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == i ? 22 : 8,
                        decoration: BoxDecoration(color: _currentPage == i ? AppTheme.primaryColor : (isDark ? Colors.grey.shade700 : Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_currentPage == 0 || last ? 'Get Started' : 'Next', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
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