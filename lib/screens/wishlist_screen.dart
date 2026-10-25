import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../widgets/kaida_loader.dart';
import '../widgets/page_header.dart';
import 'catalog_screen.dart';
import 'item_details_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({Key? key}) : super(key: key);

  @override
  _WishlistScreenState createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  bool _isLoading = true;
  List<CatalogItem> _wishlistedItems = [];
  int? _userId;
  int _tab = 0; // 0 All, 1 Courses, 2 Products

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
  }

  Future<void> _fetchWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');
    
    if (_userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.post(Uri.parse(ApiConfig.getWishlist), body: {'user_id': _userId.toString()});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          List<dynamic> list = data['data'];
          List<CatalogItem> parsedList = [];
          for (var item in list) {
            String iType = item['item_type'] == 'product' ? 'products' : 'courses';
            try { parsedList.add(CatalogItem.fromJson(item, iType)); } catch (e) {}
          }
          if (mounted) {
            setState(() {
              _wishlistedItems = parsedList;
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFromWishlist(int itemId, String type) async {
    if (_userId == null) return;

    setState(() {
      _wishlistedItems.removeWhere((item) => item.id == itemId);
    });

    try {
      await http.post(
        Uri.parse(ApiConfig.toggleWishlist),
        body: {'user_id': _userId.toString(), 'item_id': itemId.toString(), 'item_type': type == 'products' ? 'product' : 'course'}
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from wishlist'), duration: Duration(seconds: 1)));
    } catch (e) {
      _fetchWishlist(); 
    }
  }

  List<CatalogItem> get _visible {
    if (_tab == 1) return _wishlistedItems.where((i) => !i.type.contains('products')).toList();
    if (_tab == 2) return _wishlistedItems.where((i) => i.type.contains('products')).toList();
    return _wishlistedItems;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final courses = _wishlistedItems.where((i) => !i.type.contains('products')).length;
    final products = _wishlistedItems.length - courses;
    final shown = _visible;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : const Color(0xFFF6F5FB),
      body: Column(
        children: [
          PageHeader(
            title: 'My Wishlist',
            subtitle: _wishlistedItems.isEmpty ? 'Save courses and products you like' : '${_wishlistedItems.length} saved item${_wishlistedItems.length == 1 ? '' : 's'}',
            illustration: Icons.favorite_rounded,
            bottom: HeaderTabs(
              labels: ['All (${_wishlistedItems.length})', 'Courses ($courses)', 'Products ($products)'],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            bottomPadding: 16,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: KaidaLoader())
                : RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: _fetchWishlist,
                    child: shown.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 90),
                              Icon(Icons.favorite_outline_rounded, size: 80, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Center(child: Text('Wishlist Empty', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))),
                              const SizedBox(height: 8),
                              Center(child: Text('Items you favorite will appear here.', style: TextStyle(color: Colors.grey.shade500))),
                            ],
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                            physics: const AlwaysScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 16,
                              mainAxisExtent: 260,
                            ),
                            itemCount: shown.length,
                            itemBuilder: (context, index) => _buildGridCard(shown[index], isDark),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(CatalogItem item, bool isDark) {
    int discountPercent = 0;
    if (item.price > 0 && item.discountPrice > 0 && item.discountPrice < item.price) {
      discountPercent = (((item.price - item.discountPrice) / item.price) * 100).round();
    }
    
    bool isProductMode = item.type.contains('products');

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailsScreen(item: item))).then((_) => _fetchWishlist()),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100),
          boxShadow: [BoxShadow(color: isDark ? Colors.black12 : Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: item.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: item.thumbnailUrl, height: 110, width: double.infinity, fit: BoxFit.cover)
                      : Container(height: 110, color: AppTheme.primaryColor.withOpacity(0.2), child: Icon(isProductMode ? Icons.shopping_bag_rounded : Icons.school_rounded, size: 40, color: AppTheme.primaryColor)),
                ),
                if (discountPercent > 0 && !item.isComingSoon)
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                      child: Text('-$discountPercent%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                Positioned(
                  top: 6, right: 6,
                  child: GestureDetector(
                    onTap: () => _removeFromWishlist(item.id, item.type),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                      child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 16),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(item.categoryName.toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5), overflow: TextOverflow.ellipsis)),
                        if (!isProductMode)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(item.language.toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(isProductMode ? Icons.store_rounded : Icons.person_rounded, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(child: Text(isProductMode ? (item.productType.toUpperCase()) : item.instructorName, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const Spacer(),
                    if (item.isFree || (item.price == 0 && item.discountPrice == 0))
                      const Text('FREE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14))
                    else if (item.discountPrice > 0 && item.discountPrice < item.price)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₦${item.discountPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.primaryColor)),
                        ],
                      )
                    else
                      Text('₦${item.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.primaryColor)),
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