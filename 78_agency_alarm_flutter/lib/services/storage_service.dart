import 'package:shared_preferences/shared_preferences.dart';
import '../models/client_task.dart';

class StorageService {
  static const String _tasksKey = 'agency_pulse_tasks_v1';
  static const String _langKey = 'agency_pulse_roman_urdu_v1';

  static Future<List<ClientTask>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tasksKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return ClientTask.decodeList(raw);
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveTasks(List<ClientTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksKey, ClientTask.encodeList(tasks));
  }

  static Future<bool> loadIsRomanUrdu() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_langKey) ?? true;
  }

  static Future<void> saveIsRomanUrdu(bool isRomanUrdu) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_langKey, isRomanUrdu);
  }
}
