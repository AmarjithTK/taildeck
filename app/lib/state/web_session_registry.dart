import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/constants.dart';
import '../core/url_utils.dart';
import '../data/models/app_settings.dart';
import '../data/models/service_item.dart';
import '../platform/platform_bridge.dart';
import '../theme/app_theme.dart';
import 'session_lru.dart';

/// Desktop User-Agent used when a service has `desktopMode` enabled.
const String kDesktopUserAgent =
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/124.0.0.0 Safari/537.36';

/// Maps a WebView failure onto the copy deck in `docs/UI_SPEC.md` §10.
String describeLoadError(String? description) {
  final d = (description ?? '').toLowerCase();
  if (d.contains('err_connection_refused') || d.contains('connection refused')) {
    return 'Connection refused';
  }
  if (d.contains('err_connection_timed_out') ||
      d.contains('timeout') ||
      d.contains('timed out')) {
    return 'Connection timed out';
  }
  if (d.contains('err_name_not_resolved') ||
      d.contains('err_name_resolution') ||
      d.contains('host lookup') ||
      d.contains('nodename')) {
    return 'Host not found';
  }
  if (d.contains('err_address_unreachable') ||
      d.contains('err_network_changed') ||
      d.contains('unreachable') ||
      d.contains('no route')) {
    return 'No route to host';
  }
  if (d.contains('err_cleartext_not_permitted')) {
    return 'Cleartext HTTP is blocked';
  }
  if (d.contains('ssl') || d.contains('certificate')) {
    return 'TLS handshake failed';
  }
  return 'Could not load the page';
}

/// One live WebView plus the tiny pieces of state its overlays need.
///
/// There is deliberately no `controller.dispose()`: `webview_flutter` v4 has no
/// such API, and the native WebView is owned by the `WebViewWidget`. Dropping
/// the session from the registry's list removes the widget, which is what
/// actually frees it.
class WebSession {
  WebSession({
    required this.serviceId,
    required this.controller,
    required this.origin,
    required this.service,
  });

  final String serviceId;
  final WebViewController controller;

  /// Origin captured when the session was created. Compared against the
  /// service's current origin so an address edit invalidates a stale page.
  final String origin;

  /// Snapshot for the overlays. Refreshed on every [WebSessionRegistry.acquire]
  /// so a rename or icon change shows up without rebuilding the WebView.
  ServiceItem service;

  final ValueNotifier<double> progress = ValueNotifier<double>(0);
  final ValueNotifier<bool> loading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> loadError = ValueNotifier<String?>(null);

  /// Whether the toolbar's back/forward buttons should be enabled. Kept here
  /// rather than read straight from the controller because `canGoBack()` is
  /// async and the toolbar needs a synchronous, listenable value.
  final ValueNotifier<bool> canGoBack = ValueNotifier<bool>(false);
  final ValueNotifier<bool> canGoForward = ValueNotifier<bool>(false);

  /// Identifier the native plugin uses for this WebView. Only set on Android,
  /// and only once the controller has been configured.
  int? webViewIdentifier;

  /// Monotonic use counter. Higher means more recently used.
  int lastUsedAt = 0;

  bool _disposed = false;
  bool get isDisposed => _disposed;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    progress.dispose();
    loading.dispose();
    loadError.dispose();
    canGoBack.dispose();
    canGoForward.dispose();
  }
}

/// Keeps at most [capacity] WebViews mounted, evicting the least recently used.
///
/// This is the mechanism that lets a service view have **no tab strip** while
/// still restoring page state: the widgets stay in the tree (see `WebLayer`)
/// and this class decides which ones survive.
class WebSessionRegistry extends ChangeNotifier {
  WebSessionRegistry({
    int capacity = K.defaultSessionCapacity,
    this.bridge = const PlatformBridge(),
  }) : _lru = SessionLru(capacity);

  /// Used to hand non-tailnet URLs to the system browser.
  final PlatformBridge bridge;

  final SessionLru _lru;
  ExternalLinkPolicy _linkPolicy = ExternalLinkPolicy.external;
  bool _disposed = false;

  /// Live WebViews, keyed by service id. Eviction order lives in `_lru`.
  final Map<String, WebSession> _sessions = <String, WebSession>{};

  /// Reverse lookup so a renderer death can be attributed to a service.
  final Map<int, String> _webViewIds = <int, String>{};

  /// Set to the service name when its renderer was reclaimed. `RootShell`
  /// listens and surfaces it; cleared by the reader.
  final ValueNotifier<String?> lastRendererCrash = ValueNotifier<String?>(null);

  int _clock = 0;

  int get capacity => _lru.capacity;
  String? get activeId => _lru.activeId;
  bool get hasActive => _lru.activeId != null;
  bool get isEmpty => _sessions.isEmpty;

  /// LRU order, oldest first. Drives the `WebLayer` child list.
  List<WebSession> get live => List<WebSession>.unmodifiable(_sessions.values);

  WebSession? sessionFor(String id) => _sessions[id];
  bool isLive(String id) => _sessions.containsKey(id);

  /// Index into `[sentinel, ...live]`, used by the `IndexedStack`.
  int get activeIndex => _lru.activeIndex;

  void setExternalLinkPolicy(ExternalLinkPolicy policy) {
    _linkPolicy = policy;
  }

  /// Creates or reuses a session and makes it the visible one.
  WebSession acquire(ServiceItem service) {
    final existing = _sessions.remove(service.id);
    final session = existing ?? _create(service);
    session.service = service;
    session.lastUsedAt = ++_clock;
    _sessions[service.id] = session;
    _lru.touch(service.id);
    _evictOverflow();
    _notify();
    return session;
  }

  /// Hides the service view without destroying anything. This is what the back
  /// button does once page history is exhausted.
  void deactivate() {
    if (_lru.activeId == null) return;
    _lru.deactivate();
    _notify();
  }

  /// Explicitly drops one session — the `Close session` menu action.
  void close(String id) {
    if (!_sessions.containsKey(id)) return;
    _disposeSession(id);
    _notify();
  }

  /// Drops a warm session when its address changed, so the next open loads the
  /// new origin instead of showing the old page (risk register §15).
  void invalidateIfOriginChanged(ServiceItem service) {
    final session = _sessions[service.id];
    if (session == null) return;
    final next = service.origin;
    if (next != null && next == session.origin) return;
    close(service.id);
  }

  void setCapacity(int value) {
    final next = value.clamp(K.minSessionCapacity, K.maxSessionCapacity);
    if (next == _lru.capacity) return;
    _lru.setCapacity(next);
    _evictOverflow();
    _notify();
  }

  Future<void> reload(String id) async {
    final session = _sessions[id];
    if (session == null) return;
    session.loadError.value = null;
    await session.controller.reload();
    await _syncHistory(session);
  }

  Future<void> goBack(String id) async {
    final session = _sessions[id];
    if (session == null) return;
    if (!await session.controller.canGoBack()) return;
    await session.controller.goBack();
    await _syncHistory(session);
  }

  Future<void> goForward(String id) async {
    final session = _sessions[id];
    if (session == null) return;
    if (!await session.controller.canGoForward()) return;
    await session.controller.goForward();
    await _syncHistory(session);
  }

  /// Mirrors the controller's history state onto the session so the toolbar can
  /// bind to it synchronously.
  Future<void> _syncHistory(WebSession session) async {
    try {
      final back = await session.controller.canGoBack();
      final forward = await session.controller.canGoForward();
      if (session.isDisposed) return;
      session.canGoBack.value = back;
      session.canGoForward.value = forward;
    } on Object {
      // A history query must never take down the view.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final id in _sessions.keys.toList(growable: false)) {
      _disposeSession(id);
    }
    lastRendererCrash.dispose();
    super.dispose();
  }

  // -- internals ---------------------------------------------------------

  WebSession _create(ServiceItem service) {
    final controller = WebViewController();
    final session = WebSession(
      serviceId: service.id,
      controller: controller,
      origin: service.origin ?? '',
      service: service,
    );
    unawaited(_configure(session, service));
    return session;
  }

  Future<void> _configure(WebSession session, ServiceItem service) async {
    final controller = session.controller;

    try {
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(AppColors.bg);
      await controller.setUserAgent(
        service.desktopMode ? kDesktopUserAgent : null,
      );

      AndroidWebViewController? android;
      final platform = controller.platform;
      if (platform is AndroidWebViewController) {
        android = platform;
        await platform.setMediaPlaybackRequiresUserGesture(true);
        await platform.setGeolocationEnabled(false);
        // Nothing else is needed here, and that is worth recording:
        // DOM storage, `window.open` and multi-window support are already
        // switched on by AndroidWebViewController's own constructor, and its
        // chrome client forwards `onCreateWindow` back through this WebView's
        // WebViewClient. The native code then re-loads the popup URL into
        // *this* WebView, where it passes through `_decide` below. That is what
        // keeps the "no tab graveyard" promise with no extra plumbing: a
        // `target="_blank"` link behaves exactly like a normal navigation.
      }

      await controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) => session.progress.value = value / 100,
          onPageStarted: (_) {
            session.loading.value = true;
            session.loadError.value = null;
            unawaited(_syncHistory(session));
          },
          onPageFinished: (_) {
            session.loading.value = false;
            unawaited(_syncHistory(session));
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
            session.loading.value = false;
            session.loadError.value = describeLoadError(error.description);
            unawaited(_syncHistory(session));
          },
          onNavigationRequest: (request) => _decide(request.url),
        ),
      );

      // Android kills the whole process when a WebView renderer dies unless the
      // client claims ownership of the event, and `webview_flutter` does not.
      // Arm the native guard, and remember whose WebView this is so the death
      // can be attributed to the right card.
      if (android != null) {
        final identifier = android.webViewIdentifier;
        session.webViewIdentifier = identifier;
        _webViewIds[identifier] = session.serviceId;
        await bridge.guardRenderProcess(identifier);
      }
    } on Object {
      // A failed configuration must not leave a blank screen with no
      // explanation; let the load attempt below surface the real error.
      session.loadError.value = null;
    }

    final target = service.uri;
    if (target == null) {
      session.loadError.value = 'Tap to configure';
      return;
    }
    try {
      await controller.loadRequest(target);
    } on Object {
      session.loadError.value = 'Could not load the page';
    }
  }

  /// Implements the external-link policy: private services stay in the WebView,
  /// everything else goes to the system browser (the default), loads in-app, or
  /// is refused.
  NavigationDecision _decide(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return NavigationDecision.prevent;

    const passthrough = <String>{
      'http',
      'https',
      'about',
      'data',
      'blob',
      'javascript',
    };
    if (!passthrough.contains(uri.scheme)) {
      // `tel:`, `mailto:`, `intent:` and friends belong to the OS.
      unawaited(bridge.openExternal(url));
      return NavigationDecision.prevent;
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return NavigationDecision.navigate;
    }

    if (isTailnetUri(uri)) return NavigationDecision.navigate;

    switch (_linkPolicy) {
      case ExternalLinkPolicy.inApp:
        return NavigationDecision.navigate;
      case ExternalLinkPolicy.external:
        unawaited(bridge.openExternal(url));
        return NavigationDecision.prevent;
      case ExternalLinkPolicy.block:
        return NavigationDecision.prevent;
    }
  }

  void _evictOverflow() {
    // `evictionCandidates` never returns the active session, so if everything
    // left is on screen we simply stay over budget for now.
    for (final victim in _lru.evictionCandidates()) {
      _disposeSession(victim);
    }
  }

  void _disposeSession(String id) {
    final session = _sessions.remove(id);
    _lru.forget(id);
    if (session == null) return;
    final identifier = session.webViewIdentifier;
    if (identifier != null) _webViewIds.remove(identifier);
    unawaited(session.dispose());
  }

  /// A renderer was reclaimed by the OS. The native guard keeps the app alive;
  /// our job is to drop the now-unusable WebView and say so.
  void handleRenderProcessGone(int webViewIdentifier) {
    final serviceId = _webViewIds.remove(webViewIdentifier);
    if (serviceId == null) return;
    final session = _sessions[serviceId];
    if (session == null) return;

    lastRendererCrash.value = session.service.name;
    _disposeSession(serviceId);
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }
}
