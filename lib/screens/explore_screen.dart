import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../widgets/kaida_loader.dart';
import '../widgets/page_header.dart';
import 'catalog_screen.dart';
import 'item_details_screen.dart';
import '../widgets/kaida_empty_state.dart';
import 'categories_screen.dart';

/// Shop: digital and physical products (native screen, uses catalog.php?action=products).
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool _isLoading = true;
  bool _error = false;
  List<CatalogItem> _items = [];
  String _query = '';
  String _category = 'All';
  String _kind = 'All'; // All | Digital | Physical

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = false; });
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/catalog.php?action=products'));
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        if (d['status'] == 'success') {
          _items = (d['data'] as List).map((e) => CatalogItem.fromJson(Map<String, dynamic>.from(e), 'products')).toList();
        } else {
          _error = true;
        }
      } else {
        _error = true;
      }
    } catch (e) {
      _error = true;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _clean(String s) => s
      .replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#039;', "'").replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<').replaceAll('&gt;', '>');

  List<String> get _categories {
    final set = <String>{};
    for (final i in _items) { if (i.categoryName.isNotEmpty) set.add(i.categoryName); }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  List<CatalogItem> get _filtered => _items.where((i) {
        if (_category != 'All' && i.categoryName != _category) return false;
        if (_kind == 'Digital' && i.productType != 'digital') return false;
        if (_kind == 'Physical' && i.productType != 'physical') return false;
        if (_query.isNotEmpty && !i.title.toLowerCase().contains(_query.toLowerCase())) return false;
        return true;
      }).toList();

  void _open(CatalogItem item) => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: item)));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;
    final filtering = _query.isNotEmpty || _category != 'All' || _kind != 'All';
    final digital = filtered.where((i) => i.productType == 'digital').toList();
    final physical = filtered.where((i) => i.productType != 'digital').toList();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : const Color(0xFFF6F5FB),
      body: Column(
        children: [
          PageHeader(
            title: 'Shop',
            subtitle: 'Digital products and physical items',
            showBack: Navigator.of(context).canPop(),
            illustration: Icons.shopping_bag_rounded,
            bottomPadding: 20,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: KaidaLoader())
                : RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.only(bottom: 110),
                      children: [
                        // search + kind
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14.5),
                                  decoration: InputDecoration(
                                    hintText: 'Search for a product...',
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : Colors.white, borderRadius: BorderRadius.circular(16)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _kind,
                                    dropdownColor: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                                    items: const ['All', 'Digital', 'Physical'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                    onChanged: (v) => setState(() => _kind = v ?? 'All'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // categories
                        SizedBox(
                          height: 52,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            itemCount: _categories.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final c = _categories[i];
                              final active = c == _category;
                              return GestureDetector(
                                onTap: () => setState(() => _category = c),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: active ? AppTheme.primaryColor : (isDark ? AppTheme.darkSurfaceColor : Colors.white),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Text(c, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: active ? Colors.white : (isDark ? Colors.white70 : Colors.black87))),
                                ),
                              );
                            },
                          ),
                        ),
                        if (_error)
                          SizedBox(height: MediaQuery.of(context).size.height * 0.6, child: KaidaErrorState(onRetry: _load))
                        else if (filtered.isEmpty)
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: KaidaEmptyState(
                              kind: KaidaEmptyKind.products,
                              primaryLabel: 'Browse products',
                              onPrimary: () => setState(() { _query = ''; _category = 'All'; _kind = 'All'; }),
                              secondaryLabel: 'Browse categories',
                              onSecondary: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
                            ),
                          )
                        else if (filtering) ...[
                          _title('Results (${filtered.length})', isDark),
                          _grid(filtered, isDark),
                        ] else ...[
                          _promo(),
                          if (digital.isNotEmpty) ...[
                            _title('Digital Products', isDark),
                            SizedBox(
                              height: 262,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: digital.length > 12 ? 12 : digital.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (_, i) => SizedBox(width: 170, child: _card(digital[i], isDark)),
                              ),
                            ),
                          ],
                          if (physical.isNotEmpty) ...[
                            _title('Physical Products', isDark),
                            _grid(physical, isDark),
                          ],
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _title(String t, bool isDark) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
        child: Text(t, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
      );

  Widget _promo() {
    Widget pill(IconData icon, String a, String b) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(icon, color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF16123A))),
                Text(b, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
              ])),
            ]),
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4C2FE0), Color(0xFF7B5CFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Digital & Physical', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.1)),
          const Text('Products', style: TextStyle(color: Color(0xFFFFC21A), fontSize: 22, fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 6),
          Text('Ebooks, scripts, templates, devices and more.', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
          const SizedBox(height: 12),
          Row(children: [
            pill(Icons.download_rounded, 'Digital', 'Download after buying'),
            const SizedBox(width: 10),
            pill(Icons.local_shipping_rounded, 'Physical', 'Delivered to you'),
          ]),
        ],
      ),
    );
  }

  Widget _grid(List<CatalogItem> list, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, mainAxisExtent: 262),
        itemBuilder: (_, i) => _card(list[i], isDark),
      ),
    );
  }

  Widget _card(CatalogItem item, bool isDark) {
    final free = item.isFree || (item.price == 0 && item.discountPrice == 0);
    final onSale = item.discountPrice > 0 && item.discountPrice < item.price;
    final digitalItem = item.productType == 'digital';
    return GestureDetector(
      onTap: () => _open(item),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: SizedBox(
                    height: 128, width: double.infinity,
                    child: item.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(imageUrl: item.thumbnailUrl, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: AppTheme.primaryColor.withOpacity(0.12)))
                        : Container(color: AppTheme.primaryColor.withOpacity(0.12), child: Icon(digitalItem ? Icons.download_rounded : Icons.shopping_bag_rounded, size: 40, color: AppTheme.primaryColor)),
                  ),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), shape: BoxShape.circle),
                    child: Icon(digitalItem ? Icons.download_rounded : Icons.local_shipping_rounded, size: 15, color: AppTheme.primaryColor),
                  ),
                ),
                if (item.isOutOfStock)
                  Positioned(
                    left: 8, top: 8,
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)), child: const Text('Sold out', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_clean(item.title), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, height: 1.2, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 3),
                    Text(item.categoryName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: free
                              ? const Text('FREE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 15))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (onSale) Text('₦${item.price.toStringAsFixed(0)}', style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey.shade400, fontSize: 10.5)),
                                    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('₦${(onSale ? item.discountPrice : item.price).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: AppTheme.primaryColor))),
                                  ],
                                ),
                        ),
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(11)),
                          child: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 19),
                        ),
                      ],
                    ),
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