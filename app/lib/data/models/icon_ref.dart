import 'package:flutter/material.dart';

/// How a service's icon is drawn.
enum IconKind { material, monogram, emoji }

/// A service icon: a glyph, a monogram or an emoji, plus its accent colour.
///
/// Material glyphs are stored by *name* and resolved through [kMaterialIcons]
/// rather than by codepoint. Building `IconData` from a runtime codepoint is
/// incompatible with Flutter's icon tree-shaking, so a static map is the only
/// release-safe option.
@immutable
class IconRef {
  const IconRef({
    required this.kind,
    required this.value,
    required this.accent,
  });

  factory IconRef.monogram(String name, {int? accent}) {
    final trimmed = name.trim();
    // `runes` rather than `substring` so an emoji or accented first character
    // is not sliced in half.
    final letter = trimmed.isEmpty
        ? '?'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    return IconRef(
      kind: IconKind.monogram,
      value: letter,
      accent: accent ?? kAccentSwatches.first,
    );
  }

  final IconKind kind;
  final String value;
  final int accent;

  IconData? get iconData =>
      kind == IconKind.material ? kMaterialIcons[value] : null;

  IconRef copyWith({IconKind? kind, String? value, int? accent}) => IconRef(
    kind: kind ?? this.kind,
    value: value ?? this.value,
    accent: accent ?? this.accent,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.name,
    'value': value,
    'accent': accent,
  };

  static IconRef fromJson(Map<String, dynamic> json, {String fallbackName = ''}) {
    final kindName = json['kind'] as String?;
    final kind = IconKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => IconKind.monogram,
    );
    final value = json['value'] as String?;
    final accent = (json['accent'] as num?)?.toInt();
    if (value == null) return IconRef.monogram(fallbackName);
    return IconRef(
      kind: kind,
      value: value,
      accent: accent ?? kAccentSwatches.first,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is IconRef &&
      other.kind == kind &&
      other.value == value &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(kind, value, accent);
}

/// Twelve accents offered by the icon picker. The first entry is the default.
const List<int> kAccentSwatches = <int>[
  0xFF22C55E, // green
  0xFF3B82F6, // blue
  0xFFF97316, // orange
  0xFF6C5CE7, // violet
  0xFF14B8A6, // teal
  0xFFEC4899, // pink
  0xFFEAB308, // amber
  0xFFEF4444, // red
  0xFF8B5CF6, // purple
  0xFF0EA5E9, // sky
  0xFF84CC16, // lime
  0xFF64748B, // slate
];

/// Curated glyph set for the picker. Every entry is a compile-time constant so
/// icon tree-shaking keeps working in release builds.
const Map<String, IconData> kMaterialIcons = <String, IconData>{
  'smart_toy': Icons.smart_toy,
  'memory': Icons.memory,
  'dns': Icons.dns,
  'computer': Icons.computer,
  'terminal': Icons.terminal,
  'code': Icons.code,
  'data_object': Icons.data_object,
  'storage': Icons.storage,
  'cloud': Icons.cloud,
  'insights': Icons.insights,
  'analytics': Icons.analytics,
  'dashboard': Icons.dashboard,
  'monitor_heart': Icons.monitor_heart,
  'rocket_launch': Icons.rocket_launch,
  'hub': Icons.hub,
  'router': Icons.router,
  'wifi': Icons.wifi,
  'security': Icons.security,
  'vpn_key': Icons.vpn_key,
  'key': Icons.key,
  'lock': Icons.lock,
  'bug_report': Icons.bug_report,
  'build': Icons.build,
  'settings': Icons.settings,
  'tune': Icons.tune,
  'home': Icons.home,
  'note': Icons.sticky_note_2,
  'description': Icons.description,
  'send': Icons.send,
  'chat': Icons.chat,
  'forum': Icons.forum,
  'photo': Icons.photo,
  'video_library': Icons.video_library,
  'music_note': Icons.music_note,
  'movie': Icons.movie,
  'games': Icons.sports_esports,
  'book': Icons.menu_book,
  'school': Icons.school,
  'science': Icons.science,
  'biotech': Icons.biotech,
  'calendar_month': Icons.calendar_month,
  'schedule': Icons.schedule,
  'timer': Icons.timer,
  'folder': Icons.folder,
  'download': Icons.download,
  'upload': Icons.upload,
  'print': Icons.print,
  'shopping_cart': Icons.shopping_cart,
  'payments': Icons.payments,
  'account_balance': Icons.account_balance,
  'wallet': Icons.account_balance_wallet,
  'monitor': Icons.monitor,
  'tv': Icons.tv,
  'podcasts': Icons.podcasts,
  'map': Icons.map,
  'public': Icons.public,
  'language': Icons.language,
  'translate': Icons.translate,
  'person': Icons.person,
  'groups': Icons.groups,
  'favorite': Icons.favorite,
  'star': Icons.star,
  'bolt': Icons.bolt,
  'local_fire_department': Icons.local_fire_department,
};

/// Default glyph suggested when a new service is created.
const String kDefaultIconName = 'dns';

/// A few friendly suggestions so the picker opens on something plausible.
const String kDefaultEmoji = '\u{1F680}';
