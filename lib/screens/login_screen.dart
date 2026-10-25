import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/kaida_loader.dart';
import '../utils/kaida_alert.dart';
import '../widgets/auth_shell.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main_layout.dart';
import 'register_screen.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      KaidaAlert.showModal(context: context, title: 'Action Required', message: 'Please fill all fields.', isError: true);
      return;
    }
    
    setState(() => _isLoading = true);
    final result = await _authService.login(_emailController.text.trim(), _passwordController.text);
    if (mounted) setState(() => _isLoading = false);

    if (result['success']) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayout()));
    } else {
      if (!mounted) return;
      KaidaAlert.showModal(context: context, title: 'Authentication Error', message: result['message'], isError: true);
    }
  }

  void _handleGoogleLogin() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    
    final result = await _authService.signInWithGoogle();
    
    if (mounted) setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayout()));
    } else if (result['needs_registration'] == true) {
      if (!mounted) return;
      // FIX: Wait for the user to confirm the modal BEFORE navigating
      KaidaAlert.showModal(
        context: context, 
        title: 'Almost There', 
        message: 'Please complete your profile details to finish signing up.', 
        isError: false,
        onConfirm: () {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(
              builder: (_) => RegisterScreen(
                prefillEmail: result['email'],
                prefillName: result['name'],
              )
            )
          );
        }
      );
    } else {
      if (!mounted) return;
      KaidaAlert.showModal(context: context, title: 'Authentication Error', message: result['message'], isError: true);
    }
  }

  Future<void> _openForgotPassword() async {
    final uri = Uri.parse('https://academy.kainuwa.africa/forgot_password');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) KaidaAlert.showModal(context: context, title: 'Could not open', message: 'Please open academy.kainuwa.africa/forgot_password in your browser.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AuthShell(
      title: 'Sign In',
      subtitle: 'Continue learning new skills with Kainuwa Academy.',
      activeTab: 0,
      loading: _isLoading,
      onBack: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen())),
      onSignInTab: () {},
      onSignUpTab: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(icon: Icons.mail_outline_rounded, hint: 'Email address', controller: _emailController, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 14),
          AuthField(
            icon: Icons.lock_outline_rounded,
            hint: 'Password',
            controller: _passwordController,
            isPassword: true,
            obscure: _obscurePassword,
            onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _openForgotPassword,
              child: const Text('Forgot password?', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
          ),
          const SizedBox(height: 4),
          AuthPrimaryButton(label: 'Sign In', onPressed: _handleLogin),
          const SizedBox(height: 22),
          const AuthOrDivider(),
          const SizedBox(height: 20),
          AuthGoogleButton(onPressed: _handleGoogleLogin, googleIcon: const FaIcon(FontAwesomeIcons.google, color: Colors.redAccent, size: 20)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : const Color(0xFFF0EDFF), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.groups_rounded, color: AppTheme.primaryColor, size: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('No account yet?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('Create a free account and start learning new skills today.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.3)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}