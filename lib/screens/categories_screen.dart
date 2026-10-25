import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../widgets/kaida_loader.dart';
import 'catalog_screen.dart';
import '../widgets/kaida_empty_state.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  @override
  _CategoriesScreenState createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _isLoading = true;
  List<dynamic> _categories = [];

  static const List<Color> _tileColors = [
    Color(0xFF7351FF), Color(0xFFFFB020), Color(0xFFEF4444), Color(0xFF2F80ED),
    Color(0xFF22C55E), Color(0xFFF97316), Color(0xFFEC4899), Color(0xFF06B6D4),
  ];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.categories));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && mounted) {
          setState(() {
            _categories = data['data'];
          });
        }
      }
    } catch (e) {
      debugPrint("Categories Fetch Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getIconForCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('web') || n.contains('cod') || n.contains('program') || n.contains('develop') || n.contains('tech')) return Icons.code_rounded;
    if (n.contains('design') || n.contains('graphic') || n.contains('art') || n.contains('canva')) return Icons.palette_rounded;
    if (n.contains('video') || n.contains('youtube') || n.contains('content') || n.contains('edit')) return Icons.play_circle_fill_rounded;
    if (n.contains('crypto') || n.contains('block') || n.contains('forex') || n.contains('trad') || n.contains('financ')) return Icons.attach_money_rounded;
    if (n.contains('market') || n.contains('social') || n.contains('seo') || n.contains('advert')) return Icons.campaign_rounded;
    if (n.contains('business') || n.contains('entrepren') || n.contains('sales')) return Icons.business_center_rounded;
    if (n.contains('ai') || n.contains('smart') || n.contains('phone') || n.contains('mobile')) return Icons.auto_awesome_rounded;
    if (n.contains('photo') || n.contains('camera')) return Icons.photo_camera_rounded;
    if (n.contains('health')) return Icons.favorite_rounded;
    if (n.contains('music') || n.contains('audio')) return Icons.music_note_rounded;
    if (n.contains('language') || n.contains('english') || n.contains('hausa')) return Icons.translate_rounded;
    return Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('All Categories', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: KaidaLoader())
          : _categories.isEmpty
              ? const KaidaEmptyState(kind: KaidaEmptyKind.generic, title: 'No categories yet', message: 'Categories will appear here soon.')
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final catName = (cat['name'] ?? 'Category').toString();
                    final color = _tileColors[index % _tileColors.length];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CatalogScreen(
                          actionType: 'category_${cat['id']}',
                          title: catName,
                        )));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(isDark ? 0.18 : 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withOpacity(0.25)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 5))],
                              ),
                              child: Icon(_getIconForCategory(catName), color: Colors.white, size: 26),
                            ),
                            const SizedBox(height: 10),
                            Text(catName, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.2)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}