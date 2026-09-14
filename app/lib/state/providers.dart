import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../data/models/app_settings.dart';
import '../data/models/icon_ref.dart';
import '../data/models/probe_status.dart';
import '../data/models/service_item.dart';
import '../data/repositories/service_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/sources/prefs_json_store.dart';
import '../domain/probe/reachability_probe.dart';
import '../platform/platform_bridge.dart';
import 'web_session_registry.dart';

// ---------------------------------------------------------------------------
// Infrastructure
// ---------------------------------------------------------------------------

/// Overridden in `main()` once `SharedPreferences` has loaded. Loading it
/// synchronously before `runApp` is what lets every notifier below expose a
/// plain (non-async) value, which keeps the whole UI free of `AsyncValue`
/// handling.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

final serviceRepositoryProvider = Provider<ServiceRepository>(
  (ref) => ServiceRepository(PrefsJsonStore(ref.watch(prefsProvider))),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(PrefsJsonStore(ref.watch(prefsProvider))),
);

final probeServiceProvider = Provider<ReachabilityProbe>(
  (ref) => const ReachabilityProbe(),
);

final platformBridgeProvider = Provider<PlatformBridge>(
  (ref) => const PlatformBridge(),
);

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsRepositoryProvider).load();

  void update(AppSettings Function(AppSettings current) change) {
    final next = change(state);
    if (next == state) return;
    state = next;
    unawaited(ref.read(settingsRepositoryProvider).save(next));
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

class ServicesNotifier extends Notifier<List<ServiceItem>> {
  static const Uuid _uuid = Uuid();
  Timer? _saveTimer;

  @override
  List<ServiceItem> build() {
    ref.onDispose(() => _saveTimer?.cancel());
    return ref.read(serviceRepositoryProvider).load();
  }

  bool get isFull => state.length >= K.maxServices;

  /// Pinned services float to the front, then position order applies; positions
  /// are renumbered so they stay contiguous after a delete.
  void _commit(List<ServiceItem> next) {
    final ordered = List<ServiceItem>.of(next)
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    state = ServiceRepository.renumber(ordered);

    _saveTimer?.cancel();
    _saveTimer = Timer(K.saveDebounce, () {
      unawaited(ref.read(serviceRepositoryProvider).save(state));
    });
  }

  ServiceItem? add({
    required String name,
    required String url,
    IconRef? icon,
    bool pinned = false,
    bool probeEnabled = true,
    bool desktopMode = false,
  }) {
    if (isFull) return null;
    final cleanName = name.trim().isEmpty ? 'Service' : name.trim();
    final item = ServiceItem(
      id: _uuid.v4(),
      name: cleanName,
      url: url,
      icon:
          icon ??
          IconRef.monogram(
            cleanName,
            accent: kAccentSwatches[state.length % kAccentSwatches.length],
          ),
      sortOrder: state.length,
      pinned: pinned,
      probeEnabled: probeEnabled,
      desktopMode: desktopMode,
      createdAt: DateTime.now(),
    );
    _commit(<ServiceItem>[...state, item]);
    return item;
  }

  void update(ServiceItem item) {
    _commit(<ServiceItem>[
      for (final existing in state)
        if (existing.id == item.id) item else existing,
    ]);
    // A changed address must not keep serving the old page from a warm session.
    ref.read(sessionRegistryProvider).invalidateIfOriginChanged(item);
  }

  void remove(String id) {
    ref.read(sessionRegistryProvider).close(id);
    _commit(<ServiceItem>[
      for (final existing in state)
        if (existing.id != id) existing,
    ]);
  }

  ServiceItem? duplicate(String id) {
    if (isFull) return null;
    final source = state.where((s) => s.id == id).firstOrNull;
    if (source == null) return null;
    final copy = ServiceItem(
      id: _uuid.v4(),
      name: '${source.name} (copy)',
      url: source.url,
      icon: source.icon,
      sortOrder: state.length,
      pinned: false,
      probeEnabled: source.probeEnabled,
      desktopMode: source.desktopMode,
      createdAt: DateTime.now(),
    );
    _commit(<ServiceItem>[...state, copy]);
    return copy;
  }

  /// Bulk replace, used by the import path.
  void replaceAll(List<ServiceItem> items) =>
      _commit(items.take(K.maxServices).toList());
}

final servicesProvider = NotifierProvider<ServicesNotifier, List<ServiceItem>>(
  ServicesNotifier.new,
);

// ---------------------------------------------------------------------------
// WebView sessions
// ---------------------------------------------------------------------------

final sessionRegistryProvider = Provider<WebSessionRegistry>((ref) {
  final registry = WebSessionRegistry(
    capacity: ref.read(settingsProvider).sessionCapacity,
    bridge: ref.read(platformBridgeProvider),
  );
  registry.setExternalLinkPolicy(
    ref.read(settingsProvider).externalLinkPolicy,
  );
  ref.listen<AppSettings>(settingsProvider, (previous, next) {
    registry.setCapacity(next.sessionCapacity);
    registry.setExternalLinkPolicy(next.externalLinkPolicy);
  });
  // Native tells us when a WebView renderer is reclaimed. Without this the OS
  // would have killed the whole app instead.
  PlatformBridge.setRenderProcessGoneHandler(registry.handleRenderProcessGone);
  ref.onDispose(() {
    PlatformBridge.setRenderProcessGoneHandler(null);
    registry.dispose();
  });
  return registry;
});

// ---------------------------------------------------------------------------
// Reachability probing
// ---------------------------------------------------------------------------

class ProbeNotifier extends Notifier<Map<String, ProbeStatus>> {
  Timer? _timer;
  final Set<String> _inFlight = <String>{};
  bool _disposed = false;

  @override
  Map<String, ProbeStatus> build() {
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
      _timer = null;
    });

    ref.listen<AppSettings>(settingsProvider, (previous, next) => _syncTimer());

    // Kick off the cold-start sweep after the first frame so it never competes
    // with the initial layout.
    Future<void>.microtask(() {
      _syncTimer();
      if (ref.read(settingsProvider).autoProbe) unawaited(probeAll());
    });

    return const <String, ProbeStatus>{};
  }

  Future<void> probeOne(ServiceItem service) async {
    if (_disposed) return;
    if (!service.probeEnabled || !service.isConfigured) {
      _set(service.id, const ProbeStatus.unknown());
      return;
    }
    final uri = service.uri;
    if (uri == null || _inFlight.contains(service.id)) return;

    _inFlight.add(service.id);
    _set(service.id, const ProbeStatus.checking());
    try {
      final result = await ref.read(probeServiceProvider).probe(uri);
      _set(service.id, result);
    } finally {
      _inFlight.remove(service.id);
    }
  }

  /// Probes every enabled, configured service with a bounded concurrency so ten
  /// cards never open ten sockets at once.
  Future<void> probeAll() async {
    if (_disposed) return;
    final targets = ref
        .read(servicesProvider)
        .where((service) => service.probeEnabled && service.isConfigured)
        .toList(growable: false);

    final queue = List<ServiceItem>.of(targets);
    Future<void> worker() async {
      while (queue.isNotEmpty && !_disposed) {
        await probeOne(queue.removeAt(0));
      }
    }

    final workers = <Future<void>>[
      for (var i = 0; i < K.probeConcurrency && i < targets.length; i++)
        worker(),
    ];
    await Future.wait(workers);
  }

  /// Re-probes only when the cached result has gone stale — used on resume.
  Future<void> probeStale() async {
    if (_disposed) return;
    final cutoff = DateTime.now().subtract(K.probeFreshness);
    final targets = ref
        .read(servicesProvider)
        .where(
          (service) =>
              service.probeEnabled &&
              service.isConfigured &&
              (state[service.id]?.checkedAt?.isAfter(cutoff) != true),
        )
        .toList(growable: false);
    if (targets.isEmpty) return;
    for (final service in targets) {
      unawaited(probeOne(service));
    }
  }

  void clearFor(String id) => _set(id, const ProbeStatus.unknown());

  void _set(String id, ProbeStatus status) {
    if (_disposed) return;
    state = <String, ProbeStatus>{...state, id: status};
  }

  void _syncTimer() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;

    final settings = ref.read(settingsProvider);
    if (!settings.autoProbe) return;

    _timer = Timer.periodic(Duration(seconds: settings.probeIntervalSec), (_) {
      if (_disposed) return;
      // Never probe while a service is in the foreground: the probe would
      // compete with the page load for the tunnel.
      if (settings.onlyProbeOnHome &&
          ref.read(sessionRegistryProvider).hasActive) {
        return;
      }
      unawaited(probeAll());
    });
  }
}

final probeProvider =
    NotifierProvider<ProbeNotifier, Map<String, ProbeStatus>>(
      ProbeNotifier.new,
    );

// ---------------------------------------------------------------------------
// Derived: VPN state and the Tailscale banner
// ---------------------------------------------------------------------------

/// Null means "the platform could not tell us".
final vpnStateProvider = FutureProvider<bool?>(
  (ref) => ref.read(platformBridgeProvider).isVpnActive(),
);

/// The five banner states from `docs/UI_SPEC.md` §2.2.
enum BannerState { connected, checking, vpnOff, servicesDown, allDisabled }

final bannerProvider = Provider<BannerState>((ref) {
  final settings = ref.watch(settingsProvider);
  final services = ref.watch(servicesProvider);
  final probes = ref.watch(probeProvider);
  final vpn = switch (ref.watch(vpnStateProvider)) {
    AsyncData(:final value) => value,
    _ => null,
  };

  final watched = services
      .where((service) => service.probeEnabled && service.isConfigured)
      .toList(growable: false);

  if (watched.isEmpty || !settings.autoProbe) return BannerState.allDisabled;

  final statuses = <ProbeStatus?>[
    for (final service in watched) probes[service.id],
  ];

  if (statuses.any((status) => status?.isOnline ?? false)) {
    return BannerState.connected;
  }
  if (statuses.any((status) => status?.isChecking ?? false)) {
    return BannerState.checking;
  }
  // Nothing has reported back yet.
  if (statuses.every((status) => status == null)) return BannerState.checking;
  if (!statuses.any((status) => status?.isOffline ?? false)) {
    return BannerState.checking;
  }

  // Everything that answered is down. Blame the VPN only when we know it is up
  // or down; an unknown VPN state still gets the more actionable message.
  if (vpn == false) return BannerState.vpnOff;
  return BannerState.servicesDown;
});
