import 'package:flutter/material.dart';
import '../config/app_theme.dart';

enum KaidaAlertKind {
  // errors
  error, noInternet, sessionExpired, paymentFailed, notFound, serverProblem,
  // successes
  success, added, paymentSuccess, profileUpdated, downloadComplete, messageSent,
}

class _Spec {
  final IconData icon;
  final IconData? badge;
  final Color color;
  final String title;
  final String message;
  final String primary;
  final String? secondary;
  const _Spec(this.icon, this.badge, this.color, this.title, this.message, this.primary, this.secondary);
}

const Color _red = Color(0xFFE5484D);
const Color _green = Color(0xFF22B573);
const Color _amber = Color(0xFFF5A524);
const Color _purple = Color(0xFF6B47F5);

const Map<KaidaAlertKind, _Spec> _specs = {
  KaidaAlertKind.error: _Spec(Icons.priority_high_rounded, null, _red, 'Something went wrong', 'We could not complete that. Please try again.', 'Retry', 'Close'),
  KaidaAlertKind.noInternet: _Spec(Icons.wifi_off_rounded, null, _red, 'No internet connection', 'Please check your connection and try again.', 'Retry', 'Close'),
  KaidaAlertKind.sessionExpired: _Spec(Icons.lock_clock_rounded, null, _amber, 'Session expired', 'For your security, please sign in again to continue.', 'Sign in again', 'Close'),
  KaidaAlertKind.paymentFailed: _Spec(Icons.credit_card_off_rounded, null, _red, 'Payment failed', 'Your payment could not be completed. Please try again or use another method.', 'Try again', 'Change method'),
  KaidaAlertKind.notFound: _Spec(Icons.search_off_rounded, null, _purple, 'Not found', 'We could not find what you were looking for.', 'Go Home', 'Retry'),
  KaidaAlertKind.serverProblem: _Spec(Icons.dns_rounded, null, _red, 'Server problem', 'Our servers are having a moment. Please try again shortly.', 'Retry', 'Close'),
  KaidaAlertKind.success: _Spec(Icons.check_rounded, null, _green, 'Successful', 'Your action was completed successfully.', 'Got it', null),
  KaidaAlertKind.added: _Spec(Icons.shopping_bag_rounded, Icons.check_circle_rounded, _green, 'Added', 'The item was added successfully.', 'View', 'Continue'),
  KaidaAlertKind.paymentSuccess: _Spec(Icons.receipt_long_rounded, Icons.check_circle_rounded, _green, 'Payment successful', 'Thank you! Your payment was received.', 'View details', 'Continue'),
  KaidaAlertKind.profileUpdated: _Spec(Icons.person_rounded, Icons.check_circle_rounded, _green, 'Profile updated', 'Your profile has been updated.', 'View profile', 'Close'),
  KaidaAlertKind.downloadComplete: _Spec(Icons.insert_drive_file_rounded, Icons.check_circle_rounded, _green, 'Download complete', 'Your file is ready to open.', 'Open file', 'Continue'),
  KaidaAlertKind.messageSent: _Spec(Icons.mark_email_read_rounded, null, _green, 'Message sent', 'Your message has been sent.', 'Ok', null),
};

class KaidaAlert {
  // ---------------------------------------------------------------------------
  // Friendly error mapping. Raw technical text is NEVER shown to the user.
  // ---------------------------------------------------------------------------
  static final RegExp _technical = RegExp(
    r'(socketexception|clientexception|timeoutexception|handshakeexception|httpexception|formatexception|'
    r'typeerror|nosuchmethod|exception|stack ?trace|errno|uri=|https?://|connection (timed out|refused|reset|closed|error)|'
    r'timed out|failed host lookup|software caused|null check|is not a subtype|unexpected character|'
    r'<!doctype|<html|\bat \S+\.dart|\bdart:|xmlhttprequest|certificate)',
    caseSensitive: false,
  );

  static bool isTechnical(String? s) => s != null && _technical.hasMatch(s);

  /// Decide the error kind from any raw text / exception.
  static KaidaAlertKind kindFor(Object? raw) {
    final t = (raw ?? '').toString().toLowerCase();
    if (t.contains('socket') || t.contains('timed out') || t.contains('timeout') || t.contains('host lookup') ||
        t.contains('connection') || t.contains('network') || t.contains('internet') || t.contains('clientexception')) {
      return KaidaAlertKind.noInternet;
    }
    if (t.contains('401') || t.contains('unauthorized') || t.contains('session') || t.contains('token')) {
      return KaidaAlertKind.sessionExpired;
    }
    if (t.contains('404') || t.contains('not found')) return KaidaAlertKind.notFound;
    if (t.contains('500') || t.contains('502') || t.contains('503') || t.contains('server') || t.contains('formatexception') || t.contains('<html')) {
      return KaidaAlertKind.serverProblem;
    }
    if (t.contains('payment')) return KaidaAlertKind.paymentFailed;
    return KaidaAlertKind.error;
  }

  /// Safe, human text for anything (use for SnackBars and inline text too).
  /// Messages written by our own server (short, plain sentences) pass through;
  /// anything technical is replaced.
  static String friendly(Object? raw, {String? fallback}) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty || isTechnical(s) || s.length > 160) {
      return fallback ?? _specs[kindFor(s)]!.message;
    }
    return s;
  }

  // ---------------------------------------------------------------------------
  // Backwards compatible entry point used across the app.
  // ---------------------------------------------------------------------------
  static Future<void> showModal({
    required BuildContext context,
    required String title,
    required String message,
    bool isError = false,
    VoidCallback? onConfirm,
  }) {
    if (isError) {
      final technical = isTechnical(title) || isTechnical(message);
      var kind = technical ? kindFor('$title $message') : KaidaAlertKind.error;
      if (!technical) {
        final k = kindFor('$title $message');
        if (k == KaidaAlertKind.noInternet || k == KaidaAlertKind.serverProblem) kind = k;
      }
      final spec = _specs[kind]!;
      return show(
        context,
        kind: kind,
        title: technical ? spec.title : (kind == KaidaAlertKind.error ? title : spec.title),
        message: technical ? spec.message : friendly(message),
        primaryLabel: 'Got it',
        secondaryLabel: null,
        onPrimary: onConfirm,
      );
    }
    return show(context, kind: KaidaAlertKind.success, title: title, message: message, primaryLabel: 'Got it', onPrimary: onConfirm);
  }

  /// Show an error from any exception / raw response. Technical text is hidden.
  static Future<void> showError(BuildContext context, {Object? error, String? title, String? message, VoidCallback? onRetry}) {
    final kind = kindFor(error ?? message);
    final spec = _specs[kind]!;
    final custom = message != null && !isTechnical(message) && message.trim().isNotEmpty;
    return show(
      context,
      kind: kind,
      title: title ?? spec.title,
      message: custom ? message : spec.message,
      onPrimary: onRetry,
      primaryLabel: onRetry == null ? 'Got it' : spec.primary,
      secondaryLabel: onRetry == null ? null : 'Close',
    );
  }

  static Future<void> showNoInternet(BuildContext context, {VoidCallback? onRetry}) =>
      show(context, kind: KaidaAlertKind.noInternet, onPrimary: onRetry);

  static Future<void> showSessionExpired(BuildContext context, {VoidCallback? onSignIn}) =>
      show(context, kind: KaidaAlertKind.sessionExpired, onPrimary: onSignIn);

  static Future<void> showPaymentFailed(BuildContext context, {VoidCallback? onRetry, VoidCallback? onChangeMethod}) =>
      show(context, kind: KaidaAlertKind.paymentFailed, onPrimary: onRetry, onSecondary: onChangeMethod);

  static Future<void> showSuccess(BuildContext context, {String? title, String? message, VoidCallback? onOk}) =>
      show(context, kind: KaidaAlertKind.success, title: title, message: message, onPrimary: onOk);

  static Future<void> showAdded(BuildContext context, {String? title, String? message, VoidCallback? onView}) =>
      show(context, kind: KaidaAlertKind.added, title: title, message: message, onPrimary: onView);

  static Future<void> showProfileUpdated(BuildContext context, {VoidCallback? onView}) =>
      show(context, kind: KaidaAlertKind.profileUpdated, onPrimary: onView);

  static Future<void> showDownloadComplete(BuildContext context, {String? message, VoidCallback? onOpen}) =>
      show(context, kind: KaidaAlertKind.downloadComplete, message: message, onPrimary: onOpen);

  static Future<void> showMessageSent(BuildContext context, {String? message}) =>
      show(context, kind: KaidaAlertKind.messageSent, message: message);

  // ---------------------------------------------------------------------------
  static Future<void> show(
    BuildContext context, {
    required KaidaAlertKind kind,
    String? title,
    String? message,
    String? primaryLabel,
    String? secondaryLabel,
    VoidCallback? onPrimary,
    VoidCallback? onSecondary,
  }) {
    final spec = _specs[kind]!;
    final pLabel = primaryLabel ?? spec.primary;
    final sLabel = secondaryLabel ?? spec.secondary;
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        const primaryColor = AppTheme.primaryColor;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          backgroundColor: dark ? AppTheme.darkSurfaceColor : Colors.white,
          elevation: 0,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _illustration(spec, dark),
                    const SizedBox(height: 18),
                    Text(title ?? spec.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: dark ? Colors.white : const Color(0xFF16123A))),
                    const SizedBox(height: 8),
                    Text(message ?? spec.message, textAlign: TextAlign.center, style: TextStyle(fontSize: 14.5, height: 1.45, color: dark ? Colors.grey.shade400 : Colors.grey.shade600)),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          if (onPrimary != null) onPrimary();
                        },
                        child: Text(pLabel, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    if (sLabel != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(side: BorderSide(color: dark ? Colors.white24 : const Color(0xFFD9D2FF)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            if (onSecondary != null) onSecondary();
                          },
                          child: Text(sLabel, style: TextStyle(color: dark ? Colors.white : const Color(0xFF4A2BE0), fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                top: 10, right: 10,
                child: InkWell(
                  onTap: () => Navigator.of(ctx).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: dark ? Colors.white10 : const Color(0xFFF1EEFF), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 18, color: dark ? Colors.white70 : const Color(0xFF4A2BE0)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _illustration(_Spec s, bool dark) {
    return SizedBox(
      width: 112, height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 112, height: 112, decoration: BoxDecoration(color: s.color.withOpacity(dark ? 0.14 : 0.10), shape: BoxShape.circle)),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: s.color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: s.color.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))]),
            child: Icon(s.icon, color: Colors.white, size: 40),
          ),
          if (s.badge != null)
            Positioned(
              right: 8, bottom: 8,
              child: Container(
                decoration: BoxDecoration(color: dark ? AppTheme.darkSurfaceColor : Colors.white, shape: BoxShape.circle),
                child: Icon(s.badge, color: _green, size: 30),
              ),
            ),
        ],
      ),
    );
  }
}