import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

const Color _kPurple = Color(0xFF6B47F5);
const Color _kYellow = Color(0xFFFFC21A);

bool _dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Rotating gradient arc (purple to yellow) used by several loaders.
class _ArcPainter extends CustomPainter {
  final double stroke;
  final Color track;
  final double sweep; // 0..1 of the circle
  _ArcPainter({required this.stroke, required this.track, this.sweep = 0.72});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    final trackPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..shader = const SweepGradient(colors: [_kPurple, _kPurple, _kYellow], stops: [0.0, 0.45, 1.0], startAngle: 0, endAngle: math.pi * 2 * 0.72).createShader(rect);
    canvas.drawArc(rect, 0, math.pi * 2 * sweep, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => false;
}

class _Spin extends StatefulWidget {
  final Widget Function(AnimationController c) builder;
  final Duration duration;
  const _Spin({Key? key, required this.builder, this.duration = const Duration(milliseconds: 1200)}) : super(key: key);
  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => widget.builder(_c);
}

/// MAIN SPINNER: gradient ring around the graduation cap. Default loader for general use.
class KaidaLoader extends StatelessWidget {
  final double size;
  const KaidaLoader({Key? key, this.size = 84}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    return Center(
      child: SizedBox(
        width: size, height: size,
        child: _Spin(
          builder: (c) => Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: c,
                child: CustomPaint(size: Size(size, size), painter: _ArcPainter(stroke: size * 0.075, track: dark ? Colors.white12 : const Color(0xFFE9E5FF))),
              ),
              Container(
                width: size * 0.66, height: size * 0.66,
                decoration: BoxDecoration(color: dark ? AppTheme.darkSurfaceColor : Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: _kPurple.withOpacity(0.18), blurRadius: 12)]),
                child: Icon(Icons.school_rounded, color: _kPurple, size: size * 0.38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// SMALL SPINNER: for buttons and icons.
class KaidaSmallSpinner extends StatelessWidget {
  final double size;
  final Color? color; // pass Colors.white inside a purple button
  const KaidaSmallSpinner({Key? key, this.size = 22, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (color != null) {
      return SizedBox(width: size, height: size, child: CircularProgressIndicator(strokeWidth: size * 0.11, color: color));
    }
    return SizedBox(
      width: size, height: size,
      child: _Spin(builder: (c) => RotationTransition(turns: c, child: CustomPaint(painter: _ArcPainter(stroke: size * 0.13, track: _dark(context) ? Colors.white12 : const Color(0xFFE9E5FF))))),
    );
  }
}

/// RING LOADER: minimal style.
class KaidaRingLoader extends StatelessWidget {
  final double size;
  const KaidaRingLoader({Key? key, this.size = 56}) : super(key: key);
  @override
  Widget build(BuildContext context) => Center(child: KaidaSmallSpinner(size: size));
}

/// DOTS LOADER: for text and small content.
class KaidaDotsLoader extends StatelessWidget {
  final double dot;
  final Color? color;
  const KaidaDotsLoader({Key? key, this.dot = 11, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = color != null ? [color!, color!, color!] : [_kPurple, _kYellow, _kPurple];
    return _Spin(
      duration: const Duration(milliseconds: 1000),
      builder: (c) => AnimatedBuilder(
        animation: c,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (c.value - i * 0.18) % 1.0;
            final s = 0.6 + 0.4 * math.sin(t * math.pi);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: dot * 0.35),
              child: Transform.scale(scale: s, child: Container(width: dot, height: dot, decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle))),
            );
          }),
        ),
      ),
    );
  }
}

/// LINEAR LOADER: for page loading or upload. Pass value (0..1) for a real progress, or null for endless.
class KaidaLinearLoader extends StatelessWidget {
  final double? value;
  final double height;
  const KaidaLinearLoader({Key? key, this.value, this.height = 8}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final track = _dark(context) ? Colors.white12 : const Color(0xFFE9E5FF);
    Widget bar(double frac) => Container(
          height: height,
          decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(height)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: frac.clamp(0.02, 1.0),
              child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(height), gradient: const LinearGradient(colors: [_kPurple, _kYellow]))),
            ),
          ),
        );
    if (value != null) return bar(value!);
    return _Spin(
      duration: const Duration(milliseconds: 1400),
      builder: (c) => AnimatedBuilder(
        animation: c,
        builder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: Container(
            height: height,
            color: track,
            child: LayoutBuilder(builder: (_, cons) {
              final w = cons.maxWidth;
              final bw = w * 0.38;
              final x = -bw + (w + bw) * c.value;
              return Stack(children: [
                Positioned(left: x, width: bw, top: 0, bottom: 0, child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(height), gradient: const LinearGradient(colors: [_kPurple, _kYellow])))),
              ]);
            }),
          ),
        ),
      ),
    );
  }
}

/// PULSE LOADER: for AI and processing.
class KaidaPulseLoader extends StatelessWidget {
  final double size;
  const KaidaPulseLoader({Key? key, this.size = 90}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size, height: size,
        child: _Spin(
          duration: const Duration(milliseconds: 1600),
          builder: (c) => AnimatedBuilder(
            animation: c,
            builder: (_, __) {
              Widget ring(double phase) {
                final t = (c.value + phase) % 1.0;
                return Opacity(opacity: (1 - t) * 0.5, child: Transform.scale(scale: 0.55 + t * 0.45, child: Container(decoration: const BoxDecoration(color: _kPurple, shape: BoxShape.circle))));
              }
              return Stack(alignment: Alignment.center, children: [
                ring(0), ring(0.5),
                Container(width: size * 0.5, height: size * 0.5, decoration: const BoxDecoration(color: _kPurple, shape: BoxShape.circle), child: Icon(Icons.school_rounded, color: Colors.white, size: size * 0.28)),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

/// FULL SCREEN LOADER: initial page loading or heavy data.
class KaidaFullScreenLoader extends StatelessWidget {
  final String title;
  final String subtitle;
  const KaidaFullScreenLoader({Key? key, this.title = 'Loading...', this.subtitle = 'Please wait a moment'}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    return Container(
      color: dark ? AppTheme.darkBackgroundColor : Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KaidaLoader(size: 120),
            const SizedBox(height: 18),
            Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: dark ? Colors.white : const Color(0xFF16123A))),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 13.5, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

/// SKELETON LOADER: shimmering placeholder rows for course / product lists.
class KaidaSkeletonList extends StatelessWidget {
  final int count;
  final EdgeInsets padding;
  const KaidaSkeletonList({Key? key, this.count = 4, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 20)}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    final base = dark ? Colors.white10 : const Color(0xFFE7E4F7);
    return _Spin(
      duration: const Duration(milliseconds: 1300),
      builder: (c) => AnimatedBuilder(
        animation: c,
        builder: (_, __) {
          final op = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(c.value * math.pi * 2));
          Widget bar(double w, double h) => Container(width: w, height: h, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8)));
          return Opacity(
            opacity: op,
            child: ListView.separated(
              padding: padding,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: count,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: dark ? AppTheme.darkSurfaceColor : Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Row(
                  children: [
                    Container(width: 84, height: 84, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.image_rounded, color: dark ? Colors.white24 : Colors.white, size: 30)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(double.infinity, 12), const SizedBox(height: 9), bar(150, 10), const SizedBox(height: 9), bar(90, 10)])),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// BUTTON LOADER: label + spinner inside a button. Use as the button's child while busy.
class KaidaButtonLoader extends StatelessWidget {
  final String label;
  final Color color;
  const KaidaButtonLoader({Key? key, this.label = 'Please wait...', this.color = Colors.white}) : super(key: key);
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KaidaSmallSpinner(size: 20, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      );
}

/// AI TYPING LOADER: avatar + bouncing dots with a status line.
class KaidaTypingLoader extends StatelessWidget {
  final String text;
  const KaidaTypingLoader({Key? key, this.text = 'Kainuwa AI is thinking...'}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: dark ? AppTheme.darkSurfaceColor : Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: _kPurple.withOpacity(0.18), blurRadius: 8)]),
          child: const Icon(Icons.school_rounded, color: _kPurple, size: 21),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(color: dark ? AppTheme.darkSurfaceColor : const Color(0xFFF1EEFF), borderRadius: BorderRadius.circular(20)),
          child: const KaidaDotsLoader(dot: 8),
        ),
        const SizedBox(width: 10),
        Flexible(child: Text(text, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500))),
      ],
    );
  }
}

/// DOWNLOAD LOADER: file name, size, progress bar and percentage.
class KaidaDownloadLoader extends StatelessWidget {
  final String title;
  final double progress; // 0..1
  final String? sizeText; // e.g. "12.5 MB / 48.0 MB"
  final VoidCallback? onCancel;
  const KaidaDownloadLoader({Key? key, required this.title, required this.progress, this.sizeText, this.onCancel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: dark ? AppTheme.darkSurfaceColor : Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.2 : 0.06), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: _kPurple.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.description_rounded, color: _kPurple)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: dark ? Colors.white : const Color(0xFF16123A))),
                  if (sizeText != null) Text(sizeText!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: KaidaLinearLoader(value: progress, height: 8)),
            const SizedBox(width: 10),
            Text('${(progress * 100).round()}%', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: dark ? Colors.white : const Color(0xFF16123A))),
          ]),
          if (onCancel != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(backgroundColor: dark ? Colors.white10 : const Color(0xFFF1EEFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Cancel Download', style: TextStyle(color: Color(0xFF4A2BE0), fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}