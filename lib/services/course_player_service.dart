import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class CoursePlayerService {
  /// true when the last curriculum came from the phone's saved copy (no internet)
  bool lastFromCache = false;

  // CHANGED: From Map<String, dynamic> to dynamic so it accepts Lists without crashing
  Future<dynamic> getCourseDetails(int courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final cacheKey = 'course_curriculum_$courseId';

    if (userId == null) return null;
    lastFromCache = false;

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.courseLessons),
        body: {
          'course_id': courseId.toString(),
          'user_id': userId.toString(),
        }
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // the shared client answers from the phone's saved copy when there is no internet
          lastFromCache = response.headers['x-kaida-from-saved'] == '1';
          prefs.setString(cacheKey, json.encode(data['data']));
          return data['data'];
        }
      }
    } catch (e) {
      // no internet: fall through to the saved copy below
    }
    // offline, timed out or the server answered badly: use the copy saved the last time this course was opened
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      try {
        lastFromCache = true;
        return json.decode(cached);
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveVideoProgress(int lessonId, double secondsWatched) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null) return;

      await http.post(
        Uri.parse(ApiConfig.saveProgress),
        body: {
          'user_id': userId.toString(),
          'lesson_id': lessonId.toString(),
          'seconds_watched': secondsWatched.toString(),
        },
      ).timeout(const Duration(seconds: 5));
    } catch (e) {}
  }
}