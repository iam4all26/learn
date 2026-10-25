import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../services/api_client.dart';
import '../widgets/kaida_loader.dart';
import '../utils/kaida_alert.dart';
import 'catalog_screen.dart';
import 'course_player_screen.dart';
import 'main_layout.dart';

class ItemDetailsScreen extends StatefulWidget {
  final CatalogItem item;
  const ItemDetailsScreen({Key? key, required this.item}) : super(key: key);

  @override
  _ItemDetailsScreenState createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isEnrolled = false;
  bool _isWishlisted = false;
  int? _userId;
  Map<String, dynamic>? _details;
  int _courseTab = 0; // 0 Overview, 1 Lessons, 2 Reviews
  final Set<int> _openSections = {0};
  
  late TabController _tabController;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  bool get isProduct => widget.item.type.contains('products'); 
  bool get isInstructor => !isProduct && _details?['course']?['instructor_id']?.toString() == _userId?.toString();

  bool get isDynamicOutOfStock {
    if (!isProduct) return false;
    if (widget.item.productType != 'physical') return false;
    if (_details == null) return widget.item.isOutOfStock; 
    int qty = int.tryParse(_details!['product']?['stock_quantity']?.toString() ?? '1') ?? 1;
    return qty <= 0;
  }

  String get displayTitle => (!isProduct ? _details?['course']?['title'] : _details?['product']?['name'])?.toString() ?? widget.item.title;
  String get displayCategory => (!isProduct ? _details?['course']?['category_name'] : _details?['product']?['category_name'])?.toString() ?? widget.item.categoryName;
  String get displayInstructor => isProduct ? 'Kainuwa Store' : (_details?['course']?['instructor_name']?.toString() ?? widget.item.instructorName);
  
  String get displayImageUrl {
    String url = (!isProduct ? _details?['course']?['thumbnail_url'] : _details?['product']?['thumbnail_path'])?.toString() ?? widget.item.thumbnailUrl;
    if (url.isNotEmpty && !url.startsWith('http')) url = 'https://academy.kainuwa.africa/' + url.replaceFirst(RegExp(r'^/+'), '');
    return url;
  }

  bool get displayIsFree {
    var freeFlag = (!isProduct ? _details?['course']?['is_free'] : _details?['product']?['is_free']);
    if (freeFlag != null) return freeFlag == 1 || freeFlag == '1' || freeFlag == true;
    return widget.item.isFree;
  }

  double get displayPrice {
    var p = (!isProduct ? _details?['course']?['price'] : _details?['product']?['price']);
    if (p != null) return double.tryParse(p.toString()) ?? 0.0;
    return widget.item.price;
  }

  double get displayDiscountPrice {
    var p = (!isProduct ? _details?['course']?['discount_price'] : _details?['product']?['discount_price']);
    if (p != null) return double.tryParse(p.toString()) ?? 0.0;
    return widget.item.discountPrice;
  }
  
  bool get displayIsComingSoon {
    if (isProduct) return false;
    var releaseDate = _details?['course']?['release_date'];
    if (releaseDate != null) {
       DateTime? d = DateTime.tryParse(releaseDate.toString());
       if (d != null && d.isAfter(DateTime.now())) return true;
    }
    return widget.item.isComingSoon;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Safety check: if slug is completely empty, fail immediately
    if (widget.item.slug.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
    } else {
      _fetchDetails();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');

    String endpoint = isProduct ? 'product_details.php' : 'course_details.php';

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/$endpoint?slug=${widget.item.slug}&user_id=${_userId ?? 0}'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          if (mounted) {
            setState(() {
              _details = data['data'];
              _isEnrolled = data['data']['is_enrolled'] == true;
              _isWishlisted = data['data']['is_wishlisted'] == true;
              _isLoading = false;
            });
            if (!isProduct) _initializeVideoPlayer();
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initializeVideoPlayer() {
    String introUrl = _details?['course']?['intro_video_url']?.toString() ?? '';
    if (introUrl.isNotEmpty) {
      if (!introUrl.startsWith('http')) introUrl = 'https://academy.kainuwa.africa/' + introUrl;
      _videoController = VideoPlayerController.network(introUrl)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _chewieController = ChewieController(
                videoPlayerController: _videoController!,
                autoPlay: false,
                looping: false,
                aspectRatio: _videoController!.value.aspectRatio,
                materialProgressColors: ChewieProgressColors(playedColor: AppTheme.primaryColor, handleColor: AppTheme.primaryColor, backgroundColor: Colors.grey),
              );
            });
          }
        });
    }
  }

  void _showVideoDialog() {
    if (_chewieController == null) return;
    _videoController?.play(); 

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85), 
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent, 
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: Chewie(controller: _chewieController!)),
        ),
      ),
    ).then((_) => _videoController?.pause());
  }

  Future<void> _toggleWishlist() async {
    if (_userId == null) {
      KaidaAlert.showModal(context: context, title: 'Authentication Required', message: 'Please log in to save items.', isError: true);
      return;
    }

    setState(() => _isWishlisted = !_isWishlisted);

    try {
      String apiUrl = '${ApiConfig.baseUrl}/toggle_wishlist.php'.replaceAll('//toggle', '/toggle');
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {'user_id': _userId.toString(), 'item_id': widget.item.id.toString(), 'item_type': isProduct ? 'product' : 'course'}
      );
      final data = json.decode(response.body);
      if (data['status'] != 'success') setState(() => _isWishlisted = !_isWishlisted); 
    } catch (e) {
      setState(() => _isWishlisted = !_isWishlisted); 
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (_userId == null) {
      KaidaAlert.showModal(context: context, title: 'Authentication Required', message: 'Please log in first.', isError: true);
      return;
    }

    if ((_isEnrolled || isInstructor) && !isProduct) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => CoursePlayerScreen(courseId: widget.item.id, courseTitle: displayTitle)));
    } else {
      String targetPath = isProduct 
          ? '/api/mobile/buy_now.php?product_id=${widget.item.id}' 
          : '/enroll.php?course_id=${widget.item.id}';
          
      // Secure one-time sign-in link from the server
      final String? authBridgeUrl = await ApiClient.webviewUrl(targetPath);
      if (!mounted) return;
      if (authBridgeUrl == null) {
        KaidaAlert.showModal(context: context, title: 'Could not open', message: 'We could not open the checkout right now. Please check your internet and try again.', isError: true);
        return;
      }

      Navigator.push(context, MaterialPageRoute(builder: (context) => CheckoutWebViewScreen(
        title: isProduct ? 'Checkout' : 'Enroll Course',
        url: authBridgeUrl,
      )));
    }
  }

  String _getButtonLabel(String priceText) {
    if (displayIsComingSoon) return 'Coming Soon';
    if (isProduct) {
      if (isDynamicOutOfStock) return 'Out of Stock';
      return 'Buy Product $priceText';
    } else {
      if (_isEnrolled || isInstructor) return 'Start Learning';
      return 'Enroll Course $priceText';
    }
  }

  Widget _buildStatCard(IconData icon, String value, String label, bool isDark, {Color? valueColor}) {
    return Container(
      height: 90, 
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: isDark ? Colors.black12 : Colors.grey.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 22),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor ?? (isDark ? Colors.white : Colors.black)))),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildSmartSpecificationsGrid(dynamic specsData, bool isDark) {
    if (specsData == null || specsData.toString().isEmpty) {
      return Text('No specifications provided.', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontSize: 15));
    }

    Map<String, dynamic> specsMap = {};
    try {
      if (specsData is String) {
        specsMap = json.decode(specsData);
      } else if (specsData is Map) {
        specsMap = Map<String, dynamic>.from(specsData);
      }
    } catch (e) {
      return Text('Specifications unavailable.', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontSize: 15));
    }

    if (specsMap.isEmpty) return Text('No specifications provided.', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontSize: 15));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 20, childAspectRatio: 2.2),
      itemCount: specsMap.length,
      itemBuilder: (context, index) {
        String key = specsMap.keys.elementAt(index);
        String val = specsMap[key].toString();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(key, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            if (val.isNotEmpty)
              Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // CRITICAL FIX: If the screen finishes loading but _details is still NULL, show an error!
    if (!_isLoading && _details == null) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackgroundColor : Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black, size: 20), onPressed: () => Navigator.pop(context)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_rounded, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text('Item Unavailable', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 8),
              Text('This item may have been removed or updated.', style: TextStyle(color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    String priceText = 'Free';
    if (!displayIsFree) {
       priceText = displayDiscountPrice > 0 ? '₦${displayDiscountPrice.toStringAsFixed(0)}' : '₦${displayPrice.toStringAsFixed(0)}';
    }

    bool isButtonDisabled = displayIsComingSoon || isDynamicOutOfStock;
    String instructorAvatar = _details?['course']?['instructor_avatar']?.toString() ?? '';

    if (!isProduct) return _buildCourseDetails(isDark, priceText, isButtonDisabled, instructorAvatar);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : Colors.white,
      body: _isLoading
          ? const Center(child: KaidaLoader())
          : Stack(
              children: [
                NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black, size: 28),
                                    ),
                                    GestureDetector(
                                      onTap: _toggleWishlist,
                                      child: Icon(
                                        _isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                                        color: _isWishlisted ? Colors.redAccent : Colors.grey.shade400,
                                        size: 28,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      height: 200,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.black26 : Colors.grey.shade100,
                                        image: displayImageUrl.isNotEmpty ? DecorationImage(
                                          image: CachedNetworkImageProvider(displayImageUrl),
                                          fit: BoxFit.cover,
                                        ) : null,
                                      ),
                                      child: (!isProduct && _details?['course']?['intro_video_url'] != null && _details!['course']['intro_video_url'].toString().isNotEmpty)
                                          ? GestureDetector(
                                              onTap: () { if (_chewieController != null) _showVideoDialog(); }, 
                                              child: Center(
                                                child: Container(
                                                  padding: const EdgeInsets.all(14),
                                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)]),
                                                  child: _chewieController == null 
                                                    ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 3))
                                                    : const Icon(Icons.play_arrow_rounded, color: AppTheme.primaryColor, size: 32),
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  
                                  if (!isButtonDisabled)
                                    Positioned(
                                      bottom: -16, right: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(24),
                                          boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
                                        ),
                                        child: Text(priceText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                            
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(displayTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.2)),
                                  const SizedBox(height: 12),
                                  
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                                      const SizedBox(width: 6),
                                      Text(_details?['review_summary']?['avg_rating']?.toString() ?? '4.5', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(width: 4),
                                      Text('(${_details?['review_summary']?['total_reviews'] ?? '0'} reviews)', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                                      const SizedBox(width: 12),
                                      Container(height: 14, width: 1.5, color: Colors.grey.shade300),
                                      const SizedBox(width: 12),
                                      Text(displayCategory, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  if (isProduct)
                                    Row(
                                      children: [
                                        Expanded(child: _buildStatCard(
                                          Icons.inventory_2_rounded, 
                                          isDynamicOutOfStock ? 'Out of Stock' : (_details?['product']?['stock_quantity']?.toString() ?? 'In Stock'), 
                                          'Availability', 
                                          isDark,
                                          valueColor: isDynamicOutOfStock ? Colors.redAccent : null
                                        )),
                                        const SizedBox(width: 8),
                                        Expanded(child: _buildStatCard(Icons.local_shipping_rounded, widget.item.productType == 'digital' ? 'Instant' : 'Shipping', 'Delivery', isDark)),
                                        const SizedBox(width: 8),
                                        Expanded(child: _buildStatCard(Icons.category_rounded, widget.item.productType.toUpperCase(), 'Type', isDark)),
                                      ],
                                    )
                                  else
                                    Row(
                                      children: [
                                        Expanded(child: _buildStatCard(Icons.people_alt_rounded, _details?['student_count']?.toString() ?? '0', 'Students', isDark)),
                                        const SizedBox(width: 8),
                                        Expanded(child: _buildStatCard(Icons.access_time_rounded, '25 hours', 'Duration', isDark)), 
                                        const SizedBox(width: 8),
                                        Expanded(child: _buildStatCard(Icons.play_lesson_rounded, _details?['sections']?.length.toString() ?? '0', 'Modules', isDark)),
                                        const SizedBox(width: 8),
                                        Expanded(child: _buildStatCard(Icons.workspace_premium_rounded, 'Yes', 'Certificate', isDark)),
                                      ],
                                    ),
                                  
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverAppBarDelegate(
                          TabBar(
                            controller: _tabController,
                            labelColor: AppTheme.primaryColor,
                            unselectedLabelColor: Colors.grey.shade500,
                            indicatorColor: AppTheme.primaryColor,
                            indicatorWeight: 3,
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            tabs: isProduct ? const [
                              Tab(text: 'Description'),
                              Tab(text: 'Details'),
                              Tab(text: 'Reviews'),
                            ] : const [
                              Tab(text: 'About'),
                              Tab(text: 'Lessons'),
                              Tab(text: 'Reviews'),
                            ],
                          ),
                          isDark ? AppTheme.darkBackgroundColor : Colors.white,
                        ),
                      ),
                    ];
                  },
                  
                  body: TabBarView(
                    controller: _tabController,
                    children: isProduct ? [
                      _buildAboutTab(isDark),
                      _buildProductDetailsTab(isDark),
                      _buildReviewsTab(isDark),
                    ] : [
                      _buildAboutTab(isDark, instructorAvatar),
                      _buildLessonsTab(isDark),
                      _buildReviewsTab(isDark),
                    ],
                  ),
                ),
                
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkBackgroundColor : Colors.white,
                      border: Border(top: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isButtonDisabled ? null : _handlePrimaryAction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isButtonDisabled ? (isDark ? Colors.grey.shade700 : Colors.grey.shade400) : AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 0,
                          ),
                          child: Text(
                            _getButtonLabel(priceText),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }


  // ===========================================================================
  // COURSE DETAILS (purple header, banner, tiles, pill tabs, bottom price bar)
  // ===========================================================================
  static const Color _kPurpleDeep = Color(0xFF4C2FE0);
  static const Color _kYellow = Color(0xFFFFC21A);

  /// Decodes the HTML entities that were stored with the text and strips tags
  String _clean(String? raw) {
    var t = raw ?? '';
    t = t.replaceAll(RegExp(r'<br\s*/?>|</p>|</li>', caseSensitive: false), '\n').replaceAll(RegExp(r'<[^>]*>'), '');
    for (var i = 0; i < 3; i++) {
      t = t.replaceAll('&amp;', '&').replaceAll('&#039;', "'").replaceAll('&#39;', "'").replaceAll('&quot;', '"').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&nbsp;', ' ');
    }
    return t.trim();
  }

  String get _subtitle {
    final d = _clean(_details?['course']?['description']?.toString());
    if (d.isEmpty) return '';
    final first = d.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '').trim();
    return first.length > 110 ? first.substring(0, 107).trimRight() + '...' : first;
  }

  int get _lessonTotal {
    int n = 0;
    final m = _details?['items_by_section'];
    if (m is Map) { m.forEach((k, v) { if (v is List) n += v.length; }); }
    return n;
  }

  List<Map<String, dynamic>> _curriculum() {
    final out = <Map<String, dynamic>>[];
    final items = _details?['items_by_section'];
    final Map itemsMap = items is Map ? items : {};
    final used = <String>{};
    final secs = _details?['sections'];
    if (secs is List) {
      for (final s in secs) {
        final key = s['id'].toString();
        used.add(key);
        final list = itemsMap[key];
        out.add({'title': _clean(s['title']?.toString()), 'items': list is List ? list : []});
      }
    }
    final extra = <dynamic>[];
    itemsMap.forEach((k, v) { if (!used.contains(k.toString()) && v is List) extra.addAll(v); });
    if (extra.isNotEmpty) out.add({'title': 'More lessons', 'items': extra});
    return out;
  }

  Widget _headerCircleButton(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildCourseDetails(bool isDark, String priceText, bool isButtonDisabled, String instructorAvatar) {
    final hasVideo = _details?['course']?['intro_video_url'] != null && _details!['course']['intro_video_url'].toString().isNotEmpty;
    final ratingVal = double.tryParse(_details?['review_summary']?['avg_rating']?.toString() ?? '') ?? 0;
    final reviewCount = int.tryParse(_details?['review_summary']?['total_reviews']?.toString() ?? '') ?? 0;
    final modules = (_details?['sections'] is List) ? (_details!['sections'] as List).length : 0;
    final canStart = _isEnrolled || isInstructor;
    final isFree = displayIsFree;
    final hasDiscount = !isFree && displayDiscountPrice > 0 && displayDiscountPrice < displayPrice;
    final discountPct = hasDiscount ? (((displayPrice - displayDiscountPrice) / displayPrice) * 100).round() : 0;
    final bg = isDark ? AppTheme.darkBackgroundColor : Colors.white;
    final sub = _subtitle;
    final language = (_details?['course']?['language'] ?? widget.item.language).toString();

    return Scaffold(
      backgroundColor: _kPurpleDeep,
      body: _isLoading
          ? Container(color: bg, child: const Center(child: KaidaLoader()))
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: canStart ? 100 : 190),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---- Purple header with banner ----
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFF3A22C4), Color(0xFF6B47F5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                                child: Row(
                                  children: [
                                    _headerCircleButton(Icons.arrow_back_rounded, () => Navigator.pop(context)),
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Image.asset('assets/kainuwa_academy_whitelogo.png', height: 30, fit: BoxFit.contain),
                                          const SizedBox(width: 8),
                                          const Text('Kainuwa Academy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                                        ],
                                      ),
                                    ),
                                    _headerCircleButton(_isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded, _toggleWishlist, color: _isWishlisted ? const Color(0xFFFF6B7A) : Colors.white),
                                    const SizedBox(width: 8),
                                    _headerCircleButton(Icons.share_rounded, () {
                                      Share.share('${displayTitle}\nhttps://academy.kainuwa.africa/course/${widget.item.slug}');
                                    }),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Container(
                                    height: 200,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      image: displayImageUrl.isNotEmpty ? DecorationImage(image: CachedNetworkImageProvider(displayImageUrl), fit: BoxFit.cover) : null,
                                    ),
                                    child: hasVideo
                                        ? GestureDetector(
                                            onTap: () { if (_chewieController != null) _showVideoDialog(); },
                                            child: Stack(
                                              children: [
                                                Center(
                                                  child: Container(
                                                    width: 62, height: 62,
                                                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 14)]),
                                                    child: _chewieController == null
                                                        ? const Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 3))
                                                        : const Icon(Icons.play_arrow_rounded, color: AppTheme.primaryColor, size: 38),
                                                  ),
                                                ),
                                                Positioned(
                                                  left: 12, bottom: 12,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(18)),
                                                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                                                      Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 14),
                                                      SizedBox(width: 5),
                                                      Text('Preview', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                                    ]),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ---- White sheet ----
                      Container(
                        color: _kPurpleDeep,
                        child: Container(
                          width: double.infinity,
                          transform: Matrix4.translationValues(0, -4, 0),
                          decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_clean(displayTitle), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.15, letterSpacing: -0.4)),
                              if (sub.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(sub, style: TextStyle(fontSize: 14.5, color: Colors.grey.shade600, height: 1.35)),
                              ],
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  if (ratingVal > 0) ...[
                                    const Icon(Icons.star_rounded, color: Color(0xFFFFB020), size: 20),
                                    const SizedBox(width: 3),
                                    Text(ratingVal.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                    const SizedBox(width: 4),
                                    Text('($reviewCount reviews)', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                                  ] else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                      child: const Text('New course', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 12)),
                                    ),
                                  const SizedBox(width: 14),
                                  Container(height: 16, width: 1, color: Colors.grey.shade300),
                                  const SizedBox(width: 14),
                                  const Icon(Icons.play_lesson_rounded, size: 17, color: AppTheme.primaryColor),
                                  const SizedBox(width: 5),
                                  Text('$_lessonTotal Lessons', style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // ---- 4 feature tiles ----
                              Row(
                                children: [
                                  _featureTile(Icons.translate_rounded, const Color(0xFF7351FF), language, 'Language'),
                                  _featureTile(Icons.people_alt_rounded, const Color(0xFFFFB020), _details?['student_count']?.toString() ?? '0', 'Students'),
                                  _featureTile(Icons.view_module_rounded, const Color(0xFFEF4444), '$modules', 'Modules'),
                                  _featureTile(Icons.workspace_premium_rounded, const Color(0xFF22C55E), 'Included', 'Certificate'),
                                ],
                              ),
                              const SizedBox(height: 22),

                              // ---- Pill tabs ----
                              Row(
                                children: List.generate(3, (i) {
                                  final labels = ['Overview', 'Lessons', 'Reviews'];
                                  final sel = _courseTab == i;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _courseTab = i),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        margin: EdgeInsets.only(right: i == 2 ? 0 : 8),
                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: sel ? AppTheme.primaryColor : (isDark ? AppTheme.darkSurfaceColor : const Color(0xFFF3F1FF)),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Text(labels[i], style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: sel ? Colors.white : (isDark ? Colors.grey.shade300 : const Color(0xFF3B3B4F)))),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 20),

                              if (_courseTab == 0) _courseOverview(isDark, instructorAvatar)
                              else if (_courseTab == 1) _courseLessons(isDark)
                              else _courseReviews(isDark),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ---- Bottom price + action bar ----
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 20, offset: const Offset(0, -6))],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!canStart && !displayIsComingSoon)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (hasDiscount) ...[
                                      Text('₦${displayPrice.toStringAsFixed(0)}', style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey.shade400, fontSize: 15, fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 10),
                                    ],
                                    Text(priceText, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.primaryColor, letterSpacing: -0.5)),
                                    if (hasDiscount) ...[
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(color: const Color(0xFFDDF7E6), borderRadius: BorderRadius.circular(9)),
                                        child: Text('$discountPct% OFF', style: const TextStyle(color: Color(0xFF168A45), fontWeight: FontWeight.w800, fontSize: 12)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            SizedBox(
                              width: double.infinity, height: 52,
                              child: ElevatedButton(
                                onPressed: isButtonDisabled ? null : _handlePrimaryAction,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kYellow,
                                  disabledBackgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(displayIsComingSoon ? 'Coming Soon' : (canStart ? 'Start Learning' : (isFree ? 'Enroll for Free' : 'Enroll Now')), style: const TextStyle(color: Color(0xFF1E1E2D), fontSize: 16, fontWeight: FontWeight.w800)),
                                    if (!displayIsComingSoon) ...[const SizedBox(width: 8), const Icon(Icons.arrow_forward_rounded, color: Color(0xFF1E1E2D), size: 20)],
                                  ],
                                ),
                              ),
                            ),
                            if (!canStart) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity, height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: _toggleWishlist,
                                  icon: Icon(_isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: AppTheme.primaryColor, size: 20),
                                  label: Text(_isWishlisted ? 'Saved to My Wishlist' : 'Add to My Wishlist', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 15, fontWeight: FontWeight.w800)),
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryColor, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _featureTile(IconData icon, Color color, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 7),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800))),
          Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _courseOverview(bool isDark, String avatarUrl) {
    final outcomesRaw = _clean(_details?['course']?['learning_outcomes']?.toString());
    final outcomes = outcomesRaw
        .split('\n')
        .map((l) => l.trim().replaceFirst(RegExp(r'^[-*••]+\s*'), ''))
        .where((l) => l.isNotEmpty)
        .toList();
    final desc = _clean(_details?['course']?['description']?.toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (outcomes.isNotEmpty) ...[
          const Text("What You'll Learn", style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
          const SizedBox(height: 12),
          ...outcomes.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 20)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(o, style: TextStyle(fontSize: 14.5, height: 1.35, color: isDark ? Colors.grey.shade300 : const Color(0xFF2B2B3A)))),
                  ],
                ),
              )),
          const SizedBox(height: 14),
        ],
        const Text('About This Course', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
        const SizedBox(height: 10),
        Text(desc.isEmpty ? 'No description available.' : desc, style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, height: 1.55, fontSize: 14.5)),
        const SizedBox(height: 22),
        const Text('Your Instructor', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
        const SizedBox(height: 10),
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
              child: avatarUrl.isEmpty ? const Icon(Icons.person_rounded, color: AppTheme.primaryColor) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_clean(displayInstructor), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(_clean(_details?['course']?['instructor_headline']?.toString()).isEmpty ? 'Instructor' : _clean(_details?['course']?['instructor_headline']?.toString()), style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFFF4DC), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _kYellow, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Completion Certificate', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFFB86E00))),
                    SizedBox(height: 2),
                    Text('Finish all the lessons of this course and earn your certificate.', style: TextStyle(fontSize: 12.5, color: Color(0xFF7A5B2A), height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _courseLessons(bool isDark) {
    final curriculum = _curriculum();
    if (curriculum.isEmpty || _lessonTotal == 0) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('Curriculum being updated.', style: TextStyle(color: Colors.grey.shade500))));
    }
    final canOpen = _isEnrolled || isInstructor;
    final allOpen = _openSections.length >= curriculum.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Course Content', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                  const SizedBox(height: 2),
                  Text('${curriculum.length} Modules  •  $_lessonTotal Lessons', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() {
                if (allOpen) { _openSections.clear(); } else { _openSections..clear()..addAll(List.generate(curriculum.length, (i) => i)); }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Text(allOpen ? 'Collapse All' : 'Expand All', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  const SizedBox(width: 2),
                  Icon(allOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryColor, size: 18),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...List.generate(curriculum.length, (si) {
          final sec = curriculum[si];
          final List items = sec['items'] as List;
          final open = _openSections.contains(si);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() { if (open) { _openSections.remove(si); } else { _openSections.add(si); } }),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 34, height: 34, alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(11)),
                          child: Text('${si + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sec['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.2)),
                              const SizedBox(height: 2),
                              Text('${items.length} lessons', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
                if (open)
                  ...List.generate(items.length, (ii) {
                    final it = items[ii];
                    final type = (it['type'] ?? 'lesson').toString();
                    final label = type == 'quiz' ? 'Quiz' : (type == 'assignment' ? 'Assignment' : 'Lesson');
                    final icon = type == 'quiz' ? Icons.quiz_rounded : (type == 'assignment' ? Icons.assignment_rounded : Icons.play_circle_fill_rounded);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (canOpen) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => CoursePlayerScreen(courseId: widget.item.id, courseTitle: displayTitle)));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enroll to unlock this lesson'), duration: Duration(seconds: 2)));
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF7F6FF), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Icon(icon, color: canOpen ? AppTheme.primaryColor : Colors.grey.shade400, size: 26),
                            const SizedBox(width: 10),
                            Text('${si + 1}.${ii + 1}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_clean(it['title']?.toString()), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.2)),
                                  Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5)),
                                ],
                              ),
                            ),
                            Icon(canOpen ? Icons.play_arrow_rounded : Icons.lock_outline_rounded, color: Colors.grey.shade500, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _courseReviews(bool isDark) {
    final List reviews = (_details?['reviews'] is List) ? _details!['reviews'] : [];
    final avg = double.tryParse(_details?['review_summary']?['avg_rating']?.toString() ?? '') ?? 0;
    final total = int.tryParse(_details?['review_summary']?['total_reviews']?.toString() ?? '') ?? 0;

    if (total == 0 || reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(child: Column(children: [
          Icon(Icons.rate_review_outlined, size: 46, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text('No reviews yet. Be the first to review after you learn.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
        ])),
      );
    }

    final dist = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final r in reviews) {
      final v = (int.tryParse(r['rating'].toString()) ?? 0).clamp(1, 5);
      dist[v] = (dist[v] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              children: [
                Text(avg.toStringAsFixed(1), style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900)),
                Row(children: List.generate(5, (i) => Icon(i < avg.round() ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFFFB020), size: 17))),
                const SizedBox(height: 4),
                Text('$total reviews', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                children: [5, 4, 3, 2, 1].map((star) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Text('$star', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: reviews.isEmpty ? 0 : (dist[star] ?? 0) / reviews.length, backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200, valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor), minHeight: 6))),
                      ]),
                    )).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...reviews.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(radius: 19, backgroundColor: Colors.grey.shade200, backgroundImage: (r['avatar_url'] ?? '').toString().isNotEmpty ? CachedNetworkImageProvider(r['avatar_url'].toString()) : null),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_clean(r['full_name']?.toString()).isEmpty ? 'Student' : _clean(r['full_name']?.toString()), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                        Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 14, color: i < (int.tryParse(r['rating'].toString()) ?? 5) ? const Color(0xFFFFB020) : Colors.grey.shade300))),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(_clean(r['review_text']?.toString()), style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontSize: 14, height: 1.4)),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildAboutTab(bool isDark, [String? avatarUrl]) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isProduct) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? CachedNetworkImageProvider(avatarUrl) : null,
                child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person_rounded, color: AppTheme.primaryColor) : null,
              ),
              title: Text(displayInstructor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text(_details?['course']?['instructor_headline'] ?? 'Professional Instructor', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ),
            const SizedBox(height: 24),
          ],
          Text(isProduct ? 'Product Description' : 'About Course', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            (isProduct ? _details?['product']?['description'] : _details?['course']?['description'])?.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '') ?? 'No description available.',
            style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, height: 1.5, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetailsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Specifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSmartSpecificationsGrid(_details?['product']?['specifications'], isDark),
        ],
      ),
    );
  }

  Widget _buildLessonsTab(bool isDark) {
    List<dynamic> lessons = [];
    if (_details?['items_by_section'] != null && _details!['items_by_section'] is Map) {
      _details!['items_by_section'].forEach((key, value) { lessons.addAll(value); });
    }

    if (lessons.isEmpty) return Center(child: Text('Curriculum being updated.', style: TextStyle(color: Colors.grey.shade500)));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      itemCount: lessons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        var lesson = lessons[index];
        return Row(
          children: [
            Container(
              height: 56, width: 64,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                image: displayImageUrl.isNotEmpty ? DecorationImage(image: CachedNetworkImageProvider(displayImageUrl), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken)) : null,
              ),
              child: Center(child: Text((index + 1).toString().padLeft(2, '0'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson['title'] ?? 'Lesson', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('15:00 mins', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)), 
                ],
              ),
            ),
            Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20)),
          ],
        );
      },
    );
  }

  Widget _buildReviewsTab(bool isDark) {
    List<dynamic> reviews = _details?['reviews'] ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                children: [
                  Text(_details?['review_summary']?['avg_rating']?.toString() ?? '0.0', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                  const Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber, size: 16), Icon(Icons.star_rounded, color: Colors.amber, size: 16), Icon(Icons.star_rounded, color: Colors.amber, size: 16), Icon(Icons.star_rounded, color: Colors.amber, size: 16), Icon(Icons.star_half_rounded, color: Colors.amber, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('(${_details?['review_summary']?['total_reviews'] ?? '0'} Reviews)', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [5, 4, 3, 2, 1].map((star) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text('$star', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: star == 5 ? 0.7 : (star == 4 ? 0.2 : 0.05), backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200, valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor), minHeight: 6))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Text('Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (reviews.isEmpty) Center(child: Text('No reviews yet.', style: TextStyle(color: Colors.grey.shade500))),
          ...reviews.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 20, backgroundImage: CachedNetworkImageProvider(r['avatar_url'] ?? ''), backgroundColor: Colors.grey.shade200),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['full_name'] ?? 'Buyer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Row(
                            children: [
                              ...List.generate(5, (i) => Icon(Icons.star_rounded, size: 14, color: i < (r['rating'] ?? 5) ? Colors.amber : Colors.grey.shade300)),
                              const SizedBox(width: 8),
                              Text('Verified', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)), 
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(r['review_text'] ?? '', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontSize: 14)),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color _color;
  _SliverAppBarDelegate(this._tabBar, this._color);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: _color, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class CheckoutWebViewScreen extends StatefulWidget {
  final String title;
  final String url;
  const CheckoutWebViewScreen({Key? key, required this.title, required this.url}) : super(key: key);
  @override
  _CheckoutWebViewScreenState createState() => _CheckoutWebViewScreenState();
}

class _CheckoutWebViewScreenState extends State<CheckoutWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false; 

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) { if (mounted) setState(() { _isLoading = true; _hasError = false; }); },
          onPageFinished: (String url) { if (mounted) setState(() => _isLoading = false); },
          onWebResourceError: (WebResourceError error) { if (mounted) setState(() { _isLoading = false; _hasError = true; }); },
          onHttpError: (HttpResponseError error) { if (mounted) setState(() { _isLoading = false; _hasError = true; }); },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<bool> _goBack() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return Future.value(false);
    }
    return Future.value(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return WillPopScope(
      onWillPop: _goBack,
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackgroundColor : Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black, size: 20), onPressed: () async { if (await _controller.canGoBack()) { _controller.goBack(); } else { Navigator.pop(context); } }),
          title: Text(widget.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          actions: [
            IconButton(icon: Icon(Icons.home_rounded, color: isDark ? Colors.white : Colors.black, size: 22), onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainLayout()), (route) => false)),
            IconButton(icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white : Colors.black, size: 22), onPressed: () { setState(() { _hasError = false; _isLoading = true; }); _controller.loadRequest(Uri.parse(widget.url)); }),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading && !_hasError) Container(color: isDark ? AppTheme.darkBackgroundColor : Colors.white, child: const Center(child: KaidaLoader())),
            if (_hasError)
              Container(color: isDark ? AppTheme.darkBackgroundColor : Colors.white, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.cloud_off_rounded, size: 80, color: Colors.grey), const SizedBox(height: 16), Text('Connection Failed', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)), const SizedBox(height: 24), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () { setState(() { _hasError = false; _isLoading = true; }); _controller.loadRequest(Uri.parse(widget.url)); }, icon: const Icon(Icons.refresh_rounded, color: Colors.white), label: const Text('Try Again', style: TextStyle(color: Colors.white)))]))),
          ],
        ),
      ),
    );
  }
}
