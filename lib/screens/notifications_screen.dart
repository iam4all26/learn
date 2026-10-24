import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../widgets/kaida_loader.dart';
import '../utils/kaida_alert.dart';
import 'course_player_screen.dart';
import 'main_layout.dart';
import 'catalog_screen.dart'; 
import 'item_details_screen.dart'; 

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
          _processNotifications(_rawNotifications);
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
    if (lastWeekList.isNotEmpty) { grouped.add({'is_header': true, 'title': 'Last 7 Days'}); grouped.addAll(lastWeekList); }
    if (olderList.isNotEmpty) { grouped.add({'is_header': true, 'title': 'Older'}); grouped.addAll(olderList); }

    setState(() {
      _groupedItems = grouped;
      _isLoading = false;
    });
  }

  Future<void> _markAsReadAndRoute(Map<String, dynamic> notif) async {
    if (_userId == null) return;
    
    int notifId = int.tryParse(notif['id'].toString()) ?? 0;
    bool isRead = notif['is_read'] == 1 || notif['is_read'] == '1';

    if (!isRead) {
      setState(() { notif['is_read'] = 1; });
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black, size: 20), onPressed: () => Navigator.pop(context, true)),
        title: Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        actions: [
          if (_rawNotifications.isNotEmpty)
            IconButton(icon: Icon(Icons.done_all_rounded, color: AppTheme.primaryColor, size: 24), onPressed: _markAllAsRead, tooltip: 'Mark all as read'),
        ],
      ),
      body: _isLoading 
        ? const Center(child: KaidaLoader())
        : _groupedItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_rounded, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('All Caught Up!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 8),
                  Text('You have no new notifications.', style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _fetchNotifications,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _groupedItems.length,
                itemBuilder: (context, index) {
                  final item = _groupedItems[index];

                  if (item is Map && item.containsKey('is_header')) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Text(
                        item['title'].toString().toUpperCase(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, letterSpacing: 1.2),
                      ),
                    );
                  }

                  final notif = item;
                  bool isRead = notif['is_read'] == 1 || notif['is_read'] == '1';
                  String imageUrl = notif['image_url']?.toString() ?? '';

                  return InkWell(
                    onTap: () => _markAsReadAndRoute(notif),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: isRead ? Colors.transparent : (isDark ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.05)),
                        border: Border(bottom: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100, width: 1)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              color: isRead ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200) : AppTheme.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: imageUrl.isNotEmpty
                              ? ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover))
                              : Icon(Icons.notifications_active_rounded, color: isRead ? Colors.grey : AppTheme.primaryColor, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(notif['title'] ?? 'Notification', style: TextStyle(fontWeight: isRead ? FontWeight.w600 : FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : Colors.black87))),
                                    if (!isRead) Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 8), decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(notif['message'] ?? '', style: TextStyle(color: isRead ? Colors.grey.shade500 : (isDark ? Colors.grey.shade300 : Colors.black54), fontSize: 14, height: 1.4)),
                                const SizedBox(height: 8),
                                Text(_formatTime(notif['created_at']?.toString() ?? ''), style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}