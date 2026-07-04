import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Minimal offline cache: stores JSON-encoded strings in a Hive box.
///
/// Deliberately stores everything as encoded strings rather than raw
/// Maps -- Hive can technically store nested Maps directly, but reading
/// them back sometimes yields `Map<dynamic, dynamic>` instead of
/// `Map<String, dynamic>`, which breaks a straight cast. Round-tripping
/// through `jsonEncode`/`jsonDecode` sidesteps that entirely at the cost
/// of a little CPU, which is irrelevant for the small payloads cached
/// here (a profile, a directory listing).
class LocalCache {
  LocalCache._();

  static const _boxName = 'app_cache';
  static Box<String>? _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
  }

  static Map<String, dynamic>? getMap(String key) {
    final raw = _box?.get(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static List<dynamic>? getList(String key) {
    final raw = _box?.get(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setJson(String key, dynamic value) async {
    await _box?.put(key, jsonEncode(value));
  }

  static DateTime? lastUpdated(String key) {
    final raw = _box?.get('$key.__updated_at');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> setJsonWithTimestamp(String key, dynamic value) async {
    await setJson(key, value);
    await _box?.put('$key.__updated_at', DateTime.now().toIso8601String());
  }
}
