import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../widgets/kaida_loader.dart';
import '../utils/kaida_alert.dart';
import 'item_details_screen.dart';
import '../widgets/kaida_empty_state.dart';
import 'categories_screen.dart';
import '../widgets/star_rating.dart';
import '../utils/category_style.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class CatalogItem {
  final int id;
  final String title;
  final String slug;
  final String thumbnailUrl;
  final double price;
  final double discountPrice;
  final bool isFree;
  final String instructorName;
  final String categoryName;
  final String language;
  final String type;
  final String productType;
  final bool isComingSoon;
  final bool isOutOfStock; // CRITICAL FIX 2: Inventory Tracking
  final int lessonCount;
  final double avgRating;
  final int categoryId;
  final int sectionCount;
  final int reviewCount;
  final String shortDesc;

  CatalogItem({
    required this.id,
    required this.title,
    required this.slug,
    required this.thumbnailUrl,
    required this.price,
    required this.discountPrice,
    required this.isFree,
    required this.instructorName,
    required this.categoryName,
    required this.language,
    required this.type,
    required this.productType,
    this.isComingSoon = false,
    this.isOutOfStock = false,
    this.lessonCount = 0,
    this.avgRating = 0,
    this.categoryId = 0,
    this.sectionCount = 0,
    this.reviewCount = 0,
    this.shortDesc = '',
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json, String itemType) {
    bool comingSoon = false;
    bool outOfStock = false;
    
    if (itemType == 'courses' && json.containsKey('release_date') && json['release_date'] != null) {
      DateTime? release = DateTime.tryParse(json['release_date'].toString());
      if (release != null && release.isAfter(DateTime.now())) comingSoon = true;
    }

    String pType = json['product_type'] ?? 'digital';
    if (itemType.contains('products') && pType == 'physical') {
      int qty = int.tryParse(json['stock_quantity']?.toString() ?? '1') ?? 1;
      if (qty <= 0) outOfStock = true;
    }

    return CatalogItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] ?? json['name'] ?? 'Untitled',
      slug: json['slug'] ?? '',
      thumbnailUrl: json['thumbnail_url'] != null && json['thumbnail_url'].toString().isNotEmpty
          ? (json['thumbnail_url'].toString().startsWith('http') ? json['thumbnail_url'] : 'https://academy.kainuwa.africa/${json['thumbnail_url']}')
          : (json['thumbnail_path'] != null && json['thumbnail_path'].toString().isNotEmpty 
              ? (json['thumbnail_path'].toString().startsWith('http') ? json['thumbnail_path'] : 'https://academy.kainuwa.africa/${json['thumbnail_path']}')
              : ''),
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      discountPrice: double.tryParse(json['discount_price'].toString()) ?? 0.0,
      isFree: json['is_free'] == 1 || json['is_free'] == true || json['is_free'] == '1',
      instructorName: json['instructor_name'] ?? json['author_name'] ?? 'Kainuwa',
      categoryName: json['category_name'] ?? 'General',
      language: json['language'] ?? 'EN',
      type: itemType,
      productType: pType,
      isComingSoon: comingSoon,
      isOutOfStock: outOfStock,
      lessonCount: int.tryParse(json['lesson_count']?.toString() ?? '') ?? 0,
      avgRating: double.tryParse(json['avg_rating']?.toString() ?? '') ?? 0,
      categoryId: int.tryParse(json['category_id']?.toString() ?? '') ?? 0,
      sectionCount: int.tryParse(json['section_count']?.toString() ?? '') ?? 0,
      reviewCount: int.tryParse(json['review_count']?.toString() ?? '') ?? 0,
      shortDesc: (json['short_desc'] ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'&[a-z]+;'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
  }
}

class CatalogScreen extends StatefulWidget {
  final String actionType;
  final String title;
  const CatalogScreen({Key? key, required this.actionType, required this.title}) : super(key: key);
  @override
  _CatalogScreenState createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  bool _isLoading = true;
  List<CatalogItem> _allItems = [];
  List<CatalogItem> _filteredItems = [];
  Set<int> _wishlistedCourseIds = {};
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'All';
  String _selectedLevel = 'All';
  String _chip = 'All'; // All | Popular | New | Free | Sale
  String _selectedProductType = 'All'; 
  RangeValues _priceRange = const RangeValues(0, 100000);

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
    _fetchCatalog();
    _searchController.addListener(_filterResults);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                .where((item) => item['item_type'] == (widget.actionType.contains('products') ? 'product' : 'course'))
                .map<int>((item) => int.tryParse((item['item_id'] ?? item['id']).toString()) ?? 0)
                .toSet();
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _toggleWishlist(int itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      KaidaAlert.showModal(context: context, title: 'Authentication Required', message: 'Please log in to save items.', isError: true);
      return;
    }

    final isCurrentlyWishlisted = _wishlistedCourseIds.contains(itemId);
    final itemType = widget.actionType.contains('products') ? 'product' : 'course';
    
    setState(() {
      if (isCurrentlyWishlisted) _wishlistedCourseIds.remove(itemId);
      else _wishlistedCourseIds.add(itemId);
    });

    try {
      final response = await http.post(Uri.parse(ApiConfig.toggleWishlist), body: {'user_id': userId.toString(), 'item_id': itemId.toString(), 'item_type': itemType});
      final data = json.decode(response.body);
      if (data['status'] != 'success') {
        setState(() {
          if (isCurrentlyWishlisted) _wishlistedCourseIds.add(itemId);
          else _wishlistedCourseIds.remove(itemId);
        });
      }
    } catch (e) {
      setState(() {
        if (isCurrentlyWishlisted) _wishlistedCourseIds.add(itemId);
        else _wishlistedCourseIds.remove(itemId);
      });
    }
  }

  Future<void> _fetchCatalog() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/catalog.php?action=${widget.actionType}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          List<dynamic> list = data['data'];
          List<CatalogItem> parsedList = [];
          for (var item in list) {
            try {
              parsedList.add(CatalogItem.fromJson(item, widget.actionType.contains('products') ? 'products' : 'courses'));
            } catch (e) {}
          }
          if (mounted) {
            setState(() {
              _allItems = parsedList;
              _filterResults();
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterResults() {
    String query = _searchController.text.toLowerCase();
    bool isProductMode = widget.actionType.contains('products');
    
    setState(() {
      _filteredItems = _allItems.where((item) {
        bool matchesSearch = item.title.toLowerCase().contains(query) || item.categoryName.toLowerCase().contains(query);
        bool matchesCategory = _selectedCategory == 'All' || item.categoryName == _selectedCategory;
        bool matchesPrice = item.price >= _priceRange.start && item.price <= _priceRange.end;
        bool matchesProductType = !isProductMode || _selectedProductType == 'All' || item.productType.toLowerCase() == _selectedProductType.toLowerCase();
        
        return matchesSearch && matchesCategory && matchesPrice && matchesProductType;
      }).toList();
      
      _filteredItems.sort((a, b) {
        if (a.isComingSoon == b.isComingSoon) return 0;
        return a.isComingSoon ? 1 : -1;
      });

      if (!isProductMode) {
        if (_chip == 'New') {
          _filteredItems = _filteredItems.where((i) => !i.isComingSoon).take(12).toList();
        } else if (_chip == 'Popular') {
          _filteredItems.sort((a, b) => b.avgRating.compareTo(a.avgRating));
        } else if (_chip == 'Free') {
          _filteredItems = _filteredItems.where((i) => i.isFree || (i.price == 0 && i.discountPrice == 0)).toList();
        } else if (_chip == 'Sale') {
          _filteredItems = _filteredItems.where((i) => i.discountPrice > 0 && i.discountPrice < i.price).toList();
        }
      }
    });
  }

  void _showFilterModal(bool isDark) {
    bool isProductMode = widget.actionType.contains('products'); 
    List<String> categories = isProductMode 
        ? ['All', 'E-Books', 'Software', 'Apparel', 'Hardware', 'Templates'] 
        : ['All', 'Design', 'Coding', 'Business', 'Marketing'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * (isProductMode ? 0.7 : 0.85),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBackgroundColor : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                    const Text('Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedCategory = 'All';
                          _selectedLevel = 'All';
                          _selectedProductType = 'All';
                          _priceRange = const RangeValues(0, 100000);
                        });
                        setState(() {
                          _selectedCategory = 'All';
                          _selectedLevel = 'All';
                          _selectedProductType = 'All';
                          _priceRange = const RangeValues(0, 100000);
                          _filterResults();
                        });
                      },
                      child: const Text('Reset', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: categories.map((cat) {
                            bool isSelected = _selectedCategory == cat;
                            return ChoiceChip(
                              label: Text(cat, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black))),
                              selected: isSelected,
                              showCheckmark: false, 
                              selectedColor: AppTheme.primaryColor,
                              backgroundColor: isDark ? AppTheme.darkSurfaceColor : Colors.grey.shade100,
                              onSelected: (val) => setModalState(() => _selectedCategory = cat),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.transparent)),
                            );
                          }).toList(),
                        ),
                        
                        if (isProductMode) ...[
                          const SizedBox(height: 24),
                          const Text('Product Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: ['All', 'Digital', 'Physical'].map((type) {
                              bool isSelected = _selectedProductType == type;
                              return ChoiceChip(
                                label: Text(type, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black))),
                                selected: isSelected,
                                showCheckmark: false,
                                selectedColor: AppTheme.primaryColor,
                                backgroundColor: isDark ? AppTheme.darkSurfaceColor : Colors.grey.shade100,
                                onSelected: (val) => setModalState(() => _selectedProductType = type),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.transparent)),
                              );
                            }).toList(),
                          ),
                        ],
                        
                        if (!isProductMode) ...[
                          const SizedBox(height: 24),
                          const Text('Level', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: ['All', 'Beginner', 'Intermediate', 'Expert'].map((level) {
                              bool isSelected = _selectedLevel == level;
                              return ChoiceChip(
                                label: Text(level, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black))),
                                selected: isSelected,
                                showCheckmark: false,
                                selectedColor: AppTheme.primaryColor,
                                backgroundColor: isDark ? AppTheme.darkSurfaceColor : Colors.grey.shade100,
                                onSelected: (val) => setModalState(() => _selectedLevel = level),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.transparent)),
                              );
                            }).toList(),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        const Text('Price Range', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        RangeSlider(
                          values: _priceRange,
                          min: 0, max: 100000,
                          activeColor: AppTheme.primaryColor,
                          inactiveColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          labels: RangeLabels('₦${_priceRange.start.round()}', '₦${_priceRange.end.round()}'),
                          onChanged: (val) => setModalState(() => _priceRange = val),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('₦${_priceRange.start.round()}', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                            Text('₦${_priceRange.end.round()}', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () { _filterResults(); Navigator.pop(context); },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
                    child: const Text('Apply Filter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actionType.contains('products')) return _buildLegacy(context);
    return _buildCourses(context);
  }

  Widget _buildLegacy(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isProductMode = widget.actionType.contains('products');

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: true, 
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text(widget.title, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: isProductMode ? 'Search products...' : 'Search for courses...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500),
                        suffixIcon: _searchController.text.isNotEmpty 
                            ? IconButton(icon: Icon(Icons.close_rounded, color: Colors.grey.shade500), onPressed: () => _searchController.clear())
                            : null,
                        filled: true,
                        fillColor: isDark ? AppTheme.darkSurfaceColor : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _showFilterModal(isDark),
                    child: Container(
                      height: 48, width: 48,
                      decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.tune_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: _isLoading 
                ? const KaidaSkeletonList(count: 5)
                : _filteredItems.isEmpty
                    ? KaidaEmptyState(
                        kind: isProductMode ? KaidaEmptyKind.products : KaidaEmptyKind.courses,
                        primaryLabel: isProductMode ? 'Browse products' : 'Browse all courses',
                        onPrimary: () { _searchController.clear(); },
                        secondaryLabel: isProductMode ? 'Browse categories' : 'Browse all categories',
                        secondaryAsLink: !isProductMode,
                        onSecondary: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
                      )
                    : RefreshIndicator(
                        color: AppTheme.primaryColor,
                        onRefresh: _fetchCatalog,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          physics: const AlwaysScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                            mainAxisExtent: 260,
                          ),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) => _buildGridCard(_filteredItems[index], isDark),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // COURSES layout (purple header, floating search, colour tiles, chips, grid)
  // ---------------------------------------------------------------------------
  static const List<Color> _tileColors = [
    Color(0xFF7351FF), Color(0xFFFFB020), Color(0xFFEF4444), Color(0xFF2F80ED),
    Color(0xFF22C55E), Color(0xFFF97316), Color(0xFFEC4899), Color(0xFF06B6D4),
  ];

  IconData _iconForCategory(String name) => CategoryStyle.iconFor(name);

  Widget _buildCourses(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;
    final canPop = Navigator.of(context).canPop();
    final isCategoryPage = widget.actionType.startsWith('category_');

    // Categories found in the loaded courses
    final List<String> catNames = [];
    for (final i in _allItems) {
      if (i.categoryName.isNotEmpty && !catNames.contains(i.categoryName)) catNames.add(i.categoryName);
    }
    final chips = ['All', 'Popular', 'New', 'Free', 'Sale'];
    final sectioned = !isCategoryPage && _selectedCategory == 'All' && _chip == 'All' && _searchController.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : Colors.white,
      body: Column(
        children: [
          // Header + floating search
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 52),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF4C2FE0), Color(0xFF7351FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!canPop) ...[
                        Row(
                          children: [
                            Image.asset('assets/kainuwa_academy_whitelogo.png', height: 34, fit: BoxFit.contain),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('Kainuwa Academy', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                              child: Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle), child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 20)),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                              child: Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle), child: const Icon(Icons.person_rounded, color: Colors.white, size: 20)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      Row(
                    children: [
                      if (canPop) ...[
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                            const SizedBox(height: 2),
                            const Text('Learn practical skills step by step', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const Icon(Icons.school_rounded, color: Colors.white24, size: 54),
                    ],
                  ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16, right: 16, bottom: -26,
                  child: Container(
                    padding: const EdgeInsets.only(left: 14, right: 8),
                    height: 54,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.12), blurRadius: 18, offset: const Offset(0, 8))],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search courses, skills or topics...',
                              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(icon: Icon(Icons.close_rounded, color: Colors.grey.shade500, size: 18), onPressed: () => _searchController.clear())
                                  : null,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showFilterModal(isDark),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.tune_rounded, color: AppTheme.primaryColor, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const KaidaSkeletonList(count: 5)
                : RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: _fetchCatalog,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // Colour category tiles
                        if (!isCategoryPage && catNames.isNotEmpty)
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 94,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
                                itemCount: catNames.length + 1,
                                itemBuilder: (context, index) {
                                  final isAll = index == 0;
                                  final name = isAll ? 'All' : catNames[index - 1];
                                  final color = isAll ? AppTheme.primaryColor : CategoryStyle.colorFor(name);
                                  final selected = _selectedCategory == name;
                                  return GestureDetector(
                                    onTap: () { _selectedCategory = name; _filterResults(); },
                                    child: SizedBox(
                                      width: 74,
                                      child: Column(
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 180),
                                            width: 52, height: 52,
                                            decoration: BoxDecoration(
                                              color: color,
                                              borderRadius: BorderRadius.circular(17),
                                              border: Border.all(color: selected ? (isDark ? Colors.white : const Color(0xFF1E1E2D)) : Colors.transparent, width: 2.5),
                                              boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 9, offset: const Offset(0, 4))],
                                            ),
                                            child: Icon(isAll ? Icons.grid_view_rounded : _iconForCategory(name), color: Colors.white, size: 24),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 10.5, height: 1.15, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                        // Filter chips
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 56,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                              itemCount: chips.length,
                              itemBuilder: (context, index) {
                                final label = chips[index];
                                final selected = _chip == label;
                                final text = label == 'All' ? 'All (${_allItems.length})' : label;
                                return GestureDetector(
                                  onTap: () { _chip = label; _filterResults(); },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 18),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: selected ? AppTheme.primaryColor : (isDark ? AppTheme.darkSurfaceColor : const Color(0xFFF3F1FF)),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : (isDark ? Colors.grey.shade300 : const Color(0xFF3B3B4F)))),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        if (_filteredItems.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: KaidaEmptyState(
                              kind: KaidaEmptyKind.courses,
                              primaryLabel: 'Browse all courses',
                              onPrimary: () { _searchController.clear(); _selectedCategory = 'All'; _chip = 'All'; _filterResults(); },
                              secondaryLabel: 'Browse all categories',
                              secondaryAsLink: true,
                              onSecondary: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
                            ),
                          )
                        else if (sectioned)
                          ..._buildSections(isDark)
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 100),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 206,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildCourseGridCard(_filteredItems[index], isDark),
                                childCount: _filteredItems.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSections(bool isDark) {
    final Map<String, List<CatalogItem>> groups = {};
    final Map<String, int> ids = {};
    for (final i in _filteredItems) {
      groups.putIfAbsent(i.categoryName, () => []).add(i);
      if (i.categoryId > 0) ids[i.categoryName] = i.categoryId;
    }
    final List<Widget> out = [];
    groups.forEach((name, list) {
      final color = CategoryStyle.colorFor(name);
      out.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(11)),
                child: Icon(CategoryStyle.iconFor(name), color: Colors.white, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900))),
              TextButton(
                onPressed: () {
                  final id = ids[name] ?? 0;
                  if (id > 0) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CatalogScreen(actionType: 'category_$id', title: name)));
                  } else {
                    _selectedCategory = name; _filterResults();
                  }
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Text('View more', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 13)),
                  Icon(Icons.chevron_right_rounded, color: AppTheme.primaryColor, size: 18),
                ]),
              ),
            ],
          ),
        ),
      ));
      out.add(SliverToBoxAdapter(
        child: SizedBox(
          height: 206,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            itemCount: list.length > 8 ? 8 : list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _buildCourseGridCard(list[i], isDark, width: 190),
          ),
        ),
      ));
    });
    out.add(const SliverToBoxAdapter(child: SizedBox(height: 100)));
    return out;
  }

  String _compact(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K' : '$n';

  Widget _buildCourseGridCard(CatalogItem item, bool isDark, {double? width}) {
    final isWishlisted = _wishlistedCourseIds.contains(item.id);
    final isFree = item.isFree || (item.price == 0 && item.discountPrice == 0);
    final hasDiscount = item.discountPrice > 0 && item.discountPrice < item.price;
    final muted = Colors.grey.shade500;
    const imgH = 88.0;

    Widget meta(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: AppTheme.primaryColor),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 10.5, color: muted, fontWeight: FontWeight.w600)),
        ]);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailsScreen(item: item))),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.07), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: item.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: item.thumbnailUrl, height: imgH, width: double.infinity, fit: BoxFit.cover)
                      : Container(height: imgH, width: double.infinity, color: AppTheme.primaryColor.withOpacity(0.15), child: const Icon(Icons.school_rounded, size: 34, color: AppTheme.primaryColor)),
                ),
                if (item.isComingSoon)
                  Container(height: imgH, decoration: const BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.vertical(top: Radius.circular(16))), child: const Center(child: Icon(Icons.lock_clock_rounded, color: Colors.white, size: 28))),
                if (item.isComingSoon || hasDiscount)
                  Positioned(
                    bottom: 6, left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFFFC21A), borderRadius: BorderRadius.circular(10)),
                      child: Text(item.isComingSoon ? 'Coming Soon' : 'Sale', style: const TextStyle(color: Color(0xFF1E1E2D), fontSize: 9.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                if (!item.isComingSoon)
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () => _toggleWishlist(item.id),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: isDark ? Colors.black54 : Colors.white.withOpacity(0.92), shape: BoxShape.circle),
                        child: Icon(isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isWishlisted ? Colors.redAccent : AppTheme.primaryColor, size: 16),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(item.shortDesc.isNotEmpty ? item.shortDesc : item.instructorName, style: TextStyle(color: muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        meta(Icons.play_circle_outline_rounded, item.lessonCount > 0 ? '${item.lessonCount} Lessons' : 'Lessons soon'),
                        if (item.sectionCount > 0) ...[
                          const SizedBox(width: 8),
                          Flexible(child: meta(Icons.article_outlined, '${item.sectionCount} Modules')),
                        ],
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (!item.isComingSoon) StarRating(rating: StarRating.resolve(item.avgRating, item.id), size: 12),
                              if (item.reviewCount > 0 && !item.isComingSoon)
                                Text(' (${_compact(item.reviewCount)})', style: TextStyle(fontSize: 10, color: muted, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 4),
                        item.isComingSoon
                            ? const Text('SOON', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w800, fontSize: 11))
                            : isFree
                                ? const Text('FREE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 14))
                                : Text('₦${(hasDiscount ? item.discountPrice : item.price).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.primaryColor)),
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

  Widget _buildGridCard(CatalogItem item, bool isDark) {
    int discountPercent = 0;
    if (item.price > 0 && item.discountPrice > 0 && item.discountPrice < item.price) {
      discountPercent = (((item.price - item.discountPrice) / item.price) * 100).round();
    }
    
    bool isWishlisted = _wishlistedCourseIds.contains(item.id);
    bool isProductMode = widget.actionType.contains('products');

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailsScreen(item: item))),
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
                if (discountPercent > 0 && !item.isComingSoon && !item.isOutOfStock)
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                      child: Text('-$discountPercent%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (!item.isComingSoon && !item.isOutOfStock)
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () => _toggleWishlist(item.id),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: isDark ? Colors.black54 : Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                        child: Icon(
                          isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isWishlisted ? Colors.redAccent : Colors.grey.shade600,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                if (item.isComingSoon)
                  Container(height: 110, color: Colors.black54, child: const Center(child: Icon(Icons.lock_clock_rounded, color: Colors.white, size: 30)))
                else if (item.isOutOfStock)
                  Container(height: 110, color: Colors.black54, child: const Center(child: Text('OUT OF STOCK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)))),
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
                    
                    if (item.isComingSoon)
                      const Text('COMING SOON', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))
                    else if (item.isOutOfStock)
                      const Text('UNAVAILABLE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12))
                    else if (item.isFree || (item.price == 0 && item.discountPrice == 0))
                      const Text('FREE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14))
                    else if (item.discountPrice > 0 && item.discountPrice < item.price)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₦${item.discountPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.primaryColor)),
                          const SizedBox(width: 4),
                          Text('₦${item.price.toStringAsFixed(0)}', style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w600)),
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