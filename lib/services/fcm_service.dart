import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../screens/course_player_screen.dart';
import '../screens/main_layout.dart';
import '../screens/catalog_screen.dart'; 
import '../screens/item_details_screen.dart'; 

class FcmService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initNotifications(GlobalKey<NavigatorState> navigatorKey) async {
    // Request permission for push notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Configure foreground notification presentation options
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, 
        badge: true, 
        sound: true,
      );

      // Get the FCM token and save it to the server
      String? token = await _firebaseMessaging.getToken();
      if (token != null) await _saveTokenToServer(token);

      // Listen for token refresh events
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _saveTokenToServer(newToken);
      });

      // Handle notification taps when the app is in the background or terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        // Small delay to ensure the MainLayout has mounted before routing
        Future.delayed(const Duration(milliseconds: 500), () {
            _routeFromNotification(navigatorKey, message.data);
        });
      });

      // Handle initial notification if the app was terminated
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        // Longer delay for cold boots from a terminated state
        Future.delayed(const Duration(seconds: 5), () {
          _routeFromNotification(navigatorKey, initialMessage.data);
        });
      }
    }
  }

  void _routeFromNotification(GlobalKey<NavigatorState> navigatorKey, Map<String, dynamic> data) {
    if (navigatorKey.currentState == null) return;
    
    // Extract the action from the message data payload
    final action = data['action'] ?? '';
    
    switch (action) {
      case 'open_course':
        // CRITICAL FIX: Correctly parsing backend broadcast data
        // Extract the actual course details sent from the send_push.php backend
        final courseIdStr = data['course_id']?.toString();
        final courseId = int.tryParse(courseIdStr ?? '0') ?? 0;
        final actualCourseTitle = data['course_title']?.toString() ?? 'Course'; // NOT the notification title
        final slug = data['course_slug']?.toString() ?? '';
        
        // Ensure all required data is present before attempting to route
        if (courseId > 0 && slug.isNotEmpty) {
          // Create the dynamic CatalogItem placeholder with the real course data
          CatalogItem dummyItem = CatalogItem(
            id: courseId, 
            title: actualCourseTitle, // Now correctly shows e.g., 'Smartphone Graphics Design'
            slug: slug, 
            thumbnailUrl: data['course_thumbnail']?.toString() ?? '', 
            price: double.tryParse(data['course_price']?.toString() ?? '0') ?? 0.0, 
            discountPrice: double.tryParse(data['course_discount_price']?.toString() ?? '0') ?? 0.0, 
            isFree: data['course_is_free']?.toString() == '1', 
            instructorName: 'Loading...', 
            categoryName: 'Course', 
            language: 'EN', 
            type: 'courses', 
            productType: 'digital'
          ); 
          // Navigate directly to the item details screen passing the prepared item
          navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => ItemDetailsScreen(item: dummyItem)));
        } else {
            // Failsafe: If crucial data is missing (e.g., slug), route to the notifications center
            navigatorKey.currentState!.pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const MainLayout(initialIndex: 5)), (route) => false);
        }
        break;
        
      case 'open_dashboard':
        // Handle action to open the learner dashboard tab (index 3)
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainLayout(initialIndex: 5)),
          (Route<dynamic> route) => false, 
        );
        break;
        
      default:
        // Handle open_app and unhandled actions (do nothing, let MainLayout load)
        break;
    }
  }

  Future<void> _saveTokenToServer(String token) async {
    // Attempt to save the FCM token to the server associated with the logged-in user
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId != null) {
      try {
        await http.post(Uri.parse(ApiConfig.saveFcmToken), body: {'user_id': userId.toString(), 'token': token});
      } catch (e) {
        // Silent error handling for network issues
      }
    }
  }
}