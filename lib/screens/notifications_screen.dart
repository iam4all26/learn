import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../widgets/kaida_loader.dart';
import '../widgets/page_header.dart';
import '../utils/kaida_alert.dart';
import 'course_player_screen.dart';
import 'main_layout.dart';
import 'catalog_screen.dart'; 
import 'item_details_screen.dart'; 
import '../widgets/kaida_empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<dynamic> _groupedItems = []; 
  List<dynamic> _rawNotifications = [];
  int? _userId;
  int _tab = 0; // 0 All, 1 Courses, 2 KAIDA Points, 3 Announcements

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');
    
    if (_userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      String apiUrl = '${ApiConfig.baseUrl}/notifications_api.php'.replaceAll('//notifications_api', '/notifications_api');
      final response = await http.post(Uri.parse(apiUrl), body: {'action': 'get', 'user_id': _userId.toString()});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && mounted) {
          _rawNotifications = data['data'];
          _processNotifications(_visible());
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper to ensure UTC parsing for Database Timestamps
  DateTime _parseToLocalTime(String timestamp) {
    if (timestamp.isEmpty) return DateTime.now();
    String tStr = timestamp;
    if (!tStr.endsWith('Z')) tStr += 'Z'; // Force UTC interpretation
    return DateTime.tryParse(tStr)?.toLocal() ?? DateTime.now();
  }

  void _processNotifications(List<dynamic> data) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));

    List<dynamic> todayList = [];
    List<dynamic> yesterdayList = [];
    List<dynamic> lastWeekList = [];
    List<dynamic> olderList = [];

    for (var notif in data) {
      DateTime dt = _parseToLocalTime(notif['created_at']?.toString() ?? '');
      DateTime date = DateTime(dt.year, dt.month, dt.day);

      if (date == today) {
        todayList.add(notif);
      } else if (date == yesterday) {
        yesterdayList.add(notif);
      } else if (date.isAfter(lastWeek)) {
        lastWeekList.add(notif);
      } else {
        olderList.add(notif);
      }
    }

    List<dynamic> grouped = [];
    if (todayList.isNotEmpty) { grouped.add({'is_header': true, 'title': 'Today'}); grouped.addAll(todayList); }
    if (yesterdayList.isNotEmpty) { grouped.add({'is_header': true, 'title': 'Yesterday'}); grouped.addAll(yesterdayList); }
    if (lastWeekList.isNotEmpty) { grouped.add({'is_header': true, 'title': 'This Week'}); grouped.addAll(lastWeekList); }
    if (olderList.isNotEmpty) { grouped.add({'is_header': true, 'title': 'Earlier'}); grouped.addAll(olderList); }

    setState(() {
      _groupedItems = grouped;
      _isLoading = false;
    });
  }

  Future<void> _markAsReadAndRoute(Map<String, dynamic> notif, {Map? ref}) async {
    if (_userId == null) return;
    
    int notifId = int.tryParse(notif['id'].toString()) ?? 0;
    bool isRead = notif['is_read'] == 1 || notif['is_read'] == '1';

    if (!isRead) {
      setState(() { notif['is_read'] = 1; if (ref != null) ref['is_read'] = 1; });
      String apiUrl = '${ApiConfig.baseUrl}/notifications_api.php'.replaceAll('//notifications_api', '/notifications_api');
      http.post(Uri.parse(apiUrl), body: {'action': 'mark_read', 'user_id': _userId.toString(), 'notification_id': notifId.toString()});
    }

    String actionType = notif['action_type']?.toString() ?? 'open_app';
    
    if (actionType == 'open_course') {
      int courseId = int.tryParse(notif['course_id']?.toString() ?? '0') ?? 0;
      if (courseId > 0) {
        // CRITICAL FIX: Use course_title from API instead of the notification header title
        CatalogItem dummy = CatalogItem(
          id: courseId, 
          title: notif['course_title']?.toString() ?? notif['title'] ?? 'Course', 
          slug: notif['course_slug']?.toString() ?? '', 
          thumbnailUrl: notif['course_thumbnail']?.toString() ?? notif['image_url']?.toString() ?? '', 
          price: double.tryParse(notif['course_price']?.toString() ?? '0') ?? 0.0, discountPrice: double.tryParse(notif['course_discount_price']?.toString() ?? '0') ?? 0.0, isFree: notif['course_is_free']?.toString() == '1', instructorName: 'Loading...', 
          categoryName: 'Course', language: 'EN', type: 'courses', productType: 'digital'
        ); 
        Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: dummy)));
      }
    } else if (actionType == 'open_dashboard') {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 5)), (route) => false);
    } else if (actionType == 'open_store') {
      final url = Uri.parse("market://details?id=com.kainuwa.academy"); 
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _markAllAsRead() async {
    if (_userId == null || _rawNotifications.isEmpty) return;
    setState(() { for (var n in _rawNotifications) { n['is_read'] = 1; } });
    try {
      String apiUrl = '${ApiConfig.baseUrl}/notifications_api.php'.replaceAll('//notifications_api', '/notifications_api');
      await http.post(Uri.parse(apiUrl), body: {'action': 'mark_all_read', 'user_id': _userId.toString()});
      KaidaAlert.showModal(context: context, title: 'Cleared', message: 'All notifications marked as read.', isError: false);
    } catch (e) {}
  }

  String _formatTime(String timestamp) {
    if (timestamp.isEmpty) return 'Now';
    DateTime dt = _parseToLocalTime(timestamp);
    Duration diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inMinutes < 1) return 'Now';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    return '${diff.inMinutes}m';
  }

  // ---- Categories and per-type look ----
  String _text(dynamic n) => '${n['title'] ?? ''} ${n['message'] ?? ''}'.toLowerCase();

  // 'courses', 'points' or 'announcements'. No category column exists in the database,
  // so it is worked out from the action type and the wording.
  String _categoryOf(dynamic n) {
    final t = _text(n);
    final action = n['action_type']?.toString() ?? '';
    if (RegExp(r'kaida|point|token|wallet|coin|reward|bonus|earn').hasMatch(t)) return 'points';
    final cid = int.tryParse(n['course_id']?.toString() ?? '0') ?? 0;
    if (action == 'open_course' || cid > 0 || RegExp(r'course|lesson|enrol|certificate|quiz|assignment').hasMatch(t)) return 'courses';
    return 'announcements';
  }

  List<dynamic> _visible() {
    if (_tab == 0) return _rawNotifications;
    const keys = ['', 'courses', 'points', 'announcements'];
    return _rawNotifications.where((n) => _categoryOf(n) == keys[_tab]).toList();
  }

  int _count(int tab) {
    if (tab == 0) return _rawNotifications.length;
    const keys = ['', 'courses', 'points', 'announcements'];
    return _rawNotifications.where((n) => _categoryOf(n) == keys[tab]).length;
  }

  // icon + colour for one notification
  (IconData, Color) _look(dynamic n) {
    final t = _text(n);
    if (RegExp(r'certificate').hasMatch(t)) return (Icons.workspace_premium_rounded, const Color(0xFFF2711C));
    if (RegExp(r'warning|expir|failed|declin|reject|suspend|alert|reminder|overdue').hasMatch(t)) return (Icons.warning_amber_rounded, const Color(0xFFEF4444));
    if (RegExp(r'gift|bonus|reward|free').hasMatch(t)) return (Icons.card_giftcard_rounded, const Color(0xFFE5489B));
    if (RegExp(r'kaida|point|token|wallet|coin|earn').hasMatch(t)) return (Icons.monetization_on_rounded, const Color(0xFFFFB020));
    if (RegExp(r'complet|congrat|success|approved|verified|welcome').hasMatch(t)) return (Icons.check_circle_rounded, const Color(0xFF22A06B));
    final cat = _categoryOf(n);
    if (cat == 'courses') return (Icons.school_rounded, const Color(0xFF7351FF));
    return (Icons.campaign_rounded, const Color(0xFF2F80ED));
  }

  void _setTab(int i) {
    _tab = i;
    _processNotifications(_visible());
  }

  int get _unread => _rawNotifications.where((n) => !(n['is_read'] == 1 || n['is_read'] == '1')).length;

  Widget _notifCard(Map notif, bool isDark) {
    final isRead = notif['is_read'] == 1 || notif['is_read'] == '1';
    final look = _look(notif);
    final imageUrl = notif['image_url']?.toString() ?? '';
    return GestureDetector(
      onTap: () => _markAsReadAndRoute(Map<String, dynamic>.from(notif), ref: notif),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: look.$2.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(borderRadius: BorderRadius.circular(14), child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, errorWidget: (_, __, ___) => Icon(look.$1, color: look.$2, size: 25)))
                  : Icon(look.$1, color: look.$2, size: 25),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(_decode('${notif['title'] ?? 'Notification'}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: isRead ? FontWeight.w700 : FontWeight.w900, fontSize: 14.5, color: isDark ? Colors.white : Colors.black87))),
                      const SizedBox(width: 6),
                      Text(_formatTime(notif['created_at']?.toString() ?? ''), style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(_decode('${notif['message'] ?? ''}'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isRead ? Colors.grey.shade500 : (isDark ? Colors.grey.shade300 : Colors.black54), fontSize: 13, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              children: [
                if (!isRead) Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFF7351FF), shape: BoxShape.circle)) else const SizedBox(height: 9),
                const SizedBox(height: 6),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _decode(String s) => s
      .replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#039;', "'").replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<').replaceAll('&gt;', '>');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabLabels = [
      'All (${_count(0)})', 'Courses (${_count(1)})', 'KAIDA Points (${_count(2)})', 'Announcements (${_count(3)})',
    ];

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : const Color(0xFFF6F5FB),
      body: Column(
        children: [
          PageHeader(
            title: 'Notifications',
            subtitle: _unread > 0 ? 'You have $_unread unread' : 'Stay updated with everything important',
            illustration: Icons.notifications_active_rounded,
            actions: [
              if (_rawNotifications.isNotEmpty) PageHeader.circleButton(Icons.done_all_rounded, _markAllAsRead),
            ],
            bottom: HeaderTabs(labels: tabLabels, selected: _tab, onChanged: _setTab),
            bottomPadding: 16,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: KaidaLoader())
                : RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: _fetchNotifications,
                    child: _groupedItems.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.6,
                                child: const KaidaEmptyState(kind: KaidaEmptyKind.notifications),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 30),
                            itemCount: _groupedItems.length,
                            itemBuilder: (context, index) {
                              final item = _groupedItems[index];
                              if (item is Map && item.containsKey('is_header')) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                                  child: Text(item['title'].toString(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                                );
                              }
                              return _notifCard(item as Map, isDark);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}