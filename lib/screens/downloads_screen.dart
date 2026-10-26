import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../widgets/kaida_loader.dart';
import '../widgets/page_header.dart';
import '../utils/kaida_alert.dart';
import '../widgets/kaida_empty_state.dart';
import 'explore_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  _DownloadsScreenState createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  bool _isLoading = true;
  List<dynamic> _downloads = [];
  final Set<int> _downloadingItems = {};
  int _tab = 0; // All, Ebooks, Scripts, Templates, Videos
  String _query = '';
  bool _newestFirst = true;

  static const _tabNames = ['All', 'Ebooks', 'Scripts', 'Templates', 'Videos'];

  @override
  void initState() {
    super.initState();
    _fetchDownloads();
  }

  Future<void> _fetchDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final response = await http.post(Uri.parse(ApiConfig.myDownloads), body: {'user_id': userId.toString()});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && mounted) {
          setState(() => _downloads = data['data']);
        }
      }
    } catch (e) {
      debugPrint("API Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startNativeDownload(int orderId, int itemId) async {
    setState(() => _downloadingItems.add(itemId));
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.getDownloadLink),
        body: {'user_id': userId.toString(), 'order_id': orderId.toString(), 'item_id': itemId.toString()},
      );
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        String downloadUrl = data['url'];
        if (!downloadUrl.startsWith('http')) {
          downloadUrl = 'https://academy.kainuwa.africa/' + downloadUrl.replaceFirst(RegExp(r'^/+'), '');
        }
        if (!await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication)) {
          throw Exception('Could not launch downloader');
        }
      } else {
        if (!mounted) return;
        KaidaAlert.showModal(context: context, title: 'Download Error', message: data['message'] ?? 'Error generating link', isError: true);
      }
    } catch (e) {
      debugPrint("Download error: $e");
      if (!mounted) return;
      KaidaAlert.showModal(context: context, title: 'Download Failed', message: 'Failed to initiate download. Please check your connection.', isError: true);
    } finally {
      if (mounted) setState(() => _downloadingItems.remove(itemId));
    }
  }

  // ---- classification by file extension ----
  String _kind(dynamic d) {
    final ext = (d['file_ext']?.toString() ?? '').toLowerCase();
    if (['pdf', 'epub', 'mobi', 'doc', 'docx', 'txt'].contains(ext)) return 'Ebooks';
    if (['zip', 'rar', '7z', 'php', 'js', 'py', 'sql', 'sh', 'apk'].contains(ext)) return 'Scripts';
    if (['psd', 'ai', 'fig', 'xd', 'ppt', 'pptx', 'xls', 'xlsx', 'csv', 'html', 'dotx', 'xltx', 'potx'].contains(ext)) return 'Templates';
    if (['mp4', 'mkv', 'mov', 'avi', 'webm'].contains(ext)) return 'Videos';
    return 'Other';
  }

  (IconData, Color) _kindLook(String kind) {
    switch (kind) {
      case 'Ebooks': return (Icons.menu_book_rounded, const Color(0xFFEF4466));
      case 'Scripts': return (Icons.code_rounded, const Color(0xFF2F80ED));
      case 'Templates': return (Icons.dashboard_customize_rounded, const Color(0xFFF2711C));
      case 'Videos': return (Icons.play_circle_fill_rounded, const Color(0xFF7351FF));
      default: return (Icons.inventory_2_rounded, const Color(0xFF22A06B));
    }
  }

  int _count(int tab) => tab == 0 ? _downloads.length : _downloads.where((d) => _kind(d) == _tabNames[tab]).length;

  List<dynamic> get _visible {
    var list = _downloads.where((d) {
      if (_tab != 0 && _kind(d) != _tabNames[_tab]) return false;
      if (_query.isNotEmpty && !'${d['title'] ?? ''}'.toLowerCase().contains(_query.toLowerCase())) return false;
      return true;
    }).toList();
    if (!_newestFirst) list = list.reversed.toList(); // API returns newest first
    return list;
  }

  String _size(dynamic bytes) {
    final b = int.tryParse('${bytes ?? ''}');
    if (b == null || b <= 0) return '';
    if (b >= 1024 * 1024 * 1024) return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(b / 1024).ceil()} KB';
  }

  String _date(dynamic ts) {
    final dt = DateTime.tryParse('${ts ?? ''}'.replaceFirst(' ', 'T'));
    if (dt == null) return '';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String get _totalSize {
    int total = 0;
    for (final d in _downloads) { total += int.tryParse('${d['file_size'] ?? 0}') ?? 0; }
    return total > 0 ? _size(total) : '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labels = [for (int i = 0; i < _tabNames.length; i++) '${_tabNames[i]} (${_count(i)})'];
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : const Color(0xFFF6F5FB),
      body: Column(
        children: [
          PageHeader(
            title: 'Downloads',
            subtitle: 'Your purchased files, ready to use',
            illustration: Icons.folder_rounded,
            bottom: HeaderTabs(labels: labels, selected: _tab, onChanged: (i) => setState(() => _tab = i)),
            bottomPadding: 16,
          ),
          Expanded(
            child: _isLoading
                ? const KaidaSkeletonList()
                : RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: _fetchDownloads,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14.5),
                                decoration: InputDecoration(
                                  hintText: 'Search downloads...',
                                  hintStyle: TextStyle(color: Colors.grey.shade500),
                                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500),
                                  filled: true,
                                  fillColor: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                ),
                                onChanged: (v) => setState(() => _query = v),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => setState(() => _newestFirst = !_newestFirst),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : Colors.white, borderRadius: BorderRadius.circular(16)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.swap_vert_rounded, color: AppTheme.primaryColor, size: 20),
                                    const SizedBox(width: 4),
                                    Text(_newestFirst ? 'Newest' : 'Oldest', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: isDark ? Colors.white : Colors.black87)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_visible.isEmpty)
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: KaidaEmptyState(
                              kind: _downloads.isEmpty ? KaidaEmptyKind.downloads : KaidaEmptyKind.search,
                              primaryLabel: _downloads.isEmpty ? 'Browse products' : null,
                              onPrimary: _downloads.isEmpty ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExploreScreen())) : null,
                            ),
                          )
                        else
                          ..._visible.map((d) => _item(d, isDark)),
                        if (_downloads.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _summary(isDark),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summary(bool isDark) {
    final size = _totalSize;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : const Color(0xFFF0EDFF), borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          const Icon(Icons.cloud_download_rounded, color: AppTheme.primaryColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_downloads.length} file${_downloads.length == 1 ? '' : 's'}${size.isNotEmpty ? ' · $size in total' : ''}',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(dynamic item, bool isDark) {
    String rawThumb = item['thumbnail_url']?.toString() ?? '';
    if (rawThumb.isNotEmpty && !rawThumb.startsWith('http')) {
      rawThumb = 'https://academy.kainuwa.africa/' + rawThumb.replaceFirst(RegExp(r'^/+'), '');
    }
    final orderId = int.tryParse(item['order_id']?.toString() ?? '0') ?? 0;
    final itemId = int.tryParse(item['item_id']?.toString() ?? '0') ?? 0;
    final busy = _downloadingItems.contains(itemId);
    final kind = _kind(item);
    final look = _kindLook(kind);
    final size = _size(item['file_size']);
    final date = _date(item['purchased_at']);
    final ext = (item['file_ext']?.toString() ?? '').toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: rawThumb.isNotEmpty
                ? Image.network(rawThumb, width: 62, height: 62, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _thumbFallback(look))
                : _thumbFallback(look),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'] ?? 'Digital Product', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.2, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: look.$2.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
                      child: Text(ext.isNotEmpty ? ext : kind, style: TextStyle(color: look.$2, fontSize: 10.5, fontWeight: FontWeight.w900)),
                    ),
                    if (size.isNotEmpty) Text(size, style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    if (date.isNotEmpty) Text(date, style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed: (busy || orderId == 0) ? null : () => _startNativeDownload(orderId, itemId),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.5),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: busy
                  ? const KaidaSmallSpinner(size: 18, color: Colors.white)
                  : const Icon(Icons.download_rounded, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbFallback((IconData, Color) look) {
    return Container(width: 62, height: 62, color: look.$2.withOpacity(0.14), child: Icon(look.$1, color: look.$2, size: 28));
  }
}