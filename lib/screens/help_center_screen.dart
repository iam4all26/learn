import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../widgets/kaida_loader.dart';
import '../widgets/page_header.dart';
import '../widgets/kaida_empty_state.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({Key? key}) : super(key: key);

  @override
  _HelpCenterScreenState createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  int _tab = 0; // 0 = FAQ, 1 = Contact Us
  bool _isLoading = true;
  String _searchQuery = '';

  Map<String, List<dynamic>> _faqs = {};
  Map<String, String> _contactInfo = {};

  static const List<Color> _palette = [
    Color(0xFF7351FF), Color(0xFF22A06B), Color(0xFFF2711C), Color(0xFF2F80ED), Color(0xFFE5489B), Color(0xFFFFB020),
  ];
  static const List<IconData> _icons = [
    Icons.school_rounded, Icons.shopping_bag_rounded, Icons.payments_rounded, Icons.person_rounded, Icons.settings_rounded, Icons.help_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _fetchHelpData();
  }

  Future<void> _fetchHelpData() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.helpCenter));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && mounted) {
          final faqs = <String, List<dynamic>>{};
          (data['data']['faqs'] as Map).forEach((k, v) => faqs[k.toString()] = List<dynamic>.from(v as List));
          final contact = <String, String>{};
          (data['data']['contact'] as Map).forEach((k, v) => contact[k.toString()] = v?.toString() ?? '');
          setState(() {
            _faqs = faqs;
            _contactInfo = contact;
          });
        }
      }
    } catch (e) {
      debugPrint("Help Center Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _clean(String s) {
    return s
        .replaceAll(RegExp(r'<br\s*/?>|</p>|</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  Map<String, List<dynamic>> get _filteredFaqs {
    if (_searchQuery.isEmpty) return _faqs;
    final filtered = <String, List<dynamic>>{};
    final query = _searchQuery.toLowerCase();
    _faqs.forEach((category, questions) {
      final matches = questions.where((q) {
        final qText = _clean(q['question']?.toString() ?? '').toLowerCase();
        final aText = _clean(q['answer']?.toString() ?? '').toLowerCase();
        return qText.contains(query) || aText.contains(query);
      }).toList();
      if (matches.isNotEmpty) filtered[category] = matches;
    });
    return filtered;
  }

  Future<void> _launch(String urlString, {bool isEmail = false}) async {
    if (urlString.isEmpty) return;
    try {
      if (isEmail) {
        await launchUrl(Uri(scheme: 'mailto', path: urlString));
      } else {
        await launchUrl(Uri.parse(urlString), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open application.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : const Color(0xFFF6F5FB),
      body: Column(
        children: [
          PageHeader(
            title: 'Help Center',
            subtitle: 'We are here to help you',
            illustration: Icons.support_agent_rounded,
            bottomPadding: 20,
            bottom: _segmented(),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: KaidaLoader())
                : (_tab == 0 ? _buildFaqTab(isDark) : _buildContactTab(isDark)),
          ),
        ],
      ),
    );
  }

  Widget _segmented() {
    Widget seg(String label, int i) {
      final active = _tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(26)),
            child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: active ? const Color(0xFF4A2BE0) : Colors.white))),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(30)),
      child: Row(children: [seg('FAQ', 0), seg('Contact Us', 1)]),
    );
  }

  Widget _buildFaqTab(bool isDark) {
    final displayed = _filteredFaqs;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      physics: const BouncingScrollPhysics(),
      children: [
        TextField(
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search for help...',
            hintStyle: TextStyle(color: Colors.grey.shade500),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500),
            filled: true,
            fillColor: isDark ? AppTheme.darkSurfaceColor : Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        const SizedBox(height: 18),
        if (displayed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: KaidaEmptyState(kind: _faqs.isEmpty ? KaidaEmptyKind.generic : KaidaEmptyKind.search, title: _faqs.isEmpty ? 'No FAQs yet' : null, message: _faqs.isEmpty ? 'Answers to common questions will appear here.' : null),
          )
        else
          for (int c = 0; c < displayed.length; c++) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
              child: Text(displayed.keys.elementAt(c), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
            ),
            for (int q = 0; q < displayed.values.elementAt(c).length; q++)
              _faqTile(displayed.values.elementAt(c)[q], (c + q) % _palette.length, isDark),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 8),
        _questionCard(isDark),
      ],
    );
  }

  Widget _faqTile(dynamic q, int colorIndex, bool isDark) {
    final color = _palette[colorIndex];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          iconColor: AppTheme.primaryColor,
          collapsedIconColor: Colors.grey.shade500,
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(_icons[colorIndex % _icons.length], color: color, size: 21),
          ),
          title: Text(_clean(q['question']?.toString() ?? ''), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: isDark ? Colors.white : Colors.black87)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(_clean(q['answer']?.toString() ?? ''), style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, fontSize: 13.5, height: 1.55)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionCard(bool isDark) {
    final email = _contactInfo['email'] ?? 'support@kainuwa.africa';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : const Color(0xFFF0EDFF), borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.chat_bubble_rounded, color: AppTheme.primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Can't find your answer?", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 2),
                Text('Send us a question and we will get back to you.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _launch(email, isEmail: true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            child: const Text('Send', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTab(bool isDark) {
    final email = _contactInfo['email'] ?? 'support@kainuwa.africa';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      physics: const BouncingScrollPhysics(),
      children: [
        Text('How can we help you?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 6),
        Text('Choose a way to reach us. We are happy to help.', style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600, height: 1.4)),
        const SizedBox(height: 18),
        _contactCard('Email Us', email, const Color(0xFF7351FF), const Icon(Icons.email_rounded, color: Color(0xFF7351FF), size: 24), isDark, () => _launch(email, isEmail: true)),
        if ((_contactInfo['facebook'] ?? '').isNotEmpty)
          _contactCard('Facebook', 'Follow our page', const Color(0xFF1877F2), const FaIcon(FontAwesomeIcons.facebook, color: Color(0xFF1877F2), size: 24), isDark, () => _launch(_contactInfo['facebook']!)),
        if ((_contactInfo['twitter'] ?? '').isNotEmpty)
          _contactCard('X (Twitter)', 'Send us a direct message', isDark ? Colors.white : Colors.black, FaIcon(FontAwesomeIcons.xTwitter, color: isDark ? Colors.white : Colors.black, size: 22), isDark, () => _launch(_contactInfo['twitter']!)),
        if ((_contactInfo['instagram'] ?? '').isNotEmpty)
          _contactCard('Instagram', 'See our latest updates', const Color(0xFFE5489B), const FaIcon(FontAwesomeIcons.instagram, color: Color(0xFFE5489B), size: 24), isDark, () => _launch(_contactInfo['instagram']!)),
        const SizedBox(height: 10),
        _questionCard(isDark),
      ],
    );
  }

  Widget _contactCard(String title, String subtitle, Color color, Widget icon, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
              child: Center(child: icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}