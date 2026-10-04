class ApiConfig {
  static const String baseUrl = 'https://academy.kainuwa.africa/api/mobile';
  static const String login = '$baseUrl/login.php';
  static const String googleAuth = '$baseUrl/google_auth.php';
  static const String registerNative = '$baseUrl/register_native.php';
  static const String verifyOtp = '$baseUrl/verify_otp.php';
  static const String courses = '$baseUrl/courses.php';
  static const String myCourses = '$baseUrl/my_courses.php';
  static const String courseLessons = '$baseUrl/course_lessons.php';
  static const String saveProgress = '$baseUrl/save_progress.php';
  static const String dashboardData = '$baseUrl/dashboard_data.php';
  static const String userProfile = '$baseUrl/user_profile.php';
  static const String myDownloads = '$baseUrl/my_downloads.php';
  static const String courseDetails = '$baseUrl/course_details.php?slug=';
  static const String getWishlist = '$baseUrl/get_wishlist.php';
  static const String toggleWishlist = '$baseUrl/toggle_wishlist.php'; 
  static const String uploadAvatar = '$baseUrl/upload_avatar.php';
  static const String getDownloadLink = '$baseUrl/get_download_link.php';
  static const String changePassword = '$baseUrl/change_password.php';
  static const String saveFcmToken = '$baseUrl/save_fcm_token.php';
  static const String appSettings = '$baseUrl/app_settings.php';
  static const String locations = '$baseUrl/locations.php';
  static const String checkUsername = '$baseUrl/check_username.php';
  static const String helpCenter = '$baseUrl/help_center_data.php';
  static const String getProfileDetails = '$baseUrl/get_profile_details.php';
  static const String updateProfile = '$baseUrl/update_profile.php';
  static const String categories = '$baseUrl/categories.php';
  static const String getInstructor = '$baseUrl/get_instructor.php';

  // NEW: secure login system
  static const String webviewTicket = '$baseUrl/webview_ticket.php';
  static const String logout = '$baseUrl/logout.php';

  // Google "Web client ID" (looks like 1234567890-abcdef.apps.googleusercontent.com).
  // Find it in Firebase Console -> Authentication -> Sign-in method -> Google -> Web SDK configuration,
  // or Google Cloud Console -> APIs & Services -> Credentials -> "Web client (auto created by Google Service)".
  // PASTE IT BETWEEN THE QUOTES. While it is empty, Google sign-in only works while the server is in legacy mode.
  static const String googleWebClientId = '678276904298-qupbes3rsk9kk7a5q3s90gd4kdrc7koc.apps.googleusercontent.com';
}