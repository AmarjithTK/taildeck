import 'package:flutter/foundation.dart';

import '../../core/constants.dart';

/// What to do when a page navigates outside the tailnet — ARCHITECTURE.md §10.
enum ExternalLinkPolicy {
  /// Load it in the WebView like any other page.
  inApp,

  /// Hand it to the system browser. Keeps private services in TailDeck and the
  /// public web in Brave, which is the default.
  external,

  /// Refuse to follow it.
  block,
}

@immutable
class AppSettings {
  const AppSettings({
    this.sessionCapacity = K.defaultSessionCapacity,
    this.autoProbe = true,
    this.probeIntervalSec = K.defaultProbeIntervalSec,
    this.onlyProbeOnHome = true,
    this.showFloatingBack = false,
    this.externalLinkPolicy = ExternalLinkPolicy.external,
    this.desktopModeDefault = false,
  });

  /// How many WebView sessions stay warm (LRU budget).
  final int sessionCapacity;

  final bool autoProbe;
  final int probeIntervalSec;

  /// Pause the periodic probe while a service is in the foreground, so probing
  /// never competes with a page load.
  final bool onlyProbeOnHome;

  /// A second back control floating at the bottom of the page, for one-handed
  /// reach. Off by default now that the service view has a toolbar with a back
  /// button — two of them is clutter — but kept as an option for anyone who
  /// prefers the bottom of the screen.
  final bool showFloatingBack;
  final ExternalLinkPolicy externalLinkPolicy;
  final bool desktopModeDefault;

  AppSettings copyWith({
    int? sessionCapacity,
    bool? autoProbe,
    int? probeIntervalSec,
    bool? onlyProbeOnHome,
    bool? showFloatingBack,
    ExternalLinkPolicy? externalLinkPolicy,
    bool? desktopModeDefault,
  }) => AppSettings(
    sessionCapacity:
        (sessionCapacity ?? this.sessionCapacity).clamp(
          K.minSessionCapacity,
          K.maxSessionCapacity,
        ),
    autoProbe: autoProbe ?? this.autoProbe,
    probeIntervalSec: probeIntervalSec ?? this.probeIntervalSec,
    onlyProbeOnHome: onlyProbeOnHome ?? this.onlyProbeOnHome,
    showFloatingBack: showFloatingBack ?? this.showFloatingBack,
    externalLinkPolicy: externalLinkPolicy ?? this.externalLinkPolicy,
    desktopModeDefault: desktopModeDefault ?? this.desktopModeDefault,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sessionCapacity': sessionCapacity,
    'autoProbe': autoProbe,
    'probeIntervalSec': probeIntervalSec,
    'onlyProbeOnHome': onlyProbeOnHome,
    'showFloatingBack': showFloatingBack,
    'externalLinkPolicy': externalLinkPolicy.name,
    'desktopModeDefault': desktopModeDefault,
  };

  static AppSettings fromJson(Map<String, dynamic> json) {
    const fallback = AppSettings();
    return AppSettings(
      sessionCapacity:
          (json['sessionCapacity'] as num?)?.toInt() ??
          fallback.sessionCapacity,
      autoProbe: (json['autoProbe'] as bool?) ?? fallback.autoProbe,
      probeIntervalSec:
          (json['probeIntervalSec'] as num?)?.toInt() ??
          fallback.probeIntervalSec,
      onlyProbeOnHome:
          (json['onlyProbeOnHome'] as bool?) ?? fallback.onlyProbeOnHome,
      showFloatingBack:
          (json['showFloatingBack'] as bool?) ?? fallback.showFloatingBack,
      externalLinkPolicy: ExternalLinkPolicy.values.firstWhere(
        (p) => p.name == json['externalLinkPolicy'],
        orElse: () => fallback.externalLinkPolicy,
      ),
      desktopModeDefault:
          (json['desktopModeDefault'] as bool?) ?? fallback.desktopModeDefault,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.sessionCapacity == sessionCapacity &&
      other.autoProbe == autoProbe &&
      other.probeIntervalSec == probeIntervalSec &&
      other.onlyProbeOnHome == onlyProbeOnHome &&
      other.showFloatingBack == showFloatingBack &&
      other.externalLinkPolicy == externalLinkPolicy &&
      other.desktopModeDefault == desktopModeDefault;

  @override
  int get hashCode => Object.hash(
    sessionCapacity,
    autoProbe,
    probeIntervalSec,
    onlyProbeOnHome,
    showFloatingBack,
    externalLinkPolicy,
    desktopModeDefault,
  );
}
