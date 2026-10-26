import 'package:flutter/material.dart';

/// Five-star row. Pass the real rating; when a course has none yet, use [StarRating.fallbackFor].
class StarRating extends StatelessWidget {
  final double rating; // 0..5
  final double size;
  final bool showValue;
  const StarRating({Key? key, required this.rating, this.size = 14, this.showValue = true}) : super(key: key);

  /// Display rating for items with no reviews yet (4.5 to 5.0, stable per item).
  /// Change or remove this single function if you ever want real-only ratings.
  static double fallbackFor(int id) => 4.5 + (id % 6) * 0.1;

  static double resolve(double real, int id) => real > 0 ? real : fallbackFor(id);

  @override
  Widget build(BuildContext context) {
    final r = rating.clamp(0.0, 5.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final icon = r >= i + 1 ? Icons.star_rounded : (r >= i + 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded);
          return Icon(icon, size: size, color: const Color(0xFFFFB020));
        }),
        if (showValue) ...[
          const SizedBox(width: 4),
          Text(r.toStringAsFixed(1), style: TextStyle(fontSize: size * 0.82, fontWeight: FontWeight.w800)),
        ],
      ],
    );
  }
}