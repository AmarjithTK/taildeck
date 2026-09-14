import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper that stores a schema-versioned JSON object under one key.
///
/// Deliberately not a database: the app keeps at most ten records plus one
/// settings blob, both read once at startup.
class PrefsJsonStore {
  const PrefsJsonStore(this._prefs);

  final SharedPreferences _prefs;

  /// Returns null when the key is absent, empty, unparseable or not an object.
  /// Corrupt data degrades to "no data" rather than crashing the launch.
  Map<String, dynamic>? read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> write(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  /// Preserves a copy of data written by a newer schema before we overwrite it.
  Future<void> backup(String key, Map<String, dynamic> value) => _prefs.setString(
    '$key.backup.${DateTime.now().millisecondsSinceEpoch}',
    jsonEncode(value),
  );

  Future<void> remove(String key) => _prefs.remove(key);
}
