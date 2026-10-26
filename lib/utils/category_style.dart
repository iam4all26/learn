import 'package:flutter/material.dart';

/// One place for category icons and colours, used by Home, Categories and Courses.
class CategoryStyle {
  static const List<Color> palette = [
    Color(0xFF7351FF), Color(0xFFFFB020), Color(0xFFEF4444), Color(0xFF2F80ED),
    Color(0xFF22C55E), Color(0xFFF97316), Color(0xFFEC4899), Color(0xFF06B6D4),
  ];

  /// Stable colour per category name (does not change when the list order changes).
  static Color colorFor(String name) {
    var h = 0;
    for (final c in name.toLowerCase().codeUnits) { h = (h * 31 + c) & 0x7fffffff; }
    return palette[h % palette.length];
  }

  static IconData iconFor(String name) {
    final n = name.toLowerCase();
    bool has(List<String> k) => k.any((e) => n.contains(e));

    if (has(['affiliate'])) return Icons.link_rounded;
    if (has(['poultry', 'agric', 'farm', 'livestock'])) return Icons.agriculture_rounded;
    if (has(['perfume', 'fragrance', 'scent'])) return Icons.local_florist_rounded;
    if (has(['resin', 'craft', 'handmade'])) return Icons.brush_rounded;
    if (has(['tailor', 'fashion', 'sewing', 'cloth'])) return Icons.checkroom_rounded;
    if (has(['forex', 'crypto', 'bitcoin', 'trading'])) return Icons.currency_bitcoin_rounded;
    if (has(['blockchain', 'web3', 'nft'])) return Icons.hub_rounded;
    if (has(['cyber', 'security', 'hacking'])) return Icons.shield_rounded;
    if (has(['artificial', 'machine learning', ' ai', 'ai '])) return Icons.smart_toy_rounded;
    if (n == 'ai') return Icons.smart_toy_rounded;
    if (has(['data'])) return Icons.analytics_rounded;
    if (has(['mobile', 'android', 'flutter', 'app dev'])) return Icons.phone_android_rounded;
    if (has(['ui/ux', 'ui ux', 'ux', 'product design'])) return Icons.design_services_rounded;
    if (has(['graphic', 'logo', 'canva', 'illustrat'])) return Icons.palette_rounded;
    if (has(['video', 'film', 'youtube', 'motion'])) return Icons.movie_creation_rounded;
    if (has(['photo', 'camera'])) return Icons.photo_camera_rounded;
    if (has(['web', 'program', 'cod', 'software', 'develop'])) return Icons.code_rounded;
    if (has(['e-commerce', 'ecommerce', 'dropship', 'shop', 'store'])) return Icons.shopping_cart_rounded;
    if (has(['digital marketing', 'marketing', 'social media', 'seo', 'advert'])) return Icons.campaign_rounded;
    if (has(['account', 'bookkeep', 'tax'])) return Icons.calculate_rounded;
    if (has(['invest', 'stock', 'wealth', 'saving'])) return Icons.savings_rounded;
    if (has(['financ', 'money', 'bank'])) return Icons.account_balance_wallet_rounded;
    if (has(['entrepreneur', 'startup'])) return Icons.rocket_launch_rounded;
    if (has(['business', 'management', 'manage'])) return Icons.business_center_rounded;
    if (has(['career', 'job', 'interview'])) return Icons.trending_up_rounded;
    if (has(['communicat', 'leader', 'speaking'])) return Icons.record_voice_over_rounded;
    if (has(['health', 'wellness', 'fitness', 'nutrition'])) return Icons.health_and_safety_rounded;
    if (has(['language', 'english', 'hausa', 'arabic', 'french'])) return Icons.translate_rounded;
    if (has(['time', 'productiv'])) return Icons.schedule_rounded;
    if (has(['personal', 'self', 'mindset', 'growth'])) return Icons.self_improvement_rounded;
    if (has(['teach', 'educat', 'school'])) return Icons.school_rounded;
    if (has(['music', 'audio', 'podcast'])) return Icons.music_note_rounded;
    if (has(['cook', 'food', 'bak', 'catering'])) return Icons.restaurant_rounded;
    return Icons.category_rounded;
  }
}