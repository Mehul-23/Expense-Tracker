import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'activity.dart';

class ActivityService {
  static const _key = 'activity_logs';

  static Future<void> logActivity(Activity activity) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> logs = prefs.getStringList(_key) ?? [];

    logs.add(jsonEncode(activity.toMap()));
    await prefs.setStringList(_key, logs);
  }

  static Future<List<Activity>> getActivities() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> logs = prefs.getStringList(_key) ?? [];

    return logs.map((log) => Activity.fromMap(jsonDecode(log))).toList().reversed.toList();
  }
}
