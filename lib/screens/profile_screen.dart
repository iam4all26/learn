import '../utils/kaida_alert.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../services/api_client.dart';
import '../config/app_theme.dart';
import '../config/theme_provider.dart';
import '../widgets/kaida_loader.dart';
import 'login_screen.dart';
import 'catalog_screen.dart';
import 'downloads_screen.dart';
import 'security_screen.dart';
import 'webview_screen.dart';
import 'wishlist_screen.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import 'help_center_screen.dart';
import 'dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int? _userId;
  String _name = "Loading...";
  String _email = "Loading...";
  String _role = "student";
  String? _avatarUrl;
  String _walletBalance = "0.00";
  String _username = '';
  int _enrolled = 0;
  int _completed = 0;
  
  String _shareMessage = "Join me on Kainuwa Academy! Start building your future today.";
  String _shareUrl = "https://play.google.com/store/apps/details?id=com.kainuwa.academy";
  
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('user_id');
    if (uid == null) return;
    try {
      final r = await http.post(Uri.parse(ApiConfig.dashboardData), body: {'user_id': uid.toString()});
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        if (d['status'] == 'success' && mounted) {
          setState(() {
            _enrolled = int.tryParse(d['data']['total_enrolled'].toString()) ?? 0;
            _completed = int.tryParse(d['data']['total_completed'].toString()) ?? 0;
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');
    
    if (mounted) {
      setState(() {
        _name = prefs.getString('full_name') ?? prefs.getString('name') ?? prefs.getString('username') ?? 'Loading...';
        _email = prefs.getString('email') ?? '';
        _role = prefs.getString('role') ?? 'student';
        _username = prefs.getString('username') ?? '';
      });
    }

    if (_userId == null) return;

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.userProfile),
        body: {'user_id': _userId.toString()}
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && mounted) {
          setState(() {
            _name = data['data']['name'] ?? data['data']['full_name'] ?? data['data']['username'] ?? _name;
            _email = data['data']['email'] ?? _email;
            _role = data['data']['role'] ?? _role;
            if (data['data']['username'] != null) _username = data['data']['username'].toString();
            
            String rawAvatar = data['data']['avatar_url']?.toString() ?? '';
            if (rawAvatar.isNotEmpty && !rawAvatar.startsWith('http')) {
              _avatarUrl = 'https://academy.kainuwa.africa/$rawAvatar';
            } else {
              _avatarUrl = rawAvatar.isNotEmpty ? rawAvatar : null;
            }
            
            _walletBalance = data['data']['wallet_balance']?.toString() ?? '0.00';
            
            if (data['data']['share_message'] != null) _shareMessage = data['data']['share_message'];
            if (data['data']['share_url'] != null) _shareUrl = data['data']['share_url'];

            _isLoading = false;
            
            prefs.setString('full_name', _name);
            prefs.setString('email', _email);
            prefs.setString('role', _role);
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null || _userId == null) return;

      setState(() => _isLoading = true);

      var request = http.MultipartRequest('POST', Uri.parse(ApiConfig.uploadAvatar));
      request.fields['user_id'] = _userId.toString();
      request.files.add(await http.MultipartFile.fromPath('avatar', image.path));

      var response = await request.send();
      if (response.statusCode == 200) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar updated successfully!'), backgroundColor: Colors.green));
         _loadProfileData(); 
      } else {
         KaidaAlert.showModal(context: context, title: 'Update Failed', message: 'Failed to update avatar.', isError: true);
         setState(() => _isLoading = false);
      }
    } catch (e) {
      KaidaAlert.showModal(context: context, title: 'Upload Error', message: 'An error occurred while uploading your avatar.', isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _shareApp() {
    Share.share("$_shareMessage \n\n$_shareUrl");
  }

  // Opens a page of the website in the app already signed in (secure one-time link from the server)
  Future<void> _openWebDashboard(String title, String path) async {
    final url = await ApiClient.webviewUrl(path);
    if (!mounted) return;
    if (url == null) {
      KaidaAlert.showModal(context: context, title: 'Could not open', message: 'We could not open this page right now. Please check your internet and try again.', isError: true);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => WebViewScreen(title: title, url: url)));
  }

  void _handleLogout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ApiClient.logoutOnServer();   // the server stops accepting this device's login
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context, 
                MaterialPageRoute(builder: (_) => const LoginScreen()), 
                (route) => false
              );
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PROFILE (purple header, points card, stats, quick actions, tools)
  // ===========================================================================
  Future<void> _rateApp() async {
    final url = Uri.parse('market://details?id=com.kainuwa.academy');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=com.kainuwa.academy'), mode: LaunchMode.externalApplication);
      }
    } catch (e) {}
  }

  void _openSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _SettingsPage(
          name: _name, username: _username, email: _email, avatarUrl: _avatarUrl,
          onChangePhoto: _pickAndUploadImage,
          onShare: _shareApp,
          onRate: _rateApp,
          onDelete: () => _openWebDashboard('Delete My Account', '/delete-account'),
          onLogout: _handleLogout,
        )));
  }

  String _roleLabel() {
    switch (_role) {
      case 'admin': return 'Administrator';
      case 'instructor': return 'Instructor';
      case 'affiliate': return 'Affiliate';
      default: return 'Student';
    }
  }

  Widget _headerIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }

  Widget _statCell(IconData icon, Color color, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _actionCard(IconData icon, Color color, String title, String sub, VoidCallback onTap, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, height: 1.2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolCard(IconData icon, Color color, String title, String sub, VoidCallback onTap, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: Colors.white, size: 25),
              ),
              const SizedBox(height: 9),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(sub, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 12),
        child: Text(t, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
      );

  Widget _dashboardCard(String title, String sub, IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : const Color(0xFFF0EDFF), borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final topPad = MediaQuery.of(context).padding.top;

    if (_isLoading && _name == "Loading...") {
      return Scaffold(backgroundColor: isDark ? AppTheme.darkBackgroundColor : Colors.white, body: const Center(child: KaidaLoader()));
    }

    final inProgress = (_enrolled - _completed) < 0 ? 0 : (_enrolled - _completed);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : Colors.white,
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () async { await _loadProfileData(); await _loadStats(); },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Header + identity ----
              Padding(
                padding: const EdgeInsets.only(bottom: 44),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 70),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF3A22C4), Color(0xFF6B47F5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset('assets/kainuwa_academy_whitelogo.png', height: 34, fit: BoxFit.contain),
                              const SizedBox(width: 10),
                              const Expanded(child: Text('Kainuwa Academy', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
                              _headerIcon(Icons.settings_rounded, _openSettings),
                              const SizedBox(width: 8),
                              _headerIcon(Icons.notifications_none_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _pickAndUploadImage,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: CircleAvatar(
                                        radius: 46,
                                        backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                                        backgroundImage: _avatarUrl != null ? CachedNetworkImageProvider(_avatarUrl!) : null,
                                        child: _avatarUrl == null ? const Icon(Icons.person_rounded, size: 46, color: AppTheme.primaryColor) : null,
                                      ),
                                    ),
                                    Positioned(
                                      right: -2, bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6)]),
                                        child: const Icon(Icons.edit_rounded, color: AppTheme.primaryColor, size: 15),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, height: 1.15, letterSpacing: -0.4)),
                                    const SizedBox(height: 4),
                                    if (_username.isNotEmpty)
                                      Text('@$_username', style: const TextStyle(color: Colors.white70, fontSize: 14.5, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                                      decoration: BoxDecoration(color: const Color(0xFFFFC21A), borderRadius: BorderRadius.circular(14)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.workspace_premium_rounded, size: 14, color: Color(0xFF1E1E2D)),
                                          const SizedBox(width: 5),
                                          Text(_roleLabel(), style: const TextStyle(color: Color(0xFF1E1E2D), fontWeight: FontWeight.w800, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // KAIDA points card overlapping the curve
                    Positioned(
                      left: 16, right: 16, bottom: -44,
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF4C2FE0), Color(0xFF7B5CFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [BoxShadow(color: const Color(0xFF4C2FE0).withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 8))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50, height: 50,
                                decoration: const BoxDecoration(color: Color(0xFFFFC21A), shape: BoxShape.circle),
                                child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 30),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('KAIDA Points', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(_walletBalance, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ---- Stats row ----
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    _statCell(Icons.school_rounded, const Color(0xFF5B34F0), '$_enrolled', 'Courses\nEnrolled'),
                    _statCell(Icons.play_circle_fill_rounded, const Color(0xFF2F80ED), '$inProgress', 'In\nProgress'),
                    _statCell(Icons.emoji_events_rounded, const Color(0xFFFFB020), '$_completed', 'Courses\nCompleted'),
                  ],
                ),
              ),

              _sectionTitle('What do you want to do?'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _actionCard(Icons.play_circle_fill_rounded, const Color(0xFF5B34F0), 'My Courses', 'View all your courses', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen())), isDark),
                        const SizedBox(width: 10),
                        _actionCard(Icons.favorite_rounded, const Color(0xFFEF4466), 'Wishlist', 'Courses you saved', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen())), isDark),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _actionCard(Icons.download_rounded, const Color(0xFF2F80ED), 'Downloads', 'Your saved files', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen())), isDark),
                        const SizedBox(width: 10),
                        _actionCard(Icons.notifications_rounded, const Color(0xFFFFB020), 'Notifications', 'Your latest updates', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())), isDark),
                      ],
                    ),
                  ],
                ),
              ),

              // ---- Role dashboards (web) ----
              if (_role == 'instructor' || _role == 'admin' || _role == 'affiliate') ...[
                _sectionTitle('Dashboards'),
                if (_role == 'instructor' || _role == 'admin')
                  _dashboardCard('Instructor Dashboard', 'Manage courses, reviews and earnings', Icons.groups_rounded, () => _openWebDashboard('Instructor Dashboard', '/switch_view.php?view=instructor'), isDark),
                if (_role == 'affiliate' || _role == 'admin')
                  _dashboardCard('Affiliate Dashboard', 'Track referrals and commissions', Icons.campaign_rounded, () => _openWebDashboard('Affiliate Dashboard', '/switch_view.php?view=affiliate'), isDark),
                if (_role == 'admin')
                  _dashboardCard('Admin Dashboard', 'Manage the whole platform', Icons.admin_panel_settings_rounded, () => _openWebDashboard('Admin Dashboard', '/switch_view.php?view=admin'), isDark),
              ],

              // ---- Tools & services ----
              _sectionTitle('Tools & Services'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _toolCard(Icons.storefront_rounded, const Color(0xFF22C55E), 'Kainuwa Shop', 'Products and templates', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen(actionType: 'products', title: 'Shop Products'))), isDark),
                    _toolCard(Icons.menu_book_rounded, const Color(0xFF2F80ED), 'Explore Courses', 'Find your next course', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen(actionType: 'courses', title: 'Explore Courses'))), isDark),
                    _toolCard(Icons.card_giftcard_rounded, const Color(0xFFF97316), 'Invite Friends', 'Share the app', _shareApp, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SETTINGS PAGE (opened from the gear icon)
// =============================================================================
class _SettingsPage extends StatelessWidget {
  final String name, username, email;
  final String? avatarUrl;
  final VoidCallback onChangePhoto, onShare, onRate, onDelete, onLogout;

  const _SettingsPage({
    required this.name, required this.username, required this.email, required this.avatarUrl,
    required this.onChangePhoto, required this.onShare, required this.onRate, required this.onDelete, required this.onLogout,
  });

  Widget _group(String title, List<Widget> rows, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 10), child: Text(title, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w900, letterSpacing: -0.2))),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: List.generate(rows.length, (i) => Column(children: [
                  rows[i],
                  if (i != rows.length - 1) Divider(height: 1, indent: 62, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                ])),
          ),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String title, String sub, VoidCallback? onTap, {Widget? trailing, Color? color}) {
    final c = color ?? AppTheme.primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: c, size: 26),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: color)),
                  Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : const Color(0xFFF6F5FD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text('Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile information card
            Padding(padding: const EdgeInsets.fromLTRB(20, 6, 20, 10), child: const Text('Profile Information', style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w900))),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                      backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl!) : null,
                      child: avatarUrl == null ? const Icon(Icons.person_rounded, color: AppTheme.primaryColor, size: 34) : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900))),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit_rounded, size: 15, color: AppTheme.primaryColor),
                          ]),
                          if (username.isNotEmpty) Text('@$username', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                          Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(children: [
                _row(Icons.person_rounded, 'Edit Profile', 'Update your name and details', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
                Divider(height: 1, indent: 62, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                _row(Icons.photo_camera_rounded, 'Change Profile Photo', 'Pick a new picture', onChangePhoto),
                Divider(height: 1, indent: 62, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                _row(Icons.lock_rounded, 'Change Password', 'Keep your account safe', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen()))),
              ]),
            ),

            _group('App Preferences', [
              _row(Icons.dark_mode_rounded, 'Dark Mode', 'Switch between light and dark', () => themeProvider.toggleTheme(!isDark),
                  trailing: Switch(value: isDark, activeColor: AppTheme.primaryColor, onChanged: (v) => themeProvider.toggleTheme(v))),
              _row(Icons.language_rounded, 'Language', 'App language', null, trailing: Text('English', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600))),
              _row(Icons.notifications_rounded, 'Notifications', 'See your latest updates', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            ], isDark),

            _group('Account & Security', [
              _row(Icons.shield_rounded, 'Security', 'Password and account safety', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen()))),
            ], isDark),

            _group('Support & Community', [
              _row(Icons.help_outline_rounded, 'Help Center', 'Answers and support', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen()))),
              _row(Icons.share_rounded, 'Share App', 'Invite your friends', onShare),
              _row(Icons.star_rounded, 'Rate Us', 'Rate the app on Google Play', onRate, color: null),
            ], isDark),

            _group('Data & Account', [
              _row(Icons.delete_outline_rounded, 'Delete My Account', 'Permanently remove your account', onDelete, color: Colors.red),
              _row(Icons.logout_rounded, 'Logout', 'Sign out of this device', onLogout, color: Colors.red),
            ], isDark),

            const SizedBox(height: 24),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/kainuwa_academy_whitelogo.png', height: 30, fit: BoxFit.contain, color: const Color(0xFF5B34F0)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kainuwa Academy', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF5B34F0), fontSize: 13)),
                      Text('Kainuwa Digital Africa Ltd', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}