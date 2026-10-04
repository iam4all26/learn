import '../utils/kaida_alert.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  
  String _shareMessage = "Join me on Kainuwa Academy! Start building your future today.";
  String _shareUrl = "https://play.google.com/store/apps/details?id=com.kainuwa.academy";
  
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');
    
    if (mounted) {
      setState(() {
        _name = prefs.getString('full_name') ?? prefs.getString('name') ?? prefs.getString('username') ?? 'Loading...';
        _email = prefs.getString('email') ?? '';
        _role = prefs.getString('role') ?? 'student';
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

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required bool isDark,
    Widget? trailing,
    VoidCallback? onTap,
    bool isLogout = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isLogout 
              ? Colors.red.withOpacity(0.1) 
              : AppTheme.primaryColor.withOpacity(isDark ? 0.15 : 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isLogout ? Colors.red : AppTheme.primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isLogout ? Colors.red : (isDark ? Colors.white : Colors.black87),
        ),
      ),
      trailing: trailing ?? Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, 
        title: Text('Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
      ),
      body: SafeArea(
        child: _isLoading && _name == "Loading..."
        ? const Center(child: KaidaLoader()) 
        : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                              backgroundImage: _avatarUrl != null ? CachedNetworkImageProvider(_avatarUrl!) : null,
                              child: _avatarUrl == null 
                                  ? const Icon(Icons.person_rounded, size: 50, color: AppTheme.primaryColor) 
                                  : null,
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle, border: Border.all(color: isDark ? AppTheme.darkBackgroundColor : Colors.white, width: 3)),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(_name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      const SizedBox(height: 4),
                      Text(_email, style: TextStyle(fontSize: 15, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                      
                      if (_role != 'student')
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            _role.toUpperCase(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor, letterSpacing: 1),
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),

                // CORRECTED WEB DASHBOARD ROUTES
                if (_role == 'admin') ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                    child: Text('ADMINISTRATOR', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  _buildOptionTile(icon: Icons.admin_panel_settings_rounded, title: 'Admin Dashboard', isDark: isDark, onTap: () => _openWebDashboard('Admin Dashboard', '/switch_view.php?view=admin')),
                  const SizedBox(height: 10),
                ],

                if (_role == 'instructor' || _role == 'admin') ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                    child: Text('INSTRUCTOR', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  _buildOptionTile(icon: Icons.dashboard_customize_rounded, title: 'Instructor Dashboard', isDark: isDark, onTap: () => _openWebDashboard('Instructor Dashboard', '/switch_view.php?view=instructor')),
                  const SizedBox(height: 10),
                ],

                if (_role == 'affiliate' || _role == 'admin') ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                    child: Text('AFFILIATE', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  _buildOptionTile(icon: Icons.campaign_rounded, title: 'Affiliate Dashboard', isDark: isDark, onTap: () => _openWebDashboard('Affiliate Dashboard', '/switch_view.php?view=affiliate')),
                  const SizedBox(height: 10),
                ],

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                  child: Text('GENERAL', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),

                _buildOptionTile(icon: Icons.person_rounded, title: 'Edit Profile', isDark: isDark, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                }),
                
                _buildOptionTile(icon: Icons.account_balance_wallet_rounded, title: 'Kaida Tokens', isDark: isDark, trailing: Text(_walletBalance, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 16)), onTap: () {}),
                
                _buildOptionTile(icon: Icons.favorite_rounded, title: 'My Wishlist', isDark: isDark, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen()));
                }),
                
                _buildOptionTile(icon: Icons.store_rounded, title: 'Shop', isDark: isDark, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen(actionType: 'products', title: 'Shop Products')));
                }),
                
                _buildOptionTile(icon: Icons.bookmark_rounded, title: 'Saved Downloads', isDark: isDark, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen()));
                }),

                _buildOptionTile(icon: Icons.notifications_rounded, title: 'Notifications', isDark: isDark, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                }),
                
                _buildOptionTile(icon: Icons.security_rounded, title: 'Security', isDark: isDark, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen()));
                }),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                  child: Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                ),
                
                _buildOptionTile(
                  icon: Icons.language_rounded,
                  title: 'Language',
                  isDark: isDark,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('English', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
                    ],
                  ),
                  onTap: () {},
                ),
                
                _buildOptionTile(icon: Icons.share_rounded, title: 'Share App', isDark: isDark, onTap: _shareApp),

                _buildOptionTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'Dark Mode',
                  isDark: isDark,
                  trailing: Switch(
                    value: isDark,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (value) => themeProvider.toggleTheme(value),
                  ),
                  onTap: () => themeProvider.toggleTheme(!isDark),
                ),
                
                _buildOptionTile(icon: Icons.help_rounded, title: 'Help Center', isDark: isDark, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen()));
                }),
                
                const SizedBox(height: 10),
                _buildOptionTile(icon: Icons.logout_rounded, title: 'Log Out', isDark: isDark, isLogout: true, trailing: const SizedBox(), onTap: _handleLogout),
                const SizedBox(height: 40),
              ],
            ),
          ),
      ),
    );
  }
}