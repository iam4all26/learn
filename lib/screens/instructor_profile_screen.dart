import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../widgets/kaida_loader.dart';
import 'catalog_screen.dart';
import 'item_details_screen.dart';
import '../widgets/kaida_empty_state.dart';

class InstructorProfileScreen extends StatefulWidget {
  final Map<String, dynamic> instructor;
  const InstructorProfileScreen({Key? key, required this.instructor}) : super(key: key);

  @override
  _InstructorProfileScreenState createState() => _InstructorProfileScreenState();
}

class _InstructorProfileScreenState extends State<InstructorProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _d;
  List<CatalogItem> _courses = [];
  List<dynamic> _reviews = [];
  int _tab = 0; // 0 About, 1 Courses, 2 Reviews

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final id = widget.instructor['id']?.toString() ?? '0';
    if (id == '0') {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final response = await http.get(Uri.parse('${ApiConfig.getInstructor}?id=$id'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && mounted) {
          setState(() {
            _d = data['data']['instructor'];
            _courses = (data['data']['courses'] as List? ?? []).map((c) => CatalogItem.fromJson(c, 'courses')).toList();
            _reviews = data['data']['reviews'] as List? ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Instructor fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _url(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw.startsWith('http') ? raw : 'https://academy.kainuwa.africa/${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }

  String _clean(String s) => s
      .replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#039;', "'").replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<').replaceAll('&gt;', '>');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;

    String avatar = _url(widget.instructor['avatar_url']?.toString());
    String name = _clean('${widget.instructor['name'] ?? 'Instructor'}');
    String headline = '', bio = '', since = '';
    bool verified = false;
    int students = 0, reviews = 0, courses = _courses.length;
    double rating = 0;
    List<String> topics = [];
    if (_d != null) {
      avatar = _url(_d!['avatar_url']?.toString());
      name = _clean('${_d!['full_name'] ?? _d!['username'] ?? name}');
      headline = _clean('${_d!['headline'] ?? ''}');
      bio = _clean('${_d!['bio'] ?? ''}');
      verified = '${_d!['is_verified_instructor']}' == '1';
      students = int.tryParse('${_d!['total_students']}') ?? 0;
      reviews = int.tryParse('${_d!['total_reviews']}') ?? 0;
      courses = int.tryParse('${_d!['total_courses']}') ?? courses;
      rating = double.tryParse('${_d!['avg_rating']}') ?? 0;
      since = '${_d!['member_since'] ?? ''}';
      topics = (_d!['topics'] as List? ?? []).map((e) => '$e').toList();
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : const Color(0xFFF6F5FB),
      body: _isLoading
          ? const Center(child: KaidaLoader())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // ---------- hero ----------
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 26),
                    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF3A22C4), Color(0xFF6B47F5)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), shape: BoxShape.circle),
                                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 19),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Image.asset('assets/kainuwa_academy_whitelogo.png', height: 34, fit: BoxFit.contain),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(color: Color(0xFFFFC21A), shape: BoxShape.circle),
                                  child: CircleAvatar(
                                    radius: 46,
                                    backgroundColor: Colors.white,
                                    backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                                    child: avatar.isEmpty ? const Icon(Icons.person_rounded, size: 46, color: AppTheme.primaryColor) : null,
                                  ),
                                ),
                                if (verified)
                                  Positioned(
                                    right: 0, bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: const Icon(Icons.verified_rounded, color: Color(0xFF4C2FE0), size: 24),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, height: 1.15, letterSpacing: -0.4)),
                                  const SizedBox(height: 4),
                                  Text('Instructor', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15)),
                                  if (verified) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(color: const Color(0xFFFFC21A), borderRadius: BorderRadius.circular(20)),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.school_rounded, size: 16, color: Color(0xFF3A22C4)),
                                          SizedBox(width: 6),
                                          Text('Verified Instructor', style: TextStyle(color: Color(0xFF2B1A8F), fontWeight: FontWeight.w800, fontSize: 12.5)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (headline.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(headline, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14.5, fontWeight: FontWeight.w500)),
                        ],
                      ],
                    ),
                  ),

                  // ---------- tabs ----------
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 3))]),
                    child: Row(
                      children: [
                        _tabBtn('About', Icons.person_rounded, 0),
                        _tabBtn('Courses', Icons.play_circle_fill_rounded, 1),
                        _tabBtn('Reviews', Icons.chat_bubble_rounded, 2),
                      ],
                    ),
                  ),

                  // ---------- stats ----------
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 3))]),
                    child: Row(
                      children: [
                        _stat(Icons.menu_book_rounded, const Color(0xFF5B34F0), '$courses', 'Courses', isDark),
                        _stat(Icons.groups_rounded, const Color(0xFF2F80ED), '$students', 'Students', isDark),
                        _stat(Icons.star_rounded, const Color(0xFFFFB020), rating > 0 ? rating.toStringAsFixed(1) : '-', '$reviews reviews', isDark),
                        if (since.isNotEmpty) _stat(Icons.calendar_month_rounded, const Color(0xFF22A06B), since, 'Member since', isDark),
                      ],
                    ),
                  ),

                  // ---------- tab content ----------
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                    child: _tab == 0 ? _about(bio, topics, isDark) : (_tab == 1 ? _coursesTab(isDark) : _reviewsTab(isDark)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _tabBtn(String label, IconData icon, int i) {
    final active = _tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(color: active ? AppTheme.primaryColor : Colors.transparent, borderRadius: BorderRadius.circular(14)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: active ? Colors.white : Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: active ? Colors.white : Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(IconData icon, Color color, String value, String label, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 1),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String t, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 21, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(t, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
      ]),
    );
  }

  Widget _about(String bio, List<String> topics, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.person_rounded, 'About', isDark),
        Text(bio.isNotEmpty ? bio : 'This instructor has not added a biography yet.', style: TextStyle(fontSize: 14.5, height: 1.6, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
        if (topics.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: topics.map((t) => _chip(t, isDark)).toList()),
        ],
        if (_courses.isNotEmpty) ...[
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(child: _sectionTitle(Icons.menu_book_rounded, 'Instructor Courses', isDark)),
              GestureDetector(onTap: () => setState(() => _tab = 1), child: const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('See all  →', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 13)))),
            ],
          ),
          ..._courses.take(2).map((c) => _courseCard(c, isDark)),
        ],
      ],
    );
  }

  Widget _chip(String t, bool isDark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
        child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
      );

  Widget _coursesTab(bool isDark) {
    if (_courses.isEmpty) {
      return const SizedBox(height: 330, child: KaidaEmptyState(kind: KaidaEmptyKind.courses, title: 'No courses here yet', message: 'This instructor has no active courses at the moment.'));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(Icons.menu_book_rounded, 'Instructor Courses', isDark),
      ..._courses.map((c) => _courseCard(c, isDark)),
    ]);
  }

  Widget _courseCard(CatalogItem item, bool isDark) {
    final onSale = item.discountPrice > 0 && item.discountPrice < item.price;
    final free = item.isFree || (item.price == 0 && item.discountPrice == 0);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: item))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 3))]),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 118, height: 100,
                child: item.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(imageUrl: item.thumbnailUrl, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: AppTheme.primaryColor.withOpacity(0.15)))
                    : Container(color: AppTheme.primaryColor.withOpacity(0.15), child: const Icon(Icons.school_rounded, color: AppTheme.primaryColor, size: 34)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_clean(item.title), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.2, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (item.lessonCount > 0) ...[
                        Icon(Icons.play_circle_outline_rounded, size: 15, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text('${item.lessonCount} lessons', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                      ],
                      if (item.avgRating > 0) ...[
                        const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFB020)),
                        const SizedBox(width: 2),
                        Text(item.avgRating.toStringAsFixed(1), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [
                    _miniTag(item.categoryName, isDark),
                    _miniTag(item.language, isDark),
                  ]),
                  const SizedBox(height: 6),
                  if (free)
                    const Text('FREE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 14))
                  else
                    Row(children: [
                      Text('₦${(onSale ? item.discountPrice : item.price).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.primaryColor)),
                      if (onSale) ...[
                        const SizedBox(width: 6),
                        Text('₦${item.price.toStringAsFixed(0)}', style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniTag(String t, bool isDark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10.5, fontWeight: FontWeight.w700)),
      );

  Widget _reviewsTab(bool isDark) {
    if (_reviews.isEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No reviews yet.', style: TextStyle(color: Colors.grey.shade500))));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.chat_bubble_rounded, 'Student Reviews', isDark),
        ..._reviews.map((r) {
          final stars = int.tryParse('${r['rating']}') ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 3))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_clean('${r['reviewer'] ?? 'Student'}'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : Colors.black87))),
                    for (int i = 0; i < 5; i++) Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 16, color: const Color(0xFFFFB020)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(_clean('${r['course_title'] ?? ''}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
                if ('${r['review_text'] ?? ''}'.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_clean('${r['review_text']}'), style: TextStyle(fontSize: 13.5, height: 1.5, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}