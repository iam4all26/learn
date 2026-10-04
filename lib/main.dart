import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_theme.dart';
import 'config/theme_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';

void main() {
  // Every http.get / http.post in the app now sends the login token automatically
  http.runWithClient(() => _startApp(), () => KaidaHttpClient());
}

Future<void> _startApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('auth_token');

  Widget initialScreen;
  if (token != null && token.isNotEmpty) {
    // User is logged in -> Show the minimalist Splash Screen
    initialScreen = const SplashScreen();
  } else {
    // User is NOT logged in -> Bypass Splash and go directly to Onboarding
    initialScreen = const OnboardingScreen();
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: KaidaApp(initialScreen: initialScreen),
    ),
  );
}

class KaidaApp extends StatelessWidget {
  final Widget initialScreen;
  
  const KaidaApp({Key? key, required this.initialScreen}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Kainuwa Academy',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode, 
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: initialScreen,
    );
  }
}