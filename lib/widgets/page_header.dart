import 'package:flutter/material.dart';

/// Shared purple header used by Notifications, Help Center, Change Password,
/// Downloads and My Learning. Squared (no rounded bottom corners).
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? illustration; // big faded icon on the right
  final List<Widget> actions;
  final Widget? bottom; // e.g. tabs, placed inside the purple area
  final bool showBack;
  final double bottomPadding;

  const PageHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.illustration,
    this.actions = const [],
    this.bottom,
    this.showBack = true,
    this.bottomPadding = 18,
  }) : super(key: key);

  static Widget circleButton(IconData icon, VoidCallback onTap, {Widget? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          if (badge != null) Positioned(right: -2, top: -2, child: badge),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, bottomPadding),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF3A22C4), Color(0xFF6B47F5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showBack) ...[
                circleButton(Icons.arrow_back_ios_new_rounded, () => Navigator.maybePop(context)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.3)),
                    ],
                  ],
                ),
              ),
              if (illustration != null && actions.isEmpty)
                Icon(illustration, color: Colors.white.withOpacity(0.28), size: 58),
              for (final a in actions) ...[const SizedBox(width: 8), a],
            ],
          ),
          if (bottom != null) ...[const SizedBox(height: 16), bottom!],
        ],
      ),
    );
  }
}

/// Pill-style tab row used inside the purple header.
class HeaderTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  const HeaderTabs({Key? key, required this.labels, required this.selected, required this.onChanged}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: i == selected ? Colors.white : Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(labels[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: i == selected ? const Color(0xFF4A2BE0) : Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}