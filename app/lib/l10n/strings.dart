import 'dart:convert';
import 'package:flutter/services.dart';

class TandemStrings {
  static Map<String, String> _strings = {};

  static Future<void> load() async {
    final jsonStr = await rootBundle.loadString('lib/l10n/app_en.json');
    final Map<String, dynamic> map = json.decode(jsonStr);
    _strings = map.map((k, v) => MapEntry(k, v.toString()));
  }

  static String get(String key, [Map<String, String>? params]) {
    String text = _strings[key] ?? key;
    if (params != null) {
      params.forEach((k, v) {
        text = text.replaceAll('{$k}', v);
      });
    }
    return text;
  }
}
