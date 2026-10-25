import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import 'catalog_screen.dart';
import 'item_details_screen.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final DateTime time;
  ChatMessage({required this.text, required this.isUser, this.isError = false, DateTime? time}) : time = time ?? DateTime.now();
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({Key? key}) : super(key: key);

  @override
  _AiChatScreenState createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  int? _userId;
  int? _currentSessionId;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  String? _userAvatar;
  
  List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> _sessions = [];
  List<String> _currentSuggestions = []; 
  
  bool _isTyping = false;
  bool _isLoadingHistory = false;
  String _lastFailedPrompt = ''; 
  
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> _commonQuestions = [
    {'icon': Icons.play_circle_fill_rounded, 'color': Color(0xFF7351FF), 'text': 'Recommend a short course for me'},
    {'icon': Icons.bar_chart_rounded, 'color': Color(0xFF2F80ED), 'text': 'How does digital marketing work?'},
    {'icon': Icons.palette_rounded, 'color': Color(0xFFFFB020), 'text': 'How do I design a thumbnail in Canva?'},
    {'icon': Icons.hub_rounded, 'color': Color(0xFFF97316), 'text': 'What is blockchain?'},
    {'icon': Icons.code_rounded, 'color': Color(0xFF7351FF), 'text': 'Write me a simple HTML website'},
    {'icon': Icons.smart_display_rounded, 'color': Color(0xFFEF4444), 'text': 'How do I start a YouTube channel?'},
  ];

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');
    final av = prefs.getString('avatar_url') ?? '';
    if (av.isNotEmpty && mounted) setState(() => _userAvatar = av.startsWith('http') ? av : 'https://academy.kainuwa.africa/$av');
    if (_userId != null) {
      await _loadSessions();
    } else {
      setState(() => _messages.add(ChatMessage(text: "Please log in to chat with Kainuwa AI.", isUser: false)));
    }
  }

  Future<void> _loadSessions() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/ai_chat.php?action=get_sessions&user_id=$_userId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && mounted) {
          setState(() => _sessions = List<Map<String, dynamic>>.from(data['data']));
        }
      }
    } catch (e) {
      debugPrint("Failed to load sessions.");
    }
  }

  Future<void> _loadHistory(int sessionId) async {
    setState(() {
      _isLoadingHistory = true;
      _currentSessionId = sessionId;
      _messages.clear();
      _currentSuggestions.clear();
    });
    
    if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
      Navigator.pop(context); 
    }

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/ai_chat.php?action=get_history&session_id=$sessionId&user_id=$_userId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null && mounted) {
          List<ChatMessage> loaded = [];
          for (var msg in data['data']) {
            String text = msg['message'].toString();
            if (text.contains('||')) text = text.split('||')[0].trim();
            loaded.add(ChatMessage(text: text, isUser: msg['role'] == 'user', time: DateTime.tryParse((msg['created_at'] ?? '').toString())));
          }
          setState(() {
            _messages = loaded;
            _isLoadingHistory = false;
          });
          _scrollToBottom();
        } else {
          throw Exception("Unknown load error");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
          _messages.add(ChatMessage(text: "Could not load history.", isUser: false));
        });
      }
    }
  }

  Future<void> _deleteSession(int sessionId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/ai_chat.php?action=delete_session'),
        body: {'user_id': _userId.toString(), 'session_id': sessionId.toString()},
      );
      if (response.statusCode == 200) {
        if (_currentSessionId == sessionId) _startNewChat();
        else await _loadSessions();
      }
    } catch (e) {
      debugPrint("Failed to delete session.");
    }
  }

  void _startNewChat() {
    setState(() {
      _currentSessionId = null;
      _messages.clear();
      _currentSuggestions.clear();
    });
    if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleSubmitted(String text, {bool isRetry = false}) async {
    if (text.trim().isEmpty || _userId == null) return;

    _textController.clear();
    setState(() {
      _messages.removeWhere((m) => m.isError);
      if (!isRetry) _messages.add(ChatMessage(text: text, isUser: true));
      
      _currentSuggestions.clear();
      _isTyping = true;
      _lastFailedPrompt = text; 
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/ai_chat.php?action=chat'),
        body: {
          'user_id': _userId.toString(),
          'session_id': _currentSessionId?.toString() ?? '0',
          'message': text,
        },
      ).timeout(const Duration(seconds: 130)); // Expanded client wait time

      if (response.statusCode == 200 && !response.body.trim().startsWith('<')) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          String replyText = data['message'].toString();
          List<String> suggestions = [];
          
          if (replyText.contains('||')) {
            final parts = replyText.split('||');
            replyText = parts[0].trim(); 
            for (int i = 1; i < parts.length; i++) {
              if (parts[i].trim().isNotEmpty) suggestions.add(parts[i].trim());
            }
          }

          if (mounted) {
            setState(() {
              _currentSessionId = int.tryParse(data['session_id'].toString());
              _messages.add(ChatMessage(text: replyText, isUser: false));
              _currentSuggestions = suggestions;
              _isTyping = false;
            });
            _scrollToBottom();
            await _loadSessions();
          }
        } else {
          throw Exception(data['message'] ?? "Error");
        }
      } else {
        // 429 (too many messages) and similar answers carry a readable message in the body
        String serverMsg = "Server Error";
        try {
          final body = json.decode(response.body);
          if (body is Map && body['message'] != null) serverMsg = body['message'].toString();
        } catch (_) {}
        throw Exception(serverMsg);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          String errText = "Could not reach Kainuwa AI. Please check your internet connection.";
          String cleanError = e.toString().replaceAll('Exception: ', '').trim();
          // Show the server's own message (for example "The AI is not available right now ...") instead of hiding it
          if (cleanError.isNotEmpty && cleanError != 'Server Error' && !cleanError.contains('SocketException') && !cleanError.contains('ClientException')) {
              errText = cleanError;
          } else if (cleanError == 'Server Error') {
              errText = "Kainuwa AI had a server problem. Please try again.";
          }
          // CRITICAL FIX: Pushing the precise error message with isError = true to trigger the Retry UI
          _messages.add(ChatMessage(text: "$errText Tap to retry.", isUser: false, isError: true));
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _prefill(String lead) {
    _textController.text = lead;
    _textController.selection = TextSelection.fromPosition(TextPosition(offset: lead.length));
    _inputFocus.requestFocus();
  }

  Future<void> _openCourseLink(String? href) async {
    if (href == null || !href.startsWith('kaida://course/')) return;
    final slug = href.replaceAll('kaida://course/', '');
    showDialog(context: context, barrierDismissible: false, builder: (BuildContext c) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)));
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/catalog.php?action=courses'));
      Navigator.pop(context);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          List<dynamic> items = data['data'];
          var courseData = items.firstWhere((item) => item['slug'] == slug, orElse: () => null);
          if (courseData != null) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailsScreen(item: CatalogItem.fromJson(courseData, 'courses'))));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Course not found or unavailable.')));
          }
        }
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to fetch course details.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showSuggestions = _currentSuggestions.isNotEmpty && !_isTyping && _messages.isNotEmpty;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : Colors.white,
      endDrawer: _buildHistoryDrawer(isDark),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              children: [
                _buildHero(isDark),
                if (_messages.isEmpty && !_isLoadingHistory) _buildCommonQuestions(isDark),
                if (_isLoadingHistory)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(children: _messages.map((m) => _buildMessageBubble(m, isDark)).toList()),
                ),
                if (_isTyping)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Row(
                      children: [
                        _robotAvatar(34),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : const Color(0xFFEDEBF7), borderRadius: BorderRadius.circular(18)),
                          child: Text('Kainuwa AI is thinking...', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                        ),
                      ],
                    ),
                  ),
                if (showSuggestions)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(58, 0, 16, 12),
                    child: Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _currentSuggestions.map((sug) => GestureDetector(
                            onTap: () => _handleSubmitted(sug),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.6), width: 1.3),
                              ),
                              child: Text(sug, style: const TextStyle(fontSize: 12.5, color: AppTheme.primaryColor, fontWeight: FontWeight.w700)),
                            ),
                          )).toList(),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          _buildInputArea(isDark),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HERO: logo row, mascot, title and the 4 quick-action tiles
  // ---------------------------------------------------------------------------
  Widget _buildHero(bool isDark) {
    final topPad = MediaQuery.of(context).padding.top;
    return Padding(
      padding: const EdgeInsets.only(bottom: 52),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 64),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF3A22C4), Color(0xFF6B47F5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(38)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.asset('assets/kainuwa_logo.png', width: 36, height: 36, fit: BoxFit.contain)),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Kainuwa Academy', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
                    GestureDetector(
                      onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), shape: BoxShape.circle),
                        child: const Icon(Icons.history_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                      onSelected: (v) { if (v == 'new') _startNewChat(); },
                      itemBuilder: (_) => const [PopupMenuItem(value: 'new', child: Text('Start new chat'))],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 118, height: 140,
                      child: Stack(
                        children: [
                          const Positioned(left: 0, bottom: 0, child: CustomPaint(size: Size(110, 132), painter: _MascotPainter())),
                          Positioned(
                            right: 0, top: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (_) => Container(margin: const EdgeInsets.symmetric(horizontal: 1.5), width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF5B34F0), shape: BoxShape.circle)))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Row(
                            children: [
                              Flexible(child: Text('Kainuwa AI', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.8))),
                              SizedBox(width: 6),
                              Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFC21A), size: 22),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text('Ask me anything you want to learn', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.2)),
                          SizedBox(height: 6),
                          Text('Kainuwa AI helps you understand lessons, answers your questions and guides you through all your courses.', style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Quick action tiles overlapping the curve
          Positioned(
            left: 12, right: 12, bottom: -44,
            child: Row(
              children: [
                _heroTile(Icons.chat_bubble_rounded, const Color(0xFF7351FF), 'Ask\nQuestions', () => _prefill('I have a question: '), isDark),
                _heroTile(Icons.description_rounded, const Color(0xFFFFB020), 'Explain\nLessons', () => _prefill('Please explain this lesson to me: '), isDark),
                _heroTile(Icons.lightbulb_rounded, const Color(0xFFEF4444), 'Get\nAdvice', () => _prefill('I need advice on: '), isDark),
                _heroTile(Icons.build_rounded, const Color(0xFF22C55E), 'Practical\nTasks', () => _prefill('Give me a practical task to practise: '), isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroTile(IconData icon, Color color, String label, VoidCallback onTap, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.12), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Column(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 7),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommonQuestions(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(left: 4, bottom: 10), child: Text('Common Questions', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900))),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _commonQuestions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, mainAxisExtent: 58),
            itemBuilder: (context, i) {
              final q = _commonQuestions[i];
              final Color c = q['color'] as Color;
              return GestureDetector(
                onTap: () => _handleSubmitted(q['text'] as String),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? Colors.grey.shade800 : const Color(0xFFE8E6F5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: c.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
                        child: Icon(q['icon'] as IconData, color: c, size: 19),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(q['text'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2))),
                      Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.grey.shade500),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _robotAvatar(double size) {
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFF8B6CFF), Color(0xFF5B34F0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: size * 0.58),
    );
  }

  Widget _buildHistoryDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark ? AppTheme.darkSurfaceColor : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              color: Colors.transparent,
              child: Text('Chat History', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
              title: const Text('Start New Chat', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              onTap: _startNewChat,
            ),
            const Divider(),
            Expanded(
              child: _sessions.isEmpty
                ? Center(child: Text('No previous chats', style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey)))
                : ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      return ListTile(
                        leading: Icon(Icons.chat_bubble_outline, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        title: Text(session['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                        onTap: () => _loadHistory(int.parse(session['id'].toString())),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red, size: 20),
                          onPressed: () => _deleteSession(int.parse(session['id'].toString())),
                        ),
                      );
                    },
                  ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isDark) {
    if (message.isError) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Flexible(child: Text(message.text, style: const TextStyle(fontWeight: FontWeight.bold))),
          onPressed: () => _handleSubmitted(_lastFailedPrompt, isRetry: true),
        ),
      );
    }

    final isUser = message.isUser;
    final bgColor = isUser ? AppTheme.primaryColor : (isDark ? AppTheme.darkSurfaceColor : const Color(0xFFEDEBF7));
    final textColor = isUser ? Colors.white : (isDark ? Colors.white : const Color(0xFF1E1E2D));
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isUser ? 20 : 6),
      bottomRight: Radius.circular(isUser ? 6 : 20),
    );

    final timeRow = Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(_hhmm(message.time), style: TextStyle(fontSize: 10.5, color: isUser ? Colors.white70 : Colors.grey.shade500)),
          if (isUser) ...[const SizedBox(width: 4), const Icon(Icons.done_all_rounded, size: 14, color: Colors.white70)],
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[_robotAvatar(36), const SizedBox(width: 8)],
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(color: bgColor, borderRadius: radius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  isUser
                      ? Align(alignment: Alignment.centerLeft, child: Text(message.text, style: TextStyle(color: textColor, fontSize: 15, height: 1.4)))
                      : MarkdownBody(
                          data: message.text,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(color: textColor, fontSize: 15, height: 1.4),
                            strong: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                            h1: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
                            h2: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                            listBullet: TextStyle(color: textColor),
                            a: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                          ),
                          onTapLink: (text, href, title) => _openCourseLink(href),
                        ),
                  timeRow,
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
              backgroundImage: (_userAvatar != null && _userAvatar!.isNotEmpty) ? NetworkImage(_userAvatar!) : null,
              child: (_userAvatar == null || _userAvatar!.isEmpty) ? const Icon(Icons.person_rounded, color: AppTheme.primaryColor, size: 20) : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: isDark ? Colors.grey.shade700 : const Color(0xFFDAD6F2)),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _inputFocus,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Type your question here...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onSubmitted: (val) => _handleSubmitted(val),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _handleSubmitted(_textController.text),
            child: Container(
              height: 50, width: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF7B5CFF), Color(0xFF5B34F0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly robot mascot with graduation cap, drawn as vector.
class _MascotPainter extends CustomPainter {
  const _MascotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 130, sy = size.height / 150;
    canvas.scale(sx, sy);
    final white = Paint()..color = Colors.white;
    final shade = Paint()..color = const Color(0xFFE4E0FA);
    final navy = Paint()..color = const Color(0xFF171B4A);
    final cap = Paint()..color = const Color(0xFF1C1B3D);
    final cyan = const Color(0xFF38E8FF);

    // Body
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(32, 108, 98, 150), const Radius.circular(22)), shade);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(36, 104, 94, 146), const Radius.circular(20)), white);
    // Ear pads
    final pad = Paint()..color = const Color(0xFF7B5CFF);
    canvas.drawCircle(const Offset(10, 82), 9, pad);
    canvas.drawCircle(const Offset(120, 82), 9, pad);
    // Head
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(10, 44, 120, 124), const Radius.circular(40)), shade);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(12, 42, 118, 120), const Radius.circular(38)), white);
    // Visor
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(24, 54, 106, 108), const Radius.circular(26)), navy);
    // Eyes (happy arcs) with glow
    for (final cx in [48.0, 82.0]) {
      final rect = Rect.fromCenter(center: Offset(cx, 84), width: 22, height: 20);
      canvas.drawArc(rect, 3.14159, 3.14159, false, Paint()..color = cyan.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawArc(rect, 3.14159, 3.14159, false, Paint()..color = cyan..style = PaintingStyle.stroke..strokeWidth = 4.5..strokeCap = StrokeCap.round);
    }
    // Smile
    canvas.drawArc(Rect.fromCenter(center: const Offset(65, 94), width: 16, height: 10), 0, 3.14159, false, Paint()..color = cyan..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
    // Graduation cap
    final board = Path()
      ..moveTo(65, 8)
      ..lineTo(122, 28)
      ..lineTo(65, 46)
      ..lineTo(8, 28)
      ..close();
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(34, 30, 96, 52), const Radius.circular(10)), cap);
    canvas.drawPath(board, cap);
    canvas.drawPath(board, Paint()..color = Colors.white.withOpacity(0.08));
    // Tassel
    final tassel = Paint()..color = const Color(0xFFFFC21A)..strokeWidth = 3..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(65, 27), const Offset(116, 31), tassel);
    canvas.drawLine(const Offset(116, 31), const Offset(116, 60), tassel);
    canvas.drawCircle(const Offset(116, 62), 4, Paint()..color = const Color(0xFFFFC21A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
