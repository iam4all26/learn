import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import 'api_client.dart';

class AuthService {
  // serverClientId makes Google give the app an ID token that the server can verify.
  // Set ApiConfig.googleWebClientId (see lib/config/api_config.dart).
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: ApiConfig.googleWebClientId.isEmpty ? null : ApiConfig.googleWebClientId,
  );

  // Kept between the Google sign-in and the Google registration screen
  static String? _pendingGoogleIdToken;

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        body: {'email': email, 'password': password, 'device': 'Kainuwa Academy app'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final user = UserModel.fromJson(data);
          await _saveUserData(user.token, user.id);
          return {'success': true, 'message': 'Login successful'};
        } else {
          return {'success': false, 'message': data['message'] ?? 'Login failed'};
        }
      }
      if (response.statusCode == 429) {
        try {
          final data = json.decode(response.body);
          return {'success': false, 'message': data['message'] ?? 'Too many attempts. Please wait a few minutes.'};
        } catch (_) {}
        return {'success': false, 'message': 'Too many attempts. Please wait a few minutes.'};
      }
      return {'success': false, 'message': 'Server error'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // FIX: Force sign out first so the Google Account Picker ALWAYS shows up
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return {'success': false, 'message': 'Sign-in aborted'};

      // The ID token is Google's proof that this person really owns this email
      String? idToken;
      try {
        final googleAuth = await googleUser.authentication;
        idToken = googleAuth.idToken;
      } catch (_) {}

      final response = await http.post(
        Uri.parse(ApiConfig.googleAuth),
        body: {
          'id_token': idToken ?? '',
          // Only used by the server while it still supports old app versions
          'email': googleUser.email,
          'full_name': googleUser.displayName ?? '',
          'device': 'Kainuwa Academy app',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 426) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          await _saveUserData(data['token'], data['user_id']);
          return {'success': true, 'message': 'Login successful'};
        } else if (data['status'] == 'not_found') {
          _pendingGoogleIdToken = idToken;
          return {
            'success': false, 
            'needs_registration': true, 
            'email': googleUser.email, 
            'name': googleUser.displayName ?? ''
          };
        } else {
          await _googleSignIn.signOut();
          return {'success': false, 'message': data['message'] ?? 'Error verifying Google account'};
        }
      }
      await _googleSignIn.signOut();
      return {'success': false, 'message': 'Server error communicating with API'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> register(Map<String, String> userData) async {
    try {
      final body = Map<String, String>.from(userData);
      if (body['auth_provider'] == 'google' && _pendingGoogleIdToken != null) {
        body['google_id_token'] = _pendingGoogleIdToken!;
      }
      final response = await http.post(
        Uri.parse(ApiConfig.registerNative),
        body: body,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') { _pendingGoogleIdToken = null; }
        return {'success': data['status'] == 'success', 'message': data['message'] ?? 'Error'};
      }
      if (response.statusCode == 429) {
        return {'success': false, 'message': 'Too many sign-up attempts. Please try again later.'};
      }
      return {'success': false, 'message': 'Server error'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.verifyOtp),
        body: {'email': email, 'otp': otp},
      );
      if (response.statusCode == 200 || response.statusCode == 429) {
        final data = json.decode(response.body);
        return {'success': data['status'] == 'success', 'message': data['message'] ?? 'Error'};
      }
      return {'success': false, 'message': 'Server error'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  /// Signs this device out on the server and clears the saved login.
  Future<void> logout() async {
    await ApiClient.logoutOnServer();
    try { await _googleSignIn.signOut(); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> _saveUserData(String token, int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setInt('user_id', userId);
  }
}