import 'package:flutter/material.dart';
import '../config/app_theme.dart';

enum KaidaEmptyKind { products, courses, wishlist, downloads, notifications, search, generic }

const Color _p = Color(0xFF6B47F5);
const Color _y = Color(0xFFFFC21A);

/// Friendly illustrated empty state with up to two actions.
class KaidaEmptyState extends StatelessWidget {
  final KaidaEmptyKind kind;
  final String? title;
  final String? message;
  final String? primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool secondaryAsLink;

  const KaidaEmptyState({
    Key? key,
    this.kind = KaidaEmptyKind.generic,
    this.title,
    this.message,
    this.primaryLabel,
    this.primaryIcon = Icons.search_rounded,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryAsLink = false,
  }) : super(key: key);

  (String, String, IconData, IconData) get _look {
    switch (kind) {
      case KaidaEmptyKind.products:
        return ('No products', 'There are no products here yet. Check back soon or browse other categories.', Icons.inventory_2_rounded, Icons.shopping_cart_outlined);
      case KaidaEmptyKind.courses:
        return ('No courses here yet', 'We could not find any courses here. Try another category or browse everything.', Icons.menu_book_rounded, Icons.search_rounded);
      case KaidaEmptyKind.wishlist:
        return ('Your wishlist is empty', 'Tap the heart on any course or product to save it here for later.', Icons.favorite_rounded, Icons.favorite_border_rounded);
      case KaidaEmptyKind.downloads:
        return ('No downloads yet', 'Files you purchase or download will appear here.', Icons.download_rounded, Icons.insert_drive_file_outlined);
      case KaidaEmptyKind.notifications:
        return ('All caught up!', 'You have no notifications right now.', Icons.notifications_rounded, Icons.check_rounded);
      case KaidaEmptyKind.search:
        return ('No results found', 'Try a different word or check the spelling.', Icons.search_rounded, Icons.sentiment_dissatisfied_rounded);
      case KaidaEmptyKind.generic:
        return ('Nothing here yet', 'There is nothing to show right now.', Icons.inbox_rounded, Icons.hourglass_empty_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final look = _look;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _art(look.$3, look.$4, dark),
            const SizedBox(height: 22),
            Text(title ?? look.$1, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: dark ? Colors.white : const Color(0xFF16123A))),
            const SizedBox(height: 8),
            Text(message ?? look.$2, textAlign: TextAlign.center, style: TextStyle(fontSize: 14.5, height: 1.45, color: dark ? Colors.grey.shade400 : Colors.grey.shade600)),
            if (primaryLabel != null && onPrimary != null) ...[
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onPrimary,
                  icon: Icon(primaryIcon, color: Colors.white, size: 20),
                  label: Text(primaryLabel!, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                ),
              ),
            ],
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 10),
              secondaryAsLink
                  ? TextButton(onPressed: onSecondary, child: Text(secondaryLabel!, style: const TextStyle(color: _p, fontWeight: FontWeight.w800, fontSize: 14.5)))
                  : SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: onSecondary,
                        style: OutlinedButton.styleFrom(side: BorderSide(color: dark ? Colors.white24 : const Color(0xFFD9D2FF)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        child: Text(secondaryLabel!, style: TextStyle(color: dark ? Colors.white : const Color(0xFF4A2BE0), fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _art(IconData main, IconData bubble, bool dark) {
    return SizedBox(
      width: 190, height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 150, height: 150, decoration: BoxDecoration(color: _p.withOpacity(dark ? 0.16 : 0.08), shape: BoxShape.circle)),
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3A22C4), Color(0xFF6B47F5)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(26), boxShadow: [BoxShadow(color: _p.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8))]),
            child: Icon(main, color: Colors.white, size: 50),
          ),
          Positioned(
            top: 6, right: 14,
            child: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: dark ? AppTheme.darkSurfaceColor : Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
              child: Icon(bubble, color: _p, size: 26),
            ),
          ),
          Positioned(
            bottom: 8, left: 18,
            child: Container(
              width: 34, height: 34,
              decoration: const BoxDecoration(color: _y, shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly full-area error panel (never shows technical text).
class KaidaErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final bool noInternet;
  const KaidaErrorState({Key? key, required this.onRetry, this.noInternet = true}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const red = Color(0xFFE5484D);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 104, height: 104, decoration: BoxDecoration(color: red.withOpacity(dark ? 0.16 : 0.09), shape: BoxShape.circle), child: Icon(noInternet ? Icons.wifi_off_rounded : Icons.error_outline_rounded, color: red, size: 50)),
            const SizedBox(height: 20),
            Text(noInternet ? 'No internet connection' : 'Something went wrong', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: dark ? Colors.white : const Color(0xFF16123A))),
            const SizedBox(height: 8),
            Text(noInternet ? 'Please check your connection and try again.' : 'We could not load this. Please try again.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14.5, height: 1.45, color: dark ? Colors.grey.shade400 : Colors.grey.shade600)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              label: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            ),
          ],
        ),
      ),
    );
  }
}