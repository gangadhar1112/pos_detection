import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/pose_template.dart';

class TemplateStorage {
  static const _key = 'saved_templates';

  static Future<void> saveTemplates(List<PoseTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = templates.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }

  static Future<List<PoseTemplate>> loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];
    return jsonList
        .map((jsonStr) => PoseTemplate.fromJson(jsonDecode(jsonStr)))
        .toList();
  }
}
