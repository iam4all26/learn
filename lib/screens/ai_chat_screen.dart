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
  ChatMessage({required this.text, required this.isUser, this.isError = false});
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
  
  List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> _sessions = [];
  List<String> _currentSuggestions = []; 
  
  bool _isTyping = false;
  bool _isLoadingHistory = false;
  String _lastFailedPrompt = ''; 
  
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<String> _quickStarters = [
    'I don\'t know what to learn. Help me!',
    'Suggest a course for beginners.',
    'How do I monetize my skills?'
  ];

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');
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
            loaded.add(ChatMessage(text: text, isUser: msg['role'] == 'user'));
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: AppTheme.primaryColor, size: 22),
            const SizedBox(width: 8),
            Text('Kainuwa AI', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: isDark ? Colors.white : Colors.black),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          )
        ],
      ),
      endDrawer: _buildHistoryDrawer(isDark),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingHistory 
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : _messages.isEmpty 
                  ? _buildWelcomeScreen(isDark)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => _buildMessageBubble(_messages[index], isDark),
                    ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: const Text('Kainuwa AI is thinking...', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                ),
              ),
            ),
            
          if (_currentSuggestions.isNotEmpty && !_isTyping && _messages.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: _currentSuggestions.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(_currentSuggestions[index], style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onPressed: () => _handleSubmitted(_currentSuggestions[index]),
                  ),
                ),
              ),
            ),
            
          _buildInputArea(isDark),
        ],
      ),
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

  Widget _buildWelcomeScreen(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome, size: 48, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 24),
            Text('Welcome to Kainuwa AI', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('I can help you discover your path, choose the right courses, and learn how to monetize your skills.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, height: 1.5)),
            const SizedBox(height: 40),
            Wrap(
              spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
              children: _quickStarters.map((text) => _buildQuickStarter(text)).toList(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStarter(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () => _handleSubmitted(text),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isDark) {
    // CRITICAL FIX: Explicitly rendering the Retry Outline Button if an error occurs
    if (message.isError) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent, 
            side: const BorderSide(color: Colors.redAccent, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Flexible(child: Text(message.text, style: const TextStyle(fontWeight: FontWeight.bold))),
          onPressed: () => _handleSubmitted(_lastFailedPrompt, isRetry: true),
        ),
      );
    }

    final bgColor = message.isUser ? AppTheme.primaryColor : (isDark ? AppTheme.darkSurfaceColor : Colors.white);
    final textColor = message.isUser ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final align = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(message.isUser ? 20 : 0),
      bottomRight: Radius.circular(message.isUser ? 0 : 20),
    );
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!message.isUser)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: borderRadius,
                    boxShadow: [if (!message.isUser) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]
                  ),
                  child: message.isUser
                      ? Text(message.text, style: TextStyle(color: textColor, fontSize: 15, height: 1.4))
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
                          onTapLink: (text, href, title) async {
                            if (href != null && href.startsWith('kaida://course/')) {
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
                          },
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100, borderRadius: BorderRadius.circular(24)),
                child: TextField(
                  controller: _textController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Message Kainuwa AI...',
                    hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  onSubmitted: (val) => _handleSubmitted(val),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _handleSubmitted(_textController.text),
              child: Container(
                height: 48, width: 48,
                decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}