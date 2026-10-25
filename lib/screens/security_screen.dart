import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../widgets/page_header.dart';

/// Change Password screen (the only place in the app to change the password).
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({Key? key}) : super(key: key);

  @override
  _SecurityScreenState createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;
  bool _obscureOld = true, _obscureNew = true, _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _newCtrl.addListener(() => setState(() {}));
    _confirmCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _has8 => _newCtrl.text.length >= 8;
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_newCtrl.text);
  bool get _hasLower => RegExp(r'[a-z]').hasMatch(_newCtrl.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_newCtrl.text);
  bool get _hasSymbol => RegExp(r'[^A-Za-z0-9]').hasMatch(_newCtrl.text);
  bool get _matches => _confirmCtrl.text.isNotEmpty && _confirmCtrl.text == _newCtrl.text;
  bool get _allMet => _has8 && _hasUpper && _hasLower && _hasNumber && _hasSymbol;

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green));
  }

  Future<void> _submit() async {
    if (_oldCtrl.text.isEmpty || _newCtrl.text.isEmpty || _confirmCtrl.text.isEmpty) {
      _snack('Please fill all fields', error: true);
      return;
    }
    if (!_allMet) {
      _snack('Your new password does not meet all the requirements', error: true);
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      _snack('New passwords do not match', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      // Same call as before: user comes from the login token on the server.
      final response = await http.post(
        Uri.parse(ApiConfig.changePassword),
        body: {'current_password': _oldCtrl.text, 'new_password': _newCtrl.text},
      );
      final data = json.decode(response.body);
      if (!mounted) return;
      if (data['status'] == 'success') {
        _snack('Password changed successfully!');
        Navigator.pop(context);
      } else {
        _snack(data['message']?.toString() ?? 'Failed to change password', error: true);
        setState(() => _submitting = false);
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Connection error. Try again.', error: true);
      setState(() => _submitting = false);
    }
  }

  Widget _field(String label, TextEditingController c, bool obscure, VoidCallback toggle, bool isDark, {String hint = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: c,
          obscureText: obscure,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            filled: true,
            fillColor: isDark ? AppTheme.darkSurfaceColor : Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryColor, size: 21),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade500, size: 21),
              onPressed: toggle,
            ),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.6)),
          ),
        ),
      ],
    );
  }

  Widget _rule(String text, bool ok, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 19, color: ok ? const Color(0xFF22A06B) : Colors.grey.shade400),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ok ? (isDark ? Colors.white : Colors.black87) : Colors.grey.shade500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackgroundColor : const Color(0xFFF6F5FB),
      body: Column(
        children: [
          const PageHeader(
            title: 'Change Password',
            subtitle: 'Keep your account safe with a strong password',
            illustration: Icons.lock_rounded,
            bottomPadding: 22,
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field('Current Password', _oldCtrl, _obscureOld, () => setState(() => _obscureOld = !_obscureOld), isDark, hint: 'Enter current password'),
                  const SizedBox(height: 18),
                  _field('New Password', _newCtrl, _obscureNew, () => setState(() => _obscureNew = !_obscureNew), isDark, hint: 'Enter new password'),
                  const SizedBox(height: 18),
                  _field('Confirm New Password', _confirmCtrl, _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm), isDark, hint: 'Re-enter new password'),
                  if (_confirmCtrl.text.isNotEmpty && !_matches)
                    const Padding(
                      padding: EdgeInsets.only(top: 6, left: 4),
                      child: Text('Passwords do not match', style: TextStyle(color: Colors.red, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Password must contain:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 6),
                        _rule('At least 8 characters', _has8, isDark),
                        _rule('One uppercase letter (A-Z)', _hasUpper, isDark),
                        _rule('One lowercase letter (a-z)', _hasLower, isDark),
                        _rule('One number (0-9)', _hasNumber, isDark),
                        _rule('One symbol (!@#\$%^&*)', _hasSymbol, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      icon: _submitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                      label: const Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}