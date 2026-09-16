import 'package:flutter/foundation.dart';

import '../../core/url_utils.dart';
import 'icon_ref.dart';

/// Orientation lock belonging to one service card.
///
/// This is per-app state, never a global switch: opening a landscape service
/// must not force every other service into landscape.
enum AppOrientation {
  /// Follow the device / system rotation policy.
  system,

  /// Lock to portrait while this service is in the foreground.
  portrait,

  /// Lock to landscape while this service is in the foreground.
  landscape;

  String get label => switch (this) {
    AppOrientation.system => 'System default',
    AppOrientation.portrait => 'Portrait',
    AppOrientation.landscape => 'Landscape',
  };

  static AppOrientation fromName(String? name) =>
      AppOrientation.values.firstWhere(
        (v) => v.name == name,
        orElse: () => AppOrientation.system,
      );
}

/// One independently addressable tab inside a service.
///
/// Tabs belong to their service, not to TailDeck globally. Each tab keeps its
/// own URL, and that URL is editable: navigating inside the tab (or editing
/// the address bar) updates it, and the new URL is what gets persisted and
/// restored — never the tab's original URL.
@immutable
class ServiceTab {
  const ServiceTab({
    required this.id,
    required this.label,
    required this.url,
    required this.createdAt,
  });

  /// The tab every service starts with. The id is fixed (not random) so a
  /// service that never used tabs round-trips through JSON deterministically.
  static ServiceTab main(String url) => ServiceTab(
    id: 'main',
    label: 'Tab 1',
    url: url,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  final String id;
  final String label;

  /// The tab's current URL — updated as the user navigates, not just the URL
  /// the tab was created with.
  final String url;
  final DateTime createdAt;

  ServiceTab copyWith({String? label, String? url}) => ServiceTab(
    id: id,
    label: label ?? this.label,
    url: url ?? this.url,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'url': url,
    'createdAt': createdAt.toIso8601String(),
  };

  static ServiceTab fromJson(Map<String, dynamic> json, String fallbackUrl) =>
      ServiceTab(
        id: (json['id'] as String?) ?? 'main',
        label: (json['label'] as String?) ?? 'Tab 1',
        url: (json['url'] as String?) ?? fallbackUrl,
        createdAt:
            DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  @override
  bool operator ==(Object other) =>
      other is ServiceTab &&
      other.id == id &&
      other.label == label &&
      other.url == url;

  @override
  int get hashCode => Object.hash(id, label, url);

  @override
  String toString() => 'ServiceTab($label, $url)';
}

/// One card in the grid — ARCHITECTURE.md §4.1.
///
/// [url] is stored already normalised, so the WebView, the probe and the card
/// subtitle all read the same canonical string. It is the service's *default*
/// address (used for the card subtitle and reachability probing); the
/// per-tab [tabs] list is what the WebViews actually load.
@immutable
class ServiceItem {
  ServiceItem({
    required this.id,
    required this.name,
    required this.url,
    required this.icon,
    required this.sortOrder,
    required this.createdAt,
    this.pinned = false,
    this.probeEnabled = true,
    this.desktopMode = false,
    List<ServiceTab>? tabs,
    String? activeTabId,
    this.orientation = AppOrientation.system,
  }) : tabs = tabs == null || tabs.isEmpty
           ? <ServiceTab>[ServiceTab.main(url)]
           : List<ServiceTab>.unmodifiable(tabs),
       activeTabId =
           activeTabId != null &&
               (tabs ?? const <ServiceTab>[]).any((t) => t.id == activeTabId)
           ? activeTabId
           : (tabs == null || tabs.isEmpty ? 'main' : tabs.first.id);

  final String id;
  final String name;

  /// Normalised address, or the empty string when the card is a placeholder.
  final String url;

  final IconRef icon;
  final int sortOrder;
  final bool pinned;
  final bool probeEnabled;
  final bool desktopMode;
  final DateTime createdAt;

  /// This service's tabs. Never empty: there is always at least the `main`
  /// tab, so callers never need a null case.
  final List<ServiceTab> tabs;

  /// Which tab is currently selected in this service.
  final String activeTabId;

  /// This service's orientation lock. Restored every time the service becomes
  /// active, and persisted across restarts.
  final AppOrientation orientation;

  /// The selected tab, falling back to the first one when the id went stale
  /// (e.g. data written by an older build).
  ServiceTab get activeTab =>
      tabs.where((t) => t.id == activeTabId).firstOrNull ?? tabs.first;

  /// The URL the WebView for the selected tab should show.
  String get activeUrl => activeTab.url.isEmpty ? url : activeTab.url;

  /// A card with no usable address yet. Tapping it goes straight to Edit.
  bool get isConfigured => url.isNotEmpty && isValidServiceUrl(url);

  /// `100.114.10.5:3000` for the card subtitle.
  String get displayHost => url.isEmpty ? 'Tap to configure' : displayHostOf(url);

  /// `http://100.114.10.5:3000`, or null when unconfigured. Identifies the
  /// service so a URL edit can invalidate a warm WebView session.
  String? get origin => url.isEmpty ? null : originOf(url);

  Uri? get uri {
    final result = parseServiceUrl(url);
    return result is UrlParseOk ? result.uri : null;
  }

  ServiceItem copyWith({
    String? name,
    String? url,
    IconRef? icon,
    int? sortOrder,
    bool? pinned,
    bool? probeEnabled,
    bool? desktopMode,
    List<ServiceTab>? tabs,
    String? activeTabId,
    AppOrientation? orientation,
  }) {
    final nextTabs = tabs ?? this.tabs;
    final nextActive =
        activeTabId ??
        (nextTabs.any((t) => t.id == this.activeTabId)
            ? this.activeTabId
            : nextTabs.first.id);
    return ServiceItem(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      pinned: pinned ?? this.pinned,
      probeEnabled: probeEnabled ?? this.probeEnabled,
      desktopMode: desktopMode ?? this.desktopMode,
      tabs: nextTabs,
      activeTabId: nextActive,
      orientation: orientation ?? this.orientation,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'url': url,
    'icon': icon.toJson(),
    'sortOrder': sortOrder,
    'pinned': pinned,
    'probeEnabled': probeEnabled,
    'desktopMode': desktopMode,
    'tabs': <Map<String, dynamic>>[for (final tab in tabs) tab.toJson()],
    'activeTabId': activeTabId,
    'orientation': orientation.name,
    'createdAt': createdAt.toIso8601String(),
  };

  static ServiceItem fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?) ?? 'Service';
    final iconJson = json['icon'];
    final url = (json['url'] as String?) ?? '';
    final rawTabs = json['tabs'];
    List<ServiceTab>? tabs;
    if (rawTabs is List) {
      final parsed = <ServiceTab>[];
      for (final entry in rawTabs) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          final tab = ServiceTab.fromJson(entry, url);
          if (tab.id.isEmpty) continue;
          parsed.add(tab);
        } on Object {
          continue;
        }
      }
      if (parsed.isNotEmpty) tabs = parsed;
    }
    return ServiceItem(
      id: (json['id'] as String?) ?? '',
      name: name,
      url: url,
      icon: iconJson is Map<String, dynamic>
          ? IconRef.fromJson(iconJson, fallbackName: name)
          : IconRef.monogram(name),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      pinned: (json['pinned'] as bool?) ?? false,
      probeEnabled: (json['probeEnabled'] as bool?) ?? true,
      desktopMode: (json['desktopMode'] as bool?) ?? false,
      tabs: tabs,
      activeTabId: json['activeTabId'] as String?,
      orientation: AppOrientation.fromName(json['orientation'] as String?),
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ServiceItem &&
      other.id == id &&
      other.name == name &&
      other.url == url &&
      other.icon == icon &&
      other.sortOrder == sortOrder &&
      other.pinned == pinned &&
      other.probeEnabled == probeEnabled &&
      other.desktopMode == desktopMode &&
      _tabsEqual(other.tabs, tabs) &&
      other.activeTabId == activeTabId &&
      other.orientation == orientation;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    url,
    icon,
    sortOrder,
    pinned,
    probeEnabled,
    desktopMode,
    Object.hashAll(tabs),
    activeTabId,
    orientation,
  );

  @override
  String toString() => 'ServiceItem($name, $url, ${tabs.length} tabs)';

  static bool _tabsEqual(List<ServiceTab> a, List<ServiceTab> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
