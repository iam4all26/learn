import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/app_theme.dart';
import '../widgets/kaida_loader.dart';
import '../widgets/page_header.dart';
import 'main_layout.dart';

class WebViewScreen extends StatefulWidget {
  final String title;
  final String url;
  const WebViewScreen({Key? key, required this.title, required this.url}) : super(key: key);

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _canBack = false;
  bool _canForward = false;
  String _host = '';
  bool _secure = true;

  @override
  void initState() {
    super.initState();
    _setAddress(widget.url);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) { _setAddress(url); if (mounted) setState(() { _isLoading = true; _hasError = false; }); },
          onPageFinished: (String url) async { _setAddress(url); await _refreshNav(); if (mounted) setState(() => _isLoading = false); },
          onWebResourceError: (WebResourceError error) { if (mounted && (error.isForMainFrame ?? true)) setState(() { _isLoading = false; _hasError = true; }); },
          onHttpError: (HttpResponseError error) { if (mounted) setState(() { _isLoading = false; _hasError = true; }); },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  // Only the site name is shown. The full address can hold a one-time sign-in code, so it is never displayed.
  void _setAddress(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return;
    if (mounted) setState(() { _host = u.host; _secure = u.scheme == 'https'; });
  }

  Future<void> _refreshNav() async {
    final b = await _controller.canGoBack();
    final f = await _controller.canGoForward();
    if (mounted) setState(() { _canBack = b; _canForward = f; });
  }

  Future<void> _reload() async {
    setState(() { _hasError = false; _isLoading = true; });
    await _controller.reload();
  }

  Widget _navBtn(IconData icon, bool enabled, VoidCallback onTap, bool isDark) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 22, color: enabled ? (isDark ? Colors.white : Colors.black87) : Colors.grey.shade400),
      onPressed: enabled ? onTap : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : Colors.white,
      body: Column(
        children: [
          PageHeader(
            title: widget.title,
            subtitle: 'Opened inside the app',
            bottomPadding: 14,
            actions: [
              PageHeader.circleButton(Icons.home_rounded, () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainLayout()), (route) => false)),
            ],
          ),
          // browser bar
          Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                _navBtn(Icons.arrow_back_rounded, _canBack, () async { await _controller.goBack(); _refreshNav(); }, isDark),
                _navBtn(Icons.arrow_forward_rounded, _canForward, () async { await _controller.goForward(); _refreshNav(); }, isDark),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.07) : const Color(0xFFF3F2F8), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Icon(_secure ? Icons.lock_rounded : Icons.lock_open_rounded, size: 16, color: _secure ? const Color(0xFF22A06B) : Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_host.isEmpty ? '...' : _host, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(visualDensity: VisualDensity.compact, icon: Icon(Icons.refresh_rounded, size: 23, color: isDark ? Colors.white : Colors.black87), onPressed: _reload),
              ],
            ),
          ),
          if (_isLoading && !_hasError) const LinearProgressIndicator(minHeight: 2.5, color: AppTheme.primaryColor, backgroundColor: Colors.transparent),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading && !_hasError && !_canBack)
                  Container(color: isDark ? AppTheme.darkBackgroundColor : Colors.white, child: const Center(child: KaidaLoader())),
                if (_hasError)
                  Container(
                    color: isDark ? AppTheme.darkBackgroundColor : Colors.white,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 80, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text('Connection Failed', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: () { setState(() { _hasError = false; _isLoading = true; }); _controller.loadRequest(Uri.parse(widget.url)); },
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                            label: const Text('Try Again', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}