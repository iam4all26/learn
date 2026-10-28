import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../widgets/kaida_loader.dart';

/// Shows a small "Opening..." box while something loads, and ignores extra taps while it is busy,
/// so a page can never be opened twice by a user who taps again and again.
class KaidaBusy {
  static bool _busy = false;
  static bool get isBusy => _busy;

  /// Runs [job] with a loading box on screen. Returns null (and does nothing) if another job is already running.
  static Future<T?> withLoader<T>(BuildContext context, Future<T> Function() job, {String message = 'Opening...'}) async {
    if (_busy) return null;
    _busy = true;
    final navigator = Navigator.of(context, rootNavigator: true);
    bool dialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
            decoration: BoxDecoration(
              color: Theme.of(ctx).brightness == Brightness.dark ? AppTheme.darkSurfaceColor : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KaidaLoader(size: 46),
                const SizedBox(height: 14),
                Text(message, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white : Colors.black87, decoration: TextDecoration.none)),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => dialogOpen = false);
    try {
      return await job();
    } finally {
      if (dialogOpen && navigator.canPop()) navigator.pop();
      _busy = false;
    }
  }
}