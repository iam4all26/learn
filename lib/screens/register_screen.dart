import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/kaida_loader.dart';
import '../utils/kaida_alert.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';
import 'main_layout.dart';

class RegisterScreen extends StatefulWidget {
  final String? prefillEmail;
  final String? prefillName;

  const RegisterScreen({Key? key, this.prefillEmail, this.prefillName}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String? _selectedLanguage = 'en';
  List<dynamic> _countries = [];
  List<dynamic> _states = [];
  List<dynamic> _cities = [];

  String? _selectedCountryId;
  String? _selectedCountryName;
  String? _selectedStateId;
  String? _selectedStateName;
  String? _selectedCityId;
  String? _selectedCityName;

  bool _agreeTerms = false;
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Timer? _usernameDebounce;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  bool? _passwordsMatch;

  final List<Map<String, String>> _languages = [{'id': 'en', 'name': 'English'}, {'id': 'ha', 'name': 'Hausa'}];

  @override
  void initState() {
    super.initState();
    if (widget.prefillName != null) _fullNameController.text = widget.prefillName!;
    if (widget.prefillEmail != null) _emailController.text = widget.prefillEmail!;
    _fetchCountries();
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchCountries() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.locations}?action=countries'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && mounted) setState(() => _countries = data['data']);
      }
    } catch (e) {
      debugPrint("Countries fetch error: $e");
    }
  }

  Future<void> _fetchStates(String countryId) async {
    setState(() { _states = []; _cities = []; _selectedStateId = null; _selectedStateName = null; _selectedCityId = null; _selectedCityName = null; });
    try {
      final response = await http.get(Uri.parse('${ApiConfig.locations}?action=states&country_id=$countryId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && mounted) setState(() => _states = data['data']);
      }
    } catch (e) {}
  }

  Future<void> _fetchCities(String stateId) async {
    setState(() { _cities = []; _selectedCityId = null; _selectedCityName = null; });
    try {
      final response = await http.get(Uri.parse('${ApiConfig.locations}?action=cities&state_id=$stateId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && mounted) setState(() => _cities = data['data']);
      }
    } catch (e) {}
  }

  void _onUsernameChanged(String value) {
    if (_usernameDebounce?.isActive ?? false) _usernameDebounce!.cancel();
    if (value.isEmpty) {
      setState(() { _isUsernameAvailable = null; _isCheckingUsername = false; });
      return;
    }
    setState(() => _isCheckingUsername = true);
    _usernameDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final response = await http.get(Uri.parse('${ApiConfig.checkUsername}?username=$value'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'success' && mounted) {
            setState(() { _isUsernameAvailable = data['available']; _isCheckingUsername = false; });
          }
        }
      } catch (e) { if (mounted) setState(() => _isCheckingUsername = false); }
    });
  }

  void _onPasswordChanged() {
    if (_confirmPasswordController.text.isEmpty) {
      setState(() => _passwordsMatch = null);
      return;
    }
    setState(() { _passwordsMatch = _passwordController.text == _confirmPasswordController.text; });
  }

  void _handleRegister() async {
    FocusScope.of(context).unfocus();
    if (_fullNameController.text.isEmpty || _usernameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      KaidaAlert.showModal(context: context, title: 'Action Required', message: 'Please fill all required fields.', isError: true);
      return;
    }
    if (_isUsernameAvailable == false) {
      KaidaAlert.showModal(context: context, title: 'Username Taken', message: 'That username is already taken. Please choose another one.', isError: true);
      return;
    }
    if (_selectedCountryId == null || _selectedStateId == null || _selectedCityId == null) {
      KaidaAlert.showModal(context: context, title: 'Location Required', message: 'Please select your Country, State, and City.', isError: true);
      return;
    }
    if (_passwordsMatch == false) {
      KaidaAlert.showModal(context: context, title: 'Password Mismatch', message: 'Your passwords do not match. Please try again.', isError: true);
      return;
    }
    if (!_agreeTerms) {
      KaidaAlert.showModal(context: context, title: 'Terms Required', message: 'Please confirm that you are at least 16 years old and agree to the Terms & Conditions to create an account.', isError: true);
      return;
    }
    
    setState(() => _isLoading = true);
    final userData = {
      'full_name': _fullNameController.text.trim(),
      'username': _usernameController.text.trim().toLowerCase(),
      'email': _emailController.text.trim(),
      'language': _selectedLanguage ?? 'en',
      'country_id': _selectedCountryId ?? '',
      'state_id': _selectedStateId ?? '',
      'city_id': _selectedCityId ?? '',
      'password': _passwordController.text,
      'auth_provider': widget.prefillEmail != null ? 'google' : 'email',
    };

    final result = await _authService.register(userData);

    if (result['success']) {
      if (!mounted) return;
      if (widget.prefillEmail != null) {
        // Bypass OTP, Login Directly, Go to Dashboard
        await _authService.login(_emailController.text.trim(), _passwordController.text);
        if (mounted) setState(() => _isLoading = false);
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayout()));
      } else {
        // Standard Email Registration -> Go to OTP
        if (mounted) setState(() => _isLoading = false);
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OtpVerificationScreen(email: _emailController.text.trim())));
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
      if (!mounted) return;
      KaidaAlert.showModal(context: context, title: 'Registration Failed', message: result['message'], isError: true);
    }
  }

  void _openSelectionSheet({required String title, required List<dynamic> items, required Function(String id, String name) onSelect}) {
    if (items.isEmpty) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<dynamic> filteredItems = List.from(items);
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('Select $title', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16),
                        decoration: InputDecoration(hintText: 'Search...', hintStyle: TextStyle(color: Colors.grey.shade500), prefixIcon: Icon(Icons.search, color: Colors.grey.shade500), filled: true, fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100, contentPadding: const EdgeInsets.symmetric(vertical: 0), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        onChanged: (value) => setModalState(() => filteredItems = items.where((item) => item['name'].toString().toLowerCase().contains(value.toLowerCase())).toList()),
                      ),
                    ),
                    Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                    Expanded(
                      child: filteredItems.isEmpty ? Center(child: Text("No results found", style: TextStyle(color: Colors.grey.shade500))) : ListView.builder(
                          controller: scrollController, physics: const BouncingScrollPhysics(), itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4), title: Text(item['name'], style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16)), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                              onTap: () { onSelect(item['id'].toString(), item['name'].toString()); Navigator.pop(context); },
                            );
                          },
                        ),
                    ),
                  ],
                );
              },
            );
          }
        );
      },
    );
  }

  Widget _buildBottomSheetDropdown({required IconData icon, required String label, required String? valueName, required VoidCallback onTap, required bool isDark, bool disabled = false}) {
    return GestureDetector(
      onTap: disabled ? null : onTap, behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(disabled ? 0.03 : 0.08), shape: BoxShape.circle), child: Icon(icon, color: disabled ? Colors.grey : AppTheme.primaryColor, size: 22)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1.5))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(valueName ?? 'Select', style: TextStyle(color: valueName == null || disabled ? Colors.grey : (isDark ? Colors.white : Colors.black), fontSize: 16, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomInput({required IconData icon, required String label, required TextEditingController controller, required bool isDark, bool isPassword = false, bool isConfirm = false, bool isReadOnly = false, Function(String)? onChanged, Widget? statusWidget}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.08), shape: BoxShape.circle), child: Icon(icon, color: AppTheme.primaryColor, size: 22)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
              TextField(
                controller: controller, onChanged: onChanged, readOnly: isReadOnly,
                obscureText: isPassword ? (isConfirm ? _obscureConfirmPassword : _obscurePassword) : false,
                style: TextStyle(color: isReadOnly ? Colors.grey : (isDark ? Colors.white : Colors.black), fontSize: 16, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: isReadOnly ? Colors.grey.shade300 : AppTheme.primaryColor, width: 2)),
                  suffixIconConstraints: const BoxConstraints(maxHeight: 32, maxWidth: 60),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (statusWidget != null) statusWidget,
                      if (isPassword) IconButton(padding: EdgeInsets.zero, icon: Icon((isConfirm ? _obscureConfirmPassword : _obscurePassword) ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade400, size: 20), onPressed: () => setState(() { if (isConfirm) _obscureConfirmPassword = !_obscureConfirmPassword; else _obscurePassword = !_obscurePassword; })),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget? usernameStatusWidget;
    if (_isCheckingUsername) usernameStatusWidget = const Padding(padding: EdgeInsets.only(right: 8), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
    else if (_isUsernameAvailable == true) usernameStatusWidget = const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.check_circle, color: Colors.green, size: 18));
    else if (_isUsernameAvailable == false) usernameStatusWidget = const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.cancel, color: Colors.red, size: 18));

    Widget? passwordStatusWidget;
    if (_passwordsMatch == true) passwordStatusWidget = const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.check_circle, color: Colors.green, size: 18));
    else if (_passwordsMatch == false) passwordStatusWidget = const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.cancel, color: Colors.red, size: 18));

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : Colors.white,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black, size: 20), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())))),
      body: SafeArea(
        child: _isLoading 
        ? const Center(child: KaidaLoader()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create Account', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 8),
                Text(widget.prefillEmail != null ? 'Please complete your profile details below' : 'Sign up to start learning with Kainuwa Academy', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                const SizedBox(height: 40),
                
                _buildCustomInput(icon: Icons.person_rounded, label: 'Full Name', controller: _fullNameController, isDark: isDark),
                const SizedBox(height: 24),
                
                _buildCustomInput(icon: Icons.alternate_email_rounded, label: 'Username', controller: _usernameController, isDark: isDark, onChanged: _onUsernameChanged, statusWidget: usernameStatusWidget),
                if (_isUsernameAvailable == false) const Padding(padding: EdgeInsets.only(left: 58, top: 4), child: Text('Username is already taken', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold))),
                const SizedBox(height: 24),
                
                _buildCustomInput(icon: Icons.email_rounded, label: 'Email address', controller: _emailController, isDark: isDark, isReadOnly: widget.prefillEmail != null),
                const SizedBox(height: 24),
                
                _buildBottomSheetDropdown(icon: Icons.language_rounded, label: 'Preferred Language', valueName: _selectedLanguage == 'ha' ? 'Hausa' : 'English', isDark: isDark, onTap: () => _openSelectionSheet(title: 'Language', items: _languages, onSelect: (id, name) => setState(() => _selectedLanguage = id))),
                const SizedBox(height: 24),
                _buildBottomSheetDropdown(icon: Icons.public_rounded, label: 'Country', valueName: _selectedCountryName, isDark: isDark, disabled: _countries.isEmpty, onTap: () => _openSelectionSheet(title: 'Country', items: _countries, onSelect: (id, name) { setState(() { _selectedCountryId = id; _selectedCountryName = name; }); _fetchStates(id); })),
                const SizedBox(height: 24),
                _buildBottomSheetDropdown(icon: Icons.map_rounded, label: 'State', valueName: _selectedStateName, isDark: isDark, disabled: _states.isEmpty, onTap: () => _openSelectionSheet(title: 'State', items: _states, onSelect: (id, name) { setState(() { _selectedStateId = id; _selectedStateName = name; }); _fetchCities(id); })),
                const SizedBox(height: 24),
                _buildBottomSheetDropdown(icon: Icons.location_city_rounded, label: 'City', valueName: _selectedCityName, isDark: isDark, disabled: _cities.isEmpty, onTap: () => _openSelectionSheet(title: 'City', items: _cities, onSelect: (id, name) => setState(() { _selectedCityId = id; _selectedCityName = name; }))),
                const SizedBox(height: 24),
                
                _buildCustomInput(icon: Icons.lock_rounded, label: 'Password', controller: _passwordController, isDark: isDark, isPassword: true, onChanged: (val) => _onPasswordChanged()),
                const SizedBox(height: 24),
                _buildCustomInput(icon: Icons.lock_reset_rounded, label: 'Confirm Password', controller: _confirmPasswordController, isDark: isDark, isPassword: true, isConfirm: true, onChanged: (val) => _onPasswordChanged(), statusWidget: passwordStatusWidget),
                const SizedBox(height: 30),
                
                Row(
                  children: [
                    SizedBox(height: 24, width: 24, child: Checkbox(value: _agreeTerms, activeColor: AppTheme.primaryColor, onChanged: (val) => setState(() => _agreeTerms = val ?? false))),
                    const SizedBox(width: 12),
                    Expanded(child: Text('I am at least 16 years old and I agree to the Terms & Conditions', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade300 : Colors.black87))),
                  ],
                ),
                const SizedBox(height: 30),
                
                SizedBox(height: 52, child: ElevatedButton(onPressed: _handleRegister, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0), child: const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)))),
                const SizedBox(height: 40),
              ],
            ),
          ),
      ),
    );
  }
}
