import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../widgets/kaida_loader.dart';
import '../widgets/page_header.dart';
import 'course_player_screen.dart';
import 'main_layout.dart';
import 'catalog_screen.dart';
import 'item_details_screen.dart';
import 'notifications_screen.dart';
import 'downloads_screen.dart';
import '../widgets/kaida_empty_state.dart';
import 'categories_screen.dart';

/// "My Learning": In Progress / Completed / Downloaded.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _myCourses = [];
  List<dynamic> _downloads = [];
  int _tab = 0; // 0 In Progress, 1 Completed, 2 Downloaded
  String _searchQuery = '';
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _clean(String s) => s
      .replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#039;', "'").replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<').replaceAll('&gt;', '>');

  int _progress(dynamic c) => int.tryParse(c['progress_percentage']?.toString() ?? '0') ?? 0;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final cached = prefs.getString('cached_my_courses');
    if (cached != null) {
      try {
        final data = json.decode(cached);
        if (mounted) setState(() { _myCourses = data; _isLoading = false; });
      } catch (_) {}
    }

    try {
      final results = await Future.wait([
        http.post(Uri.parse(ApiConfig.myCourses), body: {'user_id': userId.toString()}),
        http.post(Uri.parse(ApiConfig.myDownloads), body: {'user_id': userId.toString()}),
      ]);
      final c = json.decode(results[0].body);
      if (c['status'] == 'success') {
        prefs.setString('cached_my_courses', json.encode(c['data']));
        _myCourses = c['data'];
      }
      final d = json.decode(results[1].body);
      if (d['status'] == 'success') _downloads = d['data'];
    } catch (e) {
      debugPrint('My Learning error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<dynamic> get _inProgress => _myCourses.where((c) => _progress(c) < 100).toList();
  List<dynamic> get _completed => _myCourses.where((c) => _progress(c) >= 100).toList();

  List<dynamic> get _visible {
    final base = _tab == 0 ? _inProgress : (_tab == 1 ? _completed : _downloads);
    if (_searchQuery.isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((c) => '${c['title'] ?? ''}'.toLowerCase().contains(q)).toList();
  }

  String _thumb(dynamic raw) {
    String t = raw?.toString() ?? '';
    if (t.isNotEmpty && !t.startsWith('http')) t = 'https://academy.kainuwa.africa/' + t.replaceFirst(RegExp(r'^/+'), '');
    return t;
  }

  void _openPlayer(dynamic course) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CoursePlayerScreen(courseId: int.parse(course['id'].toString()), courseTitle: course['title'])))
        .then((_) => _load());
  }

  void _openDetails(dynamic course) {
    final dummy = CatalogItem(
      id: int.tryParse(course['id'].toString()) ?? 0,
      title: _clean('${course['title'] ?? 'Course'}'),
      slug: course['slug']?.toString() ?? '',
      thumbnailUrl: course['thumbnail_url']?.toString() ?? '',
      price: 0.0, discountPrice: 0.0, isFree: true,
      instructorName: course['instructor_name']?.toString() ?? '',
      categoryName: 'Course', language: 'EN', type: 'courses', productType: 'digital',
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: dummy)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labels = ['In Progress (${_inProgress.length})', 'Completed (${_completed.length})', 'Downloaded (${_downloads.length})'];

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : const Color(0xFFF6F5FB),
      body: Column(
        children: [
          PageHeader(
            title: 'My Learning',
            subtitle: 'Continue where you left off',
            showBack: Navigator.of(context).canPop(),
            actions: [
              PageHeader.circleButton(_showSearch ? Icons.close_rounded : Icons.search_rounded, () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) { _searchQuery = ''; _searchController.clear(); }
                });
              }),
              PageHeader.circleButton(Icons.notifications_none_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            ],
            bottom: HeaderTabs(labels: labels, selected: _tab, onChanged: (i) => setState(() => _tab = i)),
            bottomPadding: 16,
          ),
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search my learning...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const KaidaSkeletonList()
                : RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: _load,
                    child: _visible.isEmpty
                        ? _emptyState(isDark)
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                            itemCount: _visible.length,
                            itemBuilder: (context, i) => _tab == 2 ? _downloadCard(_visible[i], isDark) : _courseCard(_visible[i], isDark),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(bool isDark) {
    final noneAtAll = _searchQuery.isEmpty;
    final go = () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 1)), (r) => false);
    KaidaEmptyKind kind = KaidaEmptyKind.courses;
    String? title, sub;
    if (!noneAtAll) {
      kind = KaidaEmptyKind.search;
    } else if (_tab == 0) {
      title = _myCourses.isEmpty ? 'Ready to start learning?' : 'No courses in progress';
      sub = _myCourses.isEmpty ? 'Explore the catalog to find your first course.' : 'Pick a new course to keep learning.';
    } else if (_tab == 1) {
      title = 'No completed courses yet'; sub = 'Finish a course and it will show up here.';
    } else {
      kind = KaidaEmptyKind.downloads;
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: KaidaEmptyState(
            kind: kind,
            title: title,
            message: sub,
            primaryLabel: (noneAtAll && _tab != 2) ? 'Browse all courses' : null,
            onPrimary: (noneAtAll && _tab != 2) ? go : null,
            secondaryLabel: (noneAtAll && _tab != 2) ? 'Browse all categories' : null,
            secondaryAsLink: true,
            onSecondary: (noneAtAll && _tab != 2) ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())) : null,
          ),
        ),
      ],
    );
  }

  Widget _courseCard(dynamic course, bool isDark) {
    final thumb = _thumb(course['thumbnail_url']);
    final progress = _progress(course).clamp(0, 100);
    final done = progress >= 100;
    final lessons = int.tryParse(course['lesson_count']?.toString() ?? '0') ?? 0;
    final rating = double.tryParse(course['avg_rating']?.toString() ?? '0') ?? 0;
    final green = const Color(0xFF22A06B);
    final accent = done ? green : AppTheme.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 92, height: 92,
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  child: thumb.isNotEmpty
                      ? Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_fill, color: AppTheme.primaryColor, size: 34))
                      : const Icon(Icons.play_circle_fill, color: AppTheme.primaryColor, size: 34),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_clean('${course['title'] ?? ''}'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.2, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 5),
                    Text('${course['instructor_name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (lessons > 0) ...[
                          Icon(Icons.menu_book_rounded, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text('$lessons lessons', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 10),
                        ],
                        if (rating > 0) ...[
                          const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFB020)),
                          const SizedBox(width: 2),
                          Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w800)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(value: progress / 100, minHeight: 7, backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200, color: accent),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('$progress%', style: TextStyle(color: accent, fontSize: 12.5, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: done
                    ? Container(
                        height: 42,
                        decoration: BoxDecoration(color: green.withOpacity(0.14), borderRadius: BorderRadius.circular(21)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, color: green, size: 19),
                            const SizedBox(width: 6),
                            Text('Completed', style: TextStyle(color: green, fontWeight: FontWeight.w800, fontSize: 14)),
                          ],
                        ),
                      )
                    : SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: () => _openPlayer(course),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21))),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                          label: Text(progress > 0 ? 'Continue Learning' : 'Start Course', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: () => done ? _openPlayer(course) : _openDetails(course),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21))),
                    child: Text(done ? 'Review' : 'Details', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 13.5)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _downloadCard(dynamic d, bool isDark) {
    final thumb = _thumb(d['thumbnail_url']);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen())),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 62, height: 62,
                color: AppTheme.primaryColor.withOpacity(0.12),
                child: thumb.isNotEmpty
                    ? Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_rounded, color: AppTheme.primaryColor))
                    : const Icon(Icons.inventory_2_rounded, color: AppTheme.primaryColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_clean('${d['title'] ?? 'Digital Product'}'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: isDark ? Colors.white : Colors.black87))),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}