import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../widgets/kaida_loader.dart';
import '../utils/kaida_alert.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _uploading = false;

  int? _userId;
  String _role = 'student';
  String _originalUsername = '';
  String _avatarUrl = '';

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _headlineController = TextEditingController();
  final _bioController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isProfilePublic = false;
  bool _showCoursesOnProfile = true;

  String _language = 'en';
  List<dynamic> _countries = [], _states = [], _cities = [];
  String? _countryId, _countryName, _stateId, _stateName, _cityId, _cityName;

  Timer? _usernameDebounce;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;

  static const _languages = [{'id': 'en', 'name': 'English'}, {'id': 'ha', 'name': 'Hausa'}];

  @override
  void initState() {
    super.initState();
    _bioController.addListener(() => setState(() {}));
    _fetchProfileData();
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _headlineController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String _fixUrl(String raw) => raw.isEmpty ? '' : (raw.startsWith('http') ? raw : 'https://academy.kainuwa.africa/${raw.replaceFirst(RegExp(r'^/+'), '')}');

  Future<List<dynamic>> _getList(String query) async {
    try {
      final r = await http.get(Uri.parse('${ApiConfig.locations}?$query'));
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        if (d['status'] == 'success') return List<dynamic>.from(d['data']);
      }
    } catch (_) {}
    return [];
  }

  String? _nameFor(List<dynamic> list, String? id) {
    if (id == null) return null;
    for (final e in list) {
      if ('${e['id']}' == id) return '${e['name']}';
    }
    return null;
  }

  Future<void> _fetchProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');
    if (_userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final response = await http.post(Uri.parse(ApiConfig.getProfileDetails), body: {'user_id': _userId.toString()});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && mounted) {
          final user = data['data'];
          _originalUsername = user['username'] ?? '';
          _fullNameController.text = user['full_name'] ?? '';
          _usernameController.text = _originalUsername;
          _emailController.text = user['email'] ?? '';
          _phoneController.text = user['phone_number']?.toString() ?? '';
          _headlineController.text = user['headline'] ?? '';
          _bioController.text = user['bio'] ?? '';
          _avatarUrl = _fixUrl(user['avatar_url']?.toString() ?? '');
          _language = (user['language']?.toString() == 'ha') ? 'ha' : 'en';
          _isProfilePublic = '${user['is_profile_public']}' == '1';
          _showCoursesOnProfile = '${user['show_courses_on_profile']}' == '1';
          _role = user['role'] ?? 'student';

          // saved location (ids -> names)
          _countries = await _getList('action=countries');
          final cid = user['country_id']?.toString();
          final sid = user['state_id']?.toString();
          final tid = user['city_id']?.toString();
          if (cid != null && cid != 'null' && cid.isNotEmpty) {
            _countryId = cid;
            _countryName = _nameFor(_countries, cid);
            _states = await _getList('action=states&country_id=$cid');
            if (sid != null && sid != 'null' && sid.isNotEmpty) {
              _stateId = sid;
              _stateName = _nameFor(_states, sid);
              _cities = await _getList('action=cities&state_id=$sid');
              if (tid != null && tid != 'null' && tid.isNotEmpty) {
                _cityId = tid;
                _cityName = _nameFor(_cities, tid);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Edit profile load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    if (value.trim() == _originalUsername || value.isEmpty) {
      setState(() { _isUsernameAvailable = null; _isCheckingUsername = false; });
      return;
    }
    setState(() => _isCheckingUsername = true);
    _usernameDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final response = await http.get(Uri.parse('${ApiConfig.checkUsername}?username=${value.trim()}'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'success' && mounted) {
            setState(() { _isUsernameAvailable = data['available']; _isCheckingUsername = false; });
          }
        }
      } catch (e) {
        if (mounted) setState(() => _isCheckingUsername = false);
      }
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (image == null || _userId == null) return;
      if (await image.length() > 2 * 1024 * 1024) {
        _snack('Image is larger than 2MB. Please choose a smaller one.', error: true);
        return;
      }
      setState(() => _uploading = true);
      final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.uploadAvatar));
      request.fields['user_id'] = _userId.toString();
      request.files.add(await http.MultipartFile.fromPath('avatar', image.path));
      final response = await request.send();
      final body = await response.stream.bytesToString();
      Map<String, dynamic> d = {};
      try { d = json.decode(body); } catch (_) {}
      if (response.statusCode == 200 && d['status'] == 'success') {
        final newUrl = (d['avatar_url'] ?? d['url'] ?? d['data']?['avatar_url'] ?? d['data']?['url'])?.toString();
        if (newUrl != null && newUrl.isNotEmpty) {
          _avatarUrl = _fixUrl(newUrl) + '?t=${DateTime.now().millisecondsSinceEpoch}';
        } else {
          await _fetchAvatarOnly();
        }
        _snack('Photo updated');
      } else {
        _snack(d['message']?.toString() ?? 'Could not upload the photo.', error: true);
      }
    } catch (e) {
      _snack('Could not upload the photo.', error: true);
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _fetchAvatarOnly() async {
    try {
      final r = await http.post(Uri.parse(ApiConfig.getProfileDetails), body: {'user_id': _userId.toString()});
      final d = json.decode(r.body);
      if (d['status'] == 'success') _avatarUrl = _fixUrl(d['data']['avatar_url']?.toString() ?? '') + '?t=${DateTime.now().millisecondsSinceEpoch}';
    } catch (_) {}
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ? KaidaAlert.friendly(msg) : msg), backgroundColor: error ? Colors.red : Colors.green));
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (_fullNameController.text.trim().isEmpty || _usernameController.text.trim().isEmpty) {
      _snack('Name and username are required.', error: true);
      return;
    }
    if (_isUsernameAvailable == false) {
      _snack('Please choose an available username.', error: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final body = <String, String>{
        'user_id': _userId.toString(),
        'username': _usernameController.text.trim(),
        'full_name': _fullNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
        'language': _language,
        'is_profile_public': _isProfilePublic ? '1' : '0',
        'show_courses_on_profile': _showCoursesOnProfile ? '1' : '0',
        'role': _role,
      };
      if (_role == 'instructor' || _role == 'admin') body['headline'] = _headlineController.text.trim();
      if (_countryId != null) body['country_id'] = _countryId!;
      if (_stateId != null) body['state_id'] = _stateId!;
      if (_cityId != null) body['city_id'] = _cityId!;

      final response = await http.post(Uri.parse(ApiConfig.updateProfile), body: body);
      final data = json.decode(response.body);
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (data['status'] == 'success') {
        _snack('Profile updated successfully!');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('full_name', _fullNameController.text.trim());
        await prefs.setString('username', _usernameController.text.trim());
        if (mounted) Navigator.pop(context);
      } else {
        _snack(data['message']?.toString() ?? 'Update failed', error: true);
      }
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      _snack('A network error occurred.', error: true);
    }
  }

  // ---------------- UI helpers ----------------
  Widget _card(bool isDark, IconData icon, String title, String sub, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF16123A))),
              Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ])),
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _label(String t, bool required, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RichText(text: TextSpan(text: t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF16123A)), children: [
          if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
        ])),
      );

  Widget _field(bool isDark, String label, IconData icon, TextEditingController c,
      {bool required = false, bool readOnly = false, TextInputType? type, ValueChanged<String>? onChanged, Widget? suffix, List<TextInputFormatter>? formatters}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required, isDark),
        TextField(
          controller: c,
          readOnly: readOnly,
          keyboardType: type,
          onChanged: onChanged,
          inputFormatters: formatters,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: readOnly ? Colors.grey : (isDark ? Colors.white : Colors.black87)),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F4FB),
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            prefixIcon: Icon(icon, size: 19, color: Colors.grey.shade600),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            suffixIcon: suffix,
            suffixIconConstraints: const BoxConstraints(minWidth: 34),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : const Color(0xFFE3E0F5))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.6)),
          ),
        ),
      ],
    );
  }

  Widget _select(bool isDark, String label, IconData icon, String? value, String placeholder, VoidCallback onTap, {bool required = false, bool disabled = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required, isDark),
        GestureDetector(
          onTap: disabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F4FB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.grey.shade800 : const Color(0xFFE3E0F5)),
            ),
            child: Row(children: [
              Icon(icon, size: 19, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(child: Text(value ?? placeholder, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: value == null ? Colors.grey.shade500 : (isDark ? Colors.white : Colors.black87)))),
              Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey.shade600),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _pair(Widget a, Widget b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);

  void _openSheet(String title, List<dynamic> items, void Function(String id, String name) onSelect) {
    if (items.isEmpty) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<dynamic> shown = List.from(items);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setM) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
          builder: (ctx, sc) => Column(children: [
            Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.all(12), child: Text('Select $title', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))),
            if (items.length > 6)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  decoration: InputDecoration(hintText: 'Search...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100, contentPadding: EdgeInsets.zero, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  onChanged: (v) => setM(() => shown = items.where((e) => '${e['name']}'.toLowerCase().contains(v.toLowerCase())).toList()),
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: sc,
                itemCount: shown.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text('${shown[i]['name']}', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  onTap: () { onSelect('${shown[i]['id']}', '${shown[i]['name']}'); Navigator.pop(ctx); },
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;
    final isInstructor = _role == 'instructor' || _role == 'admin';

    Widget? unameStatus;
    if (_isCheckingUsername) {
      unameStatus = const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)));
    } else if (_isUsernameAvailable == true) {
      unameStatus = const Icon(Icons.check_circle, color: Colors.green, size: 18);
    } else if (_isUsernameAvailable == false) {
      unameStatus = const Icon(Icons.cancel, color: Colors.red, size: 18);
    }

    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: CircleAvatar(
            radius: 44,
            backgroundColor: const Color(0xFFEDE9FF),
            backgroundImage: _avatarUrl.isNotEmpty ? CachedNetworkImageProvider(_avatarUrl) : null,
            child: _uploading
                ? const CircularProgressIndicator(strokeWidth: 2)
                : (_avatarUrl.isEmpty ? const Icon(Icons.person_rounded, size: 44, color: AppTheme.primaryColor) : null),
          ),
        ),
        Positioned(
          right: -2, bottom: -2,
          child: GestureDetector(
            onTap: () => _pickPhoto(ImageSource.gallery),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : const Color(0xFFF6F5FB),
      body: _isLoading
          ? const Center(child: KaidaLoader())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 24),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF3A22C4), Color(0xFF6B47F5)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), shape: BoxShape.circle), child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 19)),
                          ),
                          const SizedBox(width: 12),
                          Image.asset('assets/kainuwa_academy_whitelogo.png', height: 34, fit: BoxFit.contain),
                        ]),
                        const SizedBox(height: 18),
                        Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                              const SizedBox(height: 6),
                              Text('Keep your details up to date.', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14, height: 1.35)),
                            ]),
                          ),
                          avatar,
                        ]),
                      ],
                    ),
                  ),

                  _card(isDark, Icons.person_rounded, 'Personal Information', 'These details show on your profile.', [
                    _pair(
                      _field(isDark, 'Full Name', Icons.person_outline_rounded, _fullNameController, required: true),
                      _field(isDark, 'Username', Icons.alternate_email_rounded, _usernameController, required: true, onChanged: _onUsernameChanged, suffix: unameStatus),
                    ),
                    if (_isUsernameAvailable == false)
                      const Padding(padding: EdgeInsets.only(top: 4), child: Text('Username is already taken', style: TextStyle(color: Colors.red, fontSize: 11.5, fontWeight: FontWeight.w700))),
                    const SizedBox(height: 12),
                    _pair(
                      _field(isDark, 'Email Address', Icons.mail_outline_rounded, _emailController, readOnly: true),
                      _field(isDark, 'Phone Number', Icons.phone_outlined, _phoneController, type: TextInputType.phone, formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')), LengthLimitingTextInputFormatter(20)]),
                    ),
                    const SizedBox(height: 12),
                    _pair(
                      _select(isDark, 'Language', Icons.translate_rounded, _language == 'ha' ? 'Hausa' : 'English', 'Select', () => _openSheet('Language', _languages, (id, n) => setState(() => _language = id)), required: true),
                      _select(isDark, 'Country', Icons.public_rounded, _countryName, 'Select', () => _openSheet('Country', _countries, (id, n) async {
                        setState(() { _countryId = id; _countryName = n; _stateId = _stateName = _cityId = _cityName = null; _states = []; _cities = []; });
                        final s = await _getList('action=states&country_id=$id');
                        if (mounted) setState(() => _states = s);
                      }), required: true, disabled: _countries.isEmpty),
                    ),
                    const SizedBox(height: 12),
                    _pair(
                      _select(isDark, 'State', Icons.location_on_outlined, _stateName, 'Select', () => _openSheet('State', _states, (id, n) async {
                        setState(() { _stateId = id; _stateName = n; _cityId = _cityName = null; _cities = []; });
                        final c = await _getList('action=cities&state_id=$id');
                        if (mounted) setState(() => _cities = c);
                      }), required: true, disabled: _states.isEmpty),
                      _select(isDark, 'City', Icons.apartment_rounded, _cityName, 'Select', () => _openSheet('City', _cities, (id, n) => setState(() { _cityId = id; _cityName = n; })), required: true, disabled: _cities.isEmpty),
                    ),
                  ]),

                  _card(isDark, Icons.image_rounded, 'Profile Photo', 'Choose from your gallery or take a new photo.', [
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _uploading ? null : () => _pickPhoto(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 19, color: AppTheme.primaryColor),
                          label: const Text('Choose Photo', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryColor), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _uploading ? null : () => _pickPhoto(ImageSource.camera),
                          icon: Icon(Icons.photo_camera_outlined, size: 19, color: isDark ? Colors.white : Colors.black87),
                          label: Text('Take Photo', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w800)),
                          style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade400), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text('PNG, JPG or WEBP. Maximum size 2MB. The photo is saved as soon as it uploads.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ]),

                  _card(isDark, Icons.info_rounded, 'About You (Bio)', 'Write a short introduction about yourself.', [
                    if (isInstructor) ...[
                      _field(isDark, 'Headline', Icons.badge_outlined, _headlineController),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _bioController,
                      maxLines: 4,
                      maxLength: 500,
                      style: TextStyle(fontSize: 14, height: 1.4, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Tell people about yourself...',
                        filled: true,
                        fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F4FB),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : const Color(0xFFE3E0F5))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.6)),
                      ),
                    ),
                  ]),

                  _card(isDark, Icons.lock_outline_rounded, 'Privacy', 'Choose what other people can see.', [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.primaryColor,
                      title: Text('Make Profile Public', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: Text('Allow others to view your profile', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      value: _isProfilePublic,
                      onChanged: (v) => setState(() => _isProfilePublic = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.primaryColor,
                      title: Text('Show Enrolled Courses', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                      subtitle: Text('Display your active courses on your profile', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      value: _showCoursesOnProfile,
                      onChanged: (v) => setState(() => _showCoursesOnProfile = v),
                    ),
                  ]),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 36),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded, color: Colors.white, size: 21),
                        label: const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}