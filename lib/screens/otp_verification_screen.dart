import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/kaida_loader.dart';
import 'login_screen.dart';
import '../utils/kaida_alert.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({Key? key, required this.email}) : super(key: key);

  @override
  _OtpVerificationScreenState createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> with WidgetsBindingObserver {
  final _otpController = TextEditingController();
  final _focus = FocusNode();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _resending = false;

  // The server keeps a code valid for 15 minutes. The app counts from when this screen opens.
  static const int _validSeconds = 15 * 60;
  static const int _resendWait = 60;
  int _left = _validSeconds;
  int _resendLeft = _resendWait;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_left > 0) _left--;
        if (_resendLeft > 0) _resendLeft--;
      });
    });
    _checkClipboardForOTP();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _otpController.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboardForOTP();
  }

  void _checkClipboardForOTP() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      final text = data.text!.trim();
      if (RegExp(r'^\d{6}$').hasMatch(text) && _otpController.text != text && mounted) {
        setState(() => _otpController.text = text);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code detected'), backgroundColor: Colors.green));
      }
    }
  }

  String _mmss(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  void _verifyOTP() async {
    FocusScope.of(context).unfocus();
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the 6-digit code')));
      return;
    }
    setState(() => _isLoading = true);
    final result = await _authService.verifyOtp(widget.email, _otpController.text.trim());
    if (mounted) setState(() => _isLoading = false);

    if (!mounted) return;
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account verified! Please log in.'), backgroundColor: Colors.green));
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(KaidaAlert.friendly(result['message'])), backgroundColor: Colors.red));
    }
  }

  Future<void> _resend() async {
    if (_resendLeft > 0 || _resending) return;
    setState(() => _resending = true);
    String msg = 'Could not resend the code. Try again.';
    bool ok = false;
    try {
      final r = await http.post(Uri.parse(ApiConfig.resendOtp), body: {'email': widget.email});
      final data = json.decode(r.body);
      msg = data['message']?.toString() ?? msg;
      ok = data['status'] == 'success';
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _resending = false;
      if (ok) { _left = _validSeconds; _resendLeft = _resendWait; _otpController.clear(); }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red));
  }

  Widget _box(int i, bool isDark) {
    final text = _otpController.text;
    final filled = i < text.length;
    final active = i == text.length && _focus.hasFocus;
    return Expanded(
      child: Container(
        height: 58,
        margin: EdgeInsets.only(right: i == 5 ? 0 : 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppTheme.primaryColor : (isDark ? Colors.grey.shade700 : Colors.grey.shade300), width: active ? 2 : 1.2),
        ),
        child: Center(child: Text(filled ? text[i] : '', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF16123A)))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;
    final expired = _left == 0;

    return Scaffold(
      backgroundColor: const Color(0xFF3A22C4),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // ----- hero -----
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(20, topPad + 8, 20, 54),
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF3A22C4), Color(0xFF6B47F5)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(onTap: () => Navigator.maybePop(context), child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26)),
                          const SizedBox(width: 14),
                          Image.asset('assets/kainuwa_academy_whitelogo.png', height: 40, fit: BoxFit.contain),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Verify Your\nCode', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -0.8)),
                                const SizedBox(height: 10),
                                Text('We sent a verification code to your email.', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14.5, height: 1.4)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 110, height: 110,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(Icons.mark_email_unread_rounded, size: 92, color: Color(0xFFFFC21A)),
                                Positioned(right: 0, bottom: 4, child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: const Color(0xFF6B47F5), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                  child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
                                )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ----- white sheet -----
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - topPad - 200),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
                    decoration: BoxDecoration(color: isDark ? AppTheme.darkBackgroundColor : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.mail_outline_rounded, color: AppTheme.primaryColor, size: 26),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Code sent to', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF16123A))),
                                  const SizedBox(height: 2),
                                  Text(widget.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.primaryColor)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.maybePop(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                child: const Row(children: [
                                  Icon(Icons.edit_outlined, size: 16, color: AppTheme.primaryColor),
                                  SizedBox(width: 5),
                                  Text('Change', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 12.5)),
                                ]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Text('Enter the code', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: isDark ? Colors.white : const Color(0xFF16123A))),
                        const SizedBox(height: 4),
                        Text('Enter the 6-digit code we sent you.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5)),
                        const SizedBox(height: 16),
                        // 6 boxes drawn over one hidden field (keeps autofill and paste working)
                        Stack(
                          children: [
                            Row(children: List.generate(6, (i) => _box(i, isDark))),
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0,
                                child: TextField(
                                  controller: _otpController,
                                  focusNode: _focus,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  autofillHints: const [AutofillHints.oneTimeCode],
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: const InputDecoration(counterText: ''),
                                  onChanged: (v) {
                                    setState(() {});
                                    if (v.length == 6) _verifyOTP();
                                  },
                                  onTap: () => setState(() {}),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time_rounded, size: 18, color: Colors.grey.shade600),
                              const SizedBox(width: 6),
                              Text(expired ? 'Code expired. Request a new one.' : 'Code expires in ', style: TextStyle(color: expired ? Colors.red : Colors.grey.shade600, fontSize: 13.5)),
                              if (!expired) Text(_mmss(_left), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 14)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyOTP,
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            child: _isLoading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Text('Verify Code', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                  ]),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('or', style: TextStyle(color: Colors.grey.shade500))),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ]),
                        const SizedBox(height: 14),
                        Center(
                          child: Column(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Didn't get the code?  ", style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF16123A), fontSize: 14)),
                                  GestureDetector(
                                    onTap: _resend,
                                    child: Row(children: [
                                      Icon(Icons.refresh_rounded, size: 19, color: _resendLeft > 0 ? Colors.grey : AppTheme.primaryColor),
                                      const SizedBox(width: 4),
                                      _resending
                                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                          : Text('Resend', style: TextStyle(color: _resendLeft > 0 ? Colors.grey : AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 15)),
                                    ]),
                                  ),
                                ],
                              ),
                              if (_resendLeft > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('You can resend in ${_mmss(_resendLeft)}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5)),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : const Color(0xFFF3F0FF), borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              Container(
                                width: 46, height: 46,
                                decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.shield_rounded, color: AppTheme.primaryColor, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Keep it private', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF16123A))),
                                    const SizedBox(height: 2),
                                    Text('Your code expires soon. Do not share it with anyone.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, height: 1.35)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading) Positioned.fill(child: Container(color: Colors.black26, child: const Center(child: KaidaLoader()))),
        ],
      ),
    );
  }
}