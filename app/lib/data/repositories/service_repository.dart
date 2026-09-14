import 'dart:async';

import '../models/service_item.dart';
import '../sources/prefs_json_store.dart';

/// Loads and persists the service list — ARCHITECTURE.md §4.2.
class ServiceRepository {
  const ServiceRepository(this._store);

  final PrefsJsonStore _store;

  static const String storageKey = 'taildeck.services.v1';
  static const int schemaVersion = 1;

  /// Never throws. Unreadable or partial data yields as many valid records as
  /// could be recovered, so one bad entry cannot brick the launcher.
  List<ServiceItem> load() {
    final json = _store.read(storageKey);
    if (json == null) return const <ServiceItem>[];

    final schema = (json['schema'] as num?)?.toInt() ?? 0;
    if (schema > schemaVersion) {
      // Written by a newer build. Keep a copy before this build overwrites it.
      unawaited(_store.backup(storageKey, json));
    }

    final rawItems = json['items'];
    if (rawItems is! List) return const <ServiceItem>[];

    final items = <ServiceItem>[];
    for (final entry in rawItems) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        final item = ServiceItem.fromJson(entry);
        if (item.id.isEmpty) continue;
        items.add(item);
      } on Object {
        // Skip individual malformed records rather than failing the whole load.
        continue;
      }
    }
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  Future<void> save(List<ServiceItem> items) => _store.write(storageKey, <String, dynamic>{
    'schema': schemaVersion,
    'items': <Map<String, dynamic>>[for (final item in items) item.toJson()],
  });

  /// Overwrites the stored list with [items] in the given order, renumbering
  /// `sortOrder` so positions stay contiguous after a delete or reorder.
  static List<ServiceItem> renumber(List<ServiceItem> items) => <ServiceItem>[
    for (var i = 0; i < items.length; i++) items[i].copyWith(sortOrder: i),
  ];
}
