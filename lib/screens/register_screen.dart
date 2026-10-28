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
import '../widgets/auth_shell.dart';
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
    if (_fullNameController.text.isEmpty || _usernameController.text.isEmpty || _emailController.text.isEmpty || (widget.prefillEmail == null && _passwordController.text.isEmpty)) {
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
    if (widget.prefillEmail == null && _passwordsMatch == false) {
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
      'password': widget.prefillEmail != null ? '' : _passwordController.text,
      'auth_provider': widget.prefillEmail != null ? 'google' : 'email',
    };

    final result = await _authService.register(userData);

    if (result['success']) {
      if (!mounted) return;
      if (widget.prefillEmail != null) {
        // Bypass OTP, Login Directly, Go to Dashboard
        // The server already signed this Google user in (token saved by AuthService.register)
        if (result['logged_in'] != true) {
          if (mounted) setState(() => _isLoading = false);
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
          return;
        }
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

  void _handleGoogleSignUp() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    final result = await _authService.signInWithGoogle();
    if (mounted) setState(() => _isLoading = false);
    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayout()));
    } else if (result['needs_registration'] == true) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RegisterScreen(prefillEmail: result['email'], prefillName: result['name'])));
    } else {
      KaidaAlert.showModal(context: context, title: 'Authentication Error', message: result['message'], isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget? usernameStatus;
    if (_isCheckingUsername) {
      usernameStatus = const Padding(padding: EdgeInsets.only(right: 6), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
    } else if (_isUsernameAvailable == true) {
      usernameStatus = const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.check_circle, color: Colors.green, size: 19));
    } else if (_isUsernameAvailable == false) {
      usernameStatus = const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.cancel, color: Colors.red, size: 19));
    }

    Widget? passwordStatus;
    if (_passwordsMatch == true) {
      passwordStatus = const Padding(padding: EdgeInsets.only(right: 2), child: Icon(Icons.check_circle, color: Colors.green, size: 19));
    } else if (_passwordsMatch == false) {
      passwordStatus = const Padding(padding: EdgeInsets.only(right: 2), child: Icon(Icons.cancel, color: Colors.red, size: 19));
    }

    final isGoogle = widget.prefillEmail != null;

    return AuthShell(
      title: 'Create Account',
      subtitle: isGoogle ? 'Complete your details to finish signing up.' : 'Join thousands of learners and start learning new skills with Kainuwa Academy.',
      activeTab: 1,
      loading: _isLoading,
      onBack: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
      onSignInTab: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
      onSignUpTab: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(icon: Icons.person_outline_rounded, label: 'Full Name', hint: 'e.g. Usama Musa Gudu', controller: _fullNameController),
          const SizedBox(height: 12),
          AuthField(icon: Icons.alternate_email_rounded, label: 'Username', hint: 'e.g. usamgudu', controller: _usernameController, onChanged: _onUsernameChanged, status: usernameStatus),
          if (_isUsernameAvailable == false)
            const Padding(padding: EdgeInsets.only(left: 6, top: 4), child: Text('Username is already taken', style: TextStyle(color: Colors.red, fontSize: 11.5, fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          AuthField(icon: Icons.mail_outline_rounded, label: 'Email', hint: 'e.g. usama@example.com', controller: _emailController, readOnly: isGoogle, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          AuthSelectRow(icon: Icons.translate_rounded, label: 'Preferred Language', value: _selectedLanguage == 'ha' ? 'Hausa' : 'English', placeholder: 'Select', onTap: () => _openSelectionSheet(title: 'Language', items: _languages, onSelect: (id, name) => setState(() => _selectedLanguage = id))),
          const SizedBox(height: 12),
          AuthSelectRow(icon: Icons.public_rounded, label: 'Country', value: _selectedCountryName, placeholder: 'Select country', disabled: _countries.isEmpty, onTap: () => _openSelectionSheet(title: 'Country', items: _countries, onSelect: (id, name) { setState(() { _selectedCountryId = id; _selectedCountryName = name; }); _fetchStates(id); })),
          const SizedBox(height: 12),
          AuthSelectRow(icon: Icons.map_outlined, label: 'State', value: _selectedStateName, placeholder: 'Select state', disabled: _states.isEmpty, onTap: () => _openSelectionSheet(title: 'State', items: _states, onSelect: (id, name) { setState(() { _selectedStateId = id; _selectedStateName = name; }); _fetchCities(id); })),
          const SizedBox(height: 12),
          AuthSelectRow(icon: Icons.location_city_rounded, label: 'City', value: _selectedCityName, placeholder: 'Select city', disabled: _cities.isEmpty, onTap: () => _openSelectionSheet(title: 'City', items: _cities, onSelect: (id, name) => setState(() { _selectedCityId = id; _selectedCityName = name; }))),
          const SizedBox(height: 12),
          if (!isGoogle) ...[
          AuthField(icon: Icons.lock_outline_rounded, label: 'Password', hint: 'Create a password', controller: _passwordController, isPassword: true, obscure: _obscurePassword, onChanged: (v) => _onPasswordChanged(), onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword)),
          const SizedBox(height: 12),
          AuthField(icon: Icons.lock_reset_rounded, label: 'Confirm Password', hint: 'Repeat your password', controller: _confirmPasswordController, isPassword: true, obscure: _obscureConfirmPassword, onChanged: (v) => _onPasswordChanged(), onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword), status: passwordStatus),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 24, width: 24, child: Checkbox(value: _agreeTerms, activeColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), onChanged: (val) => setState(() => _agreeTerms = val ?? false))),
              const SizedBox(width: 12),
              Expanded(child: Text('I am at least 16 years old and I agree to the Terms & Conditions and Privacy Policy.', style: TextStyle(fontSize: 13, height: 1.35, color: isDark ? Colors.grey.shade300 : Colors.black87))),
            ],
          ),
          const SizedBox(height: 20),
          AuthPrimaryButton(label: 'Create Account', onPressed: _handleRegister),
          if (!isGoogle) ...[
            const SizedBox(height: 18),
            const AuthOrDivider(),
            const SizedBox(height: 16),
            AuthGoogleButton(onPressed: _handleGoogleSignUp, googleIcon: const FaIcon(FontAwesomeIcons.google, color: Colors.redAccent, size: 20)),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account? ', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              GestureDetector(
                onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('Sign in now', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}