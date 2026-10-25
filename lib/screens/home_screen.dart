import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../widgets/kaida_loader.dart';
import '../utils/kaida_alert.dart';
import 'course_player_screen.dart';
import 'catalog_screen.dart';
import 'item_details_screen.dart';
import 'categories_screen.dart';
import 'instructor_profile_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingDashboard = true;
  bool _isLoadingCatalog = true;
  Map<String, dynamic>? _dashboardData;
  
  List<CatalogItem> _activeCourses = [];
  List<CatalogItem> _comingSoonCourses = [];
  Set<int> _wishlistedCourseIds = {}; 
  
  String _userName = "Learner"; 
  String? _userAvatar;
  int _unreadNotifications = 0; 

  List<dynamic> _banners = [];
  List<dynamic> _categories = [];
  List<dynamic> _instructors = [];

  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _fetchCatalogData();
    _fetchWishlist();
    _fetchUnreadCount(); 
    _syncFcmToken(); 
    _startBannerTimer();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_bannerController.hasClients && _banners.isNotEmpty) {
        int nextIndex = _currentBannerIndex + 1;
        if (nextIndex >= _banners.length) nextIndex = 0;
        _bannerController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  Future<void> _syncFcmToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userIdStr = prefs.get('user_id')?.toString();
      final userId = int.tryParse(userIdStr ?? '');
      
      if (userId == null) return;
      
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        String apiUrl = '${ApiConfig.baseUrl}/save_fcm_token.php'.replaceAll('//save_fcm', '/save_fcm');
        await http.post(
          Uri.parse(apiUrl),
          body: {'user_id': userId.toString(), 'token': token},
        );
      }
    } catch (e) {
      // Silent
    }
  }

  Future<void> _fetchUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) return;

    try {
      String apiUrl = '${ApiConfig.baseUrl}/notifications_api.php'.replaceAll('//notifications_api', '/notifications_api');
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {'action': 'get', 'user_id': userId.toString()}
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && mounted) {
          setState(() {
            _unreadNotifications = int.tryParse(data['unread_count'].toString()) ?? 0;
          });
        }
      }
    } catch (e) {
      // Silent
    }
  }

  Future<void> _fetchWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) return;
    try {
      final response = await http.post(Uri.parse(ApiConfig.getWishlist), body: {'user_id': userId.toString()});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && mounted) {
          setState(() {
            _wishlistedCourseIds = (data['data'] as List)
                .where((item) => item['item_type'] == 'course')
                .map<int>((item) => int.tryParse((item['item_id'] ?? item['id']).toString()) ?? 0)
                .toSet();
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _toggleWishlist(int courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      KaidaAlert.showModal(context: context, title: 'Authentication Required', message: 'Please log in to save courses.', isError: true);
      return;
    }

    final isCurrentlyWishlisted = _wishlistedCourseIds.contains(courseId);
    
    setState(() {
      if (isCurrentlyWishlisted) _wishlistedCourseIds.remove(courseId);
      else _wishlistedCourseIds.add(courseId);
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.toggleWishlist),
        body: {'user_id': userId.toString(), 'item_id': courseId.toString(), 'item_type': 'course'}
      );
      final data = json.decode(response.body);
      
      if (data['status'] != 'success') {
        setState(() {
          if (isCurrentlyWishlisted) _wishlistedCourseIds.add(courseId);
          else _wishlistedCourseIds.remove(courseId);
        });
        KaidaAlert.showModal(context: context, title: 'Action Failed', message: data['message'] ?? 'Action failed.', isError: true);
      }
    } catch (e) {
      setState(() {
        if (isCurrentlyWishlisted) _wishlistedCourseIds.add(courseId);
        else _wishlistedCourseIds.remove(courseId);
      });
    }
  }

  Future<void> _fetchDashboardData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final savedName = prefs.getString('full_name') ?? prefs.getString('name') ?? prefs.getString('username') ?? "Learner";
      
      if (mounted) setState(() {
        _userName = savedName;
        _userAvatar = prefs.getString('avatar_url'); 
      });
      
      if (userId == null) return;

      final response = await http.post(Uri.parse(ApiConfig.dashboardData), body: {'user_id': userId.toString()});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && mounted) {
          setState(() {
            _dashboardData = data['data'];
            _banners = data['data']['banners'] ?? [];
            _categories = data['data']['categories'] ?? [];
            _instructors = data['data']['instructors'] ?? [];
            
            if (data['data']['user'] != null && data['data']['user']['avatar_url'] != null) {
              _userAvatar = data['data']['user']['avatar_url'];
              prefs.setString('avatar_url', _userAvatar!);
            }
            _isLoadingDashboard = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDashboard = false);
    }
  }

  Future<void> _fetchCatalogData() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/catalog.php?action=courses'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          List<dynamic> list = data['data'];
          List<CatalogItem> active = [];
          List<CatalogItem> coming = [];
          
          for (var item in list) {
            try {
              CatalogItem parsed = CatalogItem.fromJson(item, 'courses');
              // FIXED LOGIC HERE: Correctly separating lists without breaking UI
              if (parsed.isComingSoon) {
                coming.add(parsed);
              } else {
                active.add(parsed);
              }
            } catch (e) {}
          }
          if (mounted) {
            setState(() {
              _activeCourses = active;
              _comingSoonCourses = coming;
              _isLoadingCatalog = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCatalog = false);
    }
  }

  List<CatalogItem> _getSubList(List<CatalogItem> source, int startIndex, int count) {
    if (source.isEmpty) return [];
    int safeStart = startIndex % source.length;
    List<CatalogItem> result = [];
    for(int i=0; i<count; i++) {
      if (i < source.length) result.add(source[(safeStart + i) % source.length]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : Colors.white,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: () async {
            await _fetchDashboardData();
            await _fetchCatalogData();
            await _fetchWishlist();
            await _fetchUnreadCount(); 
            await _syncFcmToken(); 
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(isDark),
                _buildCategoryTiles(isDark),
                _buildContinueLearning(isDark),

                const SizedBox(height: 24),

                if (_isLoadingCatalog)
                   const Center(child: Padding(padding: EdgeInsets.all(40), child: KaidaLoader()))
                else ...[
                  _buildCourseHorizontalList('Featured Courses', _getSubList(_activeCourses, 0, 4), isDark),
                  const SizedBox(height: 24),
                  _buildCourseHorizontalList('Popular Now', _getSubList(_activeCourses, 2, 4), isDark),
                  
                  if (_comingSoonCourses.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildCourseHorizontalList('Coming Soon', _comingSoonCourses, isDark, isComingSoon: true),
                  ],

                  const SizedBox(height: 24),
                  if (_instructors.isNotEmpty) _buildInstructorsRow(isDark)
                  else _buildFallbackInstructorsRow(isDark),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HERO: banner slider sits behind the header, greeting and search card
  // ---------------------------------------------------------------------------
  Widget _buildHero(bool isDark) {
    final topPad = MediaQuery.of(context).padding.top;
    final heroHeight = 300.0 + topPad;
    String safeAvatar = _userAvatar ?? '';
    if (safeAvatar.isNotEmpty && !safeAvatar.startsWith('http')) {
      safeAvatar = 'https://academy.kainuwa.africa/$safeAvatar';
    }
    final firstName = _userName.trim().split(' ').first;

    return Padding(
      padding: const EdgeInsets.only(bottom: 44),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Banner images (or a purple gradient when there are none)
          SizedBox(
            height: heroHeight,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF4C2FE0), Color(0xFF7351FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    ),
                  ),
                  if (_banners.isNotEmpty)
                    PageView.builder(
                      controller: _bannerController,
                      onPageChanged: (index) => setState(() => _currentBannerIndex = index),
                      itemCount: _banners.length,
                      itemBuilder: (context, index) {
                        final url = (_banners[index]['image_url'] ?? '').toString();
                        if (url.isEmpty) return const SizedBox();
                        return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                            errorWidget: (c, u, e) => const SizedBox());
                      },
                    ),
                  // Soft overlays keep the header and greeting readable
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.35, 0.6, 1.0],
                          colors: [
                            const Color(0xFF2A1580).withOpacity(0.85),
                            const Color(0xFF2A1580).withOpacity(0.15),
                            const Color(0xFF2A1580).withOpacity(0.25),
                            const Color(0xFF2A1580).withOpacity(0.9),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Header row: logo + name on the left, search / bell / avatar on the right
          Positioned(
            top: topPad + 10, left: 16, right: 16,
            child: Row(
              children: [
                Image.asset('assets/kainuwa_academy_whitelogo.png', height: 36, fit: BoxFit.contain),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Kainuwa Academy', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                ),
                _heroIconButton(Icons.search_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen(actionType: 'courses', title: 'Search Courses')))),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())).then((_) => _fetchUnreadCount()),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _heroIconButton(Icons.notifications_none_rounded, null),
                      if (_unreadNotifications > 0)
                        Positioned(
                          top: -3, right: -3,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                            child: Text(_unreadNotifications > 9 ? '9+' : '$_unreadNotifications', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                      backgroundImage: safeAvatar.isNotEmpty ? CachedNetworkImageProvider(safeAvatar) : null,
                      child: safeAvatar.isEmpty ? const Icon(Icons.person_rounded, color: AppTheme.primaryColor, size: 20) : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Greeting + call-to-action
          Positioned(
            left: 20, right: 20, bottom: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getGreeting().replaceAll(',', ''), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(firstName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen(actionType: 'courses', title: 'Explore Courses'))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    decoration: BoxDecoration(color: const Color(0xFFFFC21A), borderRadius: BorderRadius.circular(30)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Start Learning', style: TextStyle(color: Color(0xFF1E1E2D), fontWeight: FontWeight.w800, fontSize: 14)),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF1E1E2D)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Slider dots
          if (_banners.length > 1)
            Positioned(
              right: 22, bottom: 58,
              child: Row(
                children: List.generate(
                  _banners.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    height: 6,
                    width: _currentBannerIndex == index ? 18 : 6,
                    decoration: BoxDecoration(
                      color: _currentBannerIndex == index ? const Color(0xFFFFC21A) : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

          // 5. Floating search card overlapping the hero
          Positioned(
            left: 16, right: 16, bottom: -28,
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen(actionType: 'courses', title: 'Search Courses'))),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.12), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppTheme.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Search courses, skills or topics...', style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.tune_rounded, color: AppTheme.primaryColor, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroIconButton(IconData icon, VoidCallback? onTap) {
    final w = Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 20),
    );
    return onTap == null ? w : GestureDetector(onTap: onTap, child: w);
  }

  // ---------------------------------------------------------------------------
  // CATEGORIES: coloured rounded tiles
  // ---------------------------------------------------------------------------
  static const List<Color> _tileColors = [
    Color(0xFF7351FF), Color(0xFFFFB020), Color(0xFFEF4444), Color(0xFF2F80ED),
    Color(0xFF22C55E), Color(0xFFF97316), Color(0xFFEC4899), Color(0xFF06B6D4),
  ];

  IconData _iconForCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('web') || n.contains('cod') || n.contains('program') || n.contains('develop') || n.contains('tech')) return Icons.code_rounded;
    if (n.contains('design') || n.contains('graphic') || n.contains('art') || n.contains('canva')) return Icons.palette_rounded;
    if (n.contains('video') || n.contains('youtube') || n.contains('content') || n.contains('edit')) return Icons.play_circle_fill_rounded;
    if (n.contains('crypto') || n.contains('block') || n.contains('forex') || n.contains('trad') || n.contains('financ')) return Icons.attach_money_rounded;
    if (n.contains('market') || n.contains('social') || n.contains('seo') || n.contains('advert')) return Icons.campaign_rounded;
    if (n.contains('business') || n.contains('entrepren') || n.contains('sales')) return Icons.business_center_rounded;
    if (n.contains('ai') || n.contains('smart') || n.contains('phone') || n.contains('mobile')) return Icons.auto_awesome_rounded;
    if (n.contains('photo') || n.contains('camera')) return Icons.photo_camera_rounded;
    if (n.contains('language') || n.contains('english') || n.contains('hausa')) return Icons.translate_rounded;
    return Icons.category_rounded;
  }

  Widget _sectionHeader(String title, VoidCallback onSeeAll) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          GestureDetector(
            onTap: onSeeAll,
            child: Row(children: const [
              Text('See All', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(width: 2),
              Icon(Icons.arrow_forward_rounded, size: 15, color: AppTheme.primaryColor),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTiles(bool isDark) {
    final List<Map<String, dynamic>> cats = _categories.isNotEmpty
        ? _categories.map<Map<String, dynamic>>((c) => {'id': c['id'].toString(), 'name': (c['name'] ?? '').toString()}).toList()
        : [
            {'id': '1', 'name': 'Coding'},
            {'id': '2', 'name': 'Design'},
            {'id': '3', 'name': 'Business'},
            {'id': '4', 'name': 'Marketing'},
          ];
    final total = cats.length + 1; // + "More" tile

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: SizedBox(
        height: 96,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: total,
          itemBuilder: (context, index) {
            final isMore = index == cats.length;
            final name = isMore ? 'More' : cats[index]['name'] as String;
            final color = isMore ? Colors.grey.shade400 : _tileColors[index % _tileColors.length];
            return GestureDetector(
              onTap: () {
                if (isMore) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CatalogScreen(actionType: 'category_${cats[index]['id']}', title: name)));
                }
              },
              child: SizedBox(
                width: 76,
                child: Column(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      child: Icon(isMore ? Icons.grid_view_rounded : _iconForCategory(name), color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.15)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONTINUE LEARNING (only when the student has an unfinished course)
  // ---------------------------------------------------------------------------
  Widget _buildContinueLearning(bool isDark) {
    final rc = _dashboardData != null ? _dashboardData!['recent_course'] : null;
    if (rc == null || rc is! Map) return const SizedBox();
    final id = int.tryParse(rc['id'].toString()) ?? 0;
    if (id == 0) return const SizedBox();
    final title = (rc['title'] ?? '').toString();
    final progress = ((double.tryParse(rc['progress_percentage'].toString()) ?? 0).clamp(0, 100)).toDouble();
    String thumb = (rc['thumbnail_url'] ?? '').toString();
    if (thumb.isNotEmpty && !thumb.startsWith('http')) thumb = 'https://academy.kainuwa.africa/$thumb';

    void open() => Navigator.push(context, MaterialPageRoute(builder: (_) => CoursePlayerScreen(courseId: id, courseTitle: title)));

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: const Text('Continue Learning', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          ),
          GestureDetector(
            onTap: open,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.07), blurRadius: 14, offset: const Offset(0, 5))],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: thumb.isNotEmpty
                        ? CachedNetworkImage(imageUrl: thumb, width: 110, height: 80, fit: BoxFit.cover)
                        : Container(width: 110, height: 80, color: AppTheme.primaryColor.withOpacity(0.15), child: const Icon(Icons.school_rounded, color: AppTheme.primaryColor, size: 32)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.2)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(value: progress / 100, minHeight: 7, backgroundColor: AppTheme.primaryColor.withOpacity(0.12), valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${progress.round()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: AppTheme.primaryColor, size: 26),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackInstructorsRow(bool isDark) {
    final defaultInstructors = ['Mal. Ibrahim', 'Osama Elguduwis', 'Ummulkhairi'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text('Top Instructors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: defaultInstructors.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InstructorProfileScreen(instructor: {'name': defaultInstructors[index]}))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    children: [
                      CircleAvatar(radius: 30, backgroundColor: AppTheme.primaryColor.withOpacity(0.1), child: const Icon(Icons.person_rounded, color: AppTheme.primaryColor)),
                      const SizedBox(height: 8),
                      Text(defaultInstructors[index], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInstructorsRow(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text('Top Instructors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _instructors.length,
            itemBuilder: (context, index) {
              String? rawAvatar = _instructors[index]['avatar_url']?.toString();
              String? safeAvatar;
              if (rawAvatar != null && rawAvatar.isNotEmpty) {
                safeAvatar = rawAvatar.startsWith('http') ? rawAvatar : 'https://academy.kainuwa.africa/$rawAvatar';
              }

              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InstructorProfileScreen(instructor: _instructors[index]))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30, 
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1), 
                        backgroundImage: safeAvatar != null ? CachedNetworkImageProvider(safeAvatar) : null,
                        child: safeAvatar == null ? const Icon(Icons.person_rounded, color: AppTheme.primaryColor) : null,
                      ),
                      const SizedBox(height: 8),
                      Text(_instructors[index]['name'] ?? 'Instructor', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCourseHorizontalList(String title, List<CatalogItem> items, bool isDark, {bool isComingSoon = false}) {
    if (items.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CatalogScreen(actionType: 'courses', title: 'Explore Courses'))),
                child: const Text('See All', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 290, 
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) => _buildCourseCard(items[index], isDark, isComingSoon),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseCard(CatalogItem item, bool isDark, bool isComingSoon) {
    int discountPercent = 0;
    if (item.price > 0 && item.discountPrice > 0 && item.discountPrice < item.price) {
      discountPercent = (((item.price - item.discountPrice) / item.price) * 100).round();
    }
    
    bool isWishlisted = _wishlistedCourseIds.contains(item.id);

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailsScreen(item: item)));
      },
      child: Container(
        width: 220, 
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: isDark ? Colors.black12 : Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: item.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: item.thumbnailUrl, height: 120, width: double.infinity, fit: BoxFit.cover)
                      : Container(height: 120, color: AppTheme.primaryColor.withOpacity(0.2), child: const Icon(Icons.school_rounded, size: 40, color: AppTheme.primaryColor)),
                ),
                if (discountPercent > 0 && !isComingSoon && !item.isOutOfStock)
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                      child: Text('-$discountPercent%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (!isComingSoon && !item.isOutOfStock)
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () => _toggleWishlist(item.id),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9), 
                          shape: BoxShape.circle
                        ),
                        child: Icon(
                          isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isWishlisted ? Colors.redAccent : Colors.grey.shade600,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                // FIXED UI STACKING LOGIC
                if (isComingSoon)
                  Container(height: 120, color: Colors.black54, child: const Center(child: Icon(Icons.lock_clock_rounded, color: Colors.white, size: 30)))
                else if (item.isOutOfStock)
                  Container(height: 120, color: Colors.black54, child: const Center(child: Text('OUT OF STOCK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)))),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(item.categoryName.toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5), overflow: TextOverflow.ellipsis)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(item.language.toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(child: Text(item.instructorName, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  if (!isComingSoon && item.type == 'courses' && true) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.play_lesson_rounded, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(item.lessonCount > 0 ? '${item.lessonCount} Lessons' : 'Lessons soon', style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (item.avgRating > 0) ...[
                          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB020)),
                          const SizedBox(width: 2),
                          Text(item.avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        ] else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: const Text('New', style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (isComingSoon)
                    const Text('COMING SOON', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13))
                  else if (item.isOutOfStock)
                    const Text('UNAVAILABLE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12))
                  else if (item.isFree || (item.price == 0 && item.discountPrice == 0))
                    const Text('FREE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14))
                  else if (item.discountPrice > 0 && item.discountPrice < item.price)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₦${item.discountPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primaryColor)),
                        const SizedBox(width: 6),
                        Text('₦${item.price.toStringAsFixed(0)}', style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    )
                  else
                    Text('₦${item.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primaryColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
