// Persistent player progress (shared_preferences, works offline).
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Store {
  Store._(this._prefs, Map<String, dynamic> data) : _d = data;

  static const _key = 'dinoDash.save.v1';
  final SharedPreferences? _prefs;
  Map<String, dynamic> _d;

  static Map<String, dynamic> _defaults() => {
        'hiClassic': 0,
        'hiColor': 0,
        'coins': 0,
        'unlocked': <String>['rex'],
        'selected': 'rex',
        'eggs': 0,
        'lastEggAt': 0,
        'runs': 0,
        'sound': true,
        'forceClassic': false,
      };

  /// Loads the save (never throws; falls back to defaults).
  static Future<Store> load() async {
    SharedPreferences? prefs;
    var data = _defaults();
    try {
      prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) data = {...data, ...(jsonDecode(raw) as Map<String, dynamic>)};
    } catch (_) {}
    return Store._(prefs, _normalize(data));
  }

  /// In-memory store for tests.
  static Store memory([Map<String, dynamic>? initial]) => Store._(null, _normalize({..._defaults(), ...?initial}));

  static Map<String, dynamic> _normalize(Map<String, dynamic> s) {
    var unlocked = ((s['unlocked'] as List?) ?? const []).map((e) => e.toString()).toList();
    if (!unlocked.contains('rex')) unlocked = ['rex', ...unlocked];
    // v1 of the web prototype had a made-up "Neon Rex"; it became the real Brachiosaurus
    unlocked = unlocked.map((id) => id == 'neon' ? 'brachio' : id).toSet().toList();
    s['unlocked'] = unlocked;
    if (s['selected'] == 'neon') s['selected'] = 'brachio';
    return s;
  }

  T get<T>(String k) => _d[k] as T;
  int getInt(String k) => (_d[k] as num).toInt();
  bool getBool(String k) => _d[k] == true;
  List<String> get unlocked => List<String>.from(_d['unlocked'] as List);

  void set(String k, Object v) {
    _d[k] = v;
    _save();
  }

  void update(void Function(Map<String, dynamic> s) fn) {
    fn(_d);
    _save();
  }

  void reset() {
    _d = _defaults();
    _save();
  }

  void _save() {
    try {
      _prefs?.setString(_key, jsonEncode(_d));
    } catch (_) {}
  }
}
