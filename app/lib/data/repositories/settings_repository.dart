import '../models/app_settings.dart';
import '../sources/prefs_json_store.dart';

/// Loads and persists app settings.
class SettingsRepository {
  const SettingsRepository(this._store);

  final PrefsJsonStore _store;

  static const String storageKey = 'taildeck.settings.v1';
  static const int schemaVersion = 1;

  AppSettings load() {
    final json = _store.read(storageKey);
    if (json == null) return const AppSettings();
    try {
      return AppSettings.fromJson(json);
    } on Object {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) => _store.write(storageKey, <String, dynamic>{
    'schema': schemaVersion,
    ...settings.toJson(),
  });

  Future<void> reset() => _store.remove(storageKey);
}
