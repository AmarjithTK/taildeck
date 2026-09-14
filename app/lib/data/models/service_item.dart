import 'package:flutter/foundation.dart';

import '../../core/url_utils.dart';
import 'icon_ref.dart';

/// One card in the grid — ARCHITECTURE.md §4.1.
///
/// [url] is stored already normalised, so the WebView, the probe and the card
/// subtitle all read the same canonical string.
@immutable
class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.name,
    required this.url,
    required this.icon,
    required this.sortOrder,
    required this.createdAt,
    this.pinned = false,
    this.probeEnabled = true,
    this.desktopMode = false,
  });

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
  }) => ServiceItem(
    id: id,
    name: name ?? this.name,
    url: url ?? this.url,
    icon: icon ?? this.icon,
    sortOrder: sortOrder ?? this.sortOrder,
    pinned: pinned ?? this.pinned,
    probeEnabled: probeEnabled ?? this.probeEnabled,
    desktopMode: desktopMode ?? this.desktopMode,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'url': url,
    'icon': icon.toJson(),
    'sortOrder': sortOrder,
    'pinned': pinned,
    'probeEnabled': probeEnabled,
    'desktopMode': desktopMode,
    'createdAt': createdAt.toIso8601String(),
  };

  static ServiceItem fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?) ?? 'Service';
    final iconJson = json['icon'];
    return ServiceItem(
      id: (json['id'] as String?) ?? '',
      name: name,
      url: (json['url'] as String?) ?? '',
      icon: iconJson is Map<String, dynamic>
          ? IconRef.fromJson(iconJson, fallbackName: name)
          : IconRef.monogram(name),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      pinned: (json['pinned'] as bool?) ?? false,
      probeEnabled: (json['probeEnabled'] as bool?) ?? true,
      desktopMode: (json['desktopMode'] as bool?) ?? false,
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
      other.desktopMode == desktopMode;

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
  );

  @override
  String toString() => 'ServiceItem($name, $url)';
}
