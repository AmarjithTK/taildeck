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
///
/// One session exists per *tab*, not per service: every tab of a loaded
/// service stays mounted so switching tabs never resets page state.
class WebSession {
  WebSession({
    required this.serviceId,
    required this.tabId,
    required this.controller,
    required this.origin,
    required this.service,
  });

  final String serviceId;

  /// The [ServiceTab.id] this WebView belongs to.
  final String tabId;
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

/// Keeps every opened service mounted, with one WebView per tab.
///
/// The LRU capacity counts *services*, and eviction drops whole services —
/// never the visible one, never a single tab out of a loaded service. The
/// default capacity keeps every card warm; an evicted service still resumes
/// its persisted tab URLs instead of the service default, so state is
/// retained as closely as possible in every path: backgrounding, Recents,
/// in-app switching, and full restarts.
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

  /// Live WebViews, keyed by `serviceId::tabId`. Eviction order for services
  /// lives in `_lru`.
  final Map<String, WebSession> _sessions = <String, WebSession>{};

  /// Reverse lookup so a renderer death can be attributed to a service.
  final Map<int, String> _webViewIds = <int, String>{};

  /// Set to the service name when its renderer was reclaimed. `RootShell`
  /// listens and surfaces it; cleared by the reader.
  final ValueNotifier<String?> lastRendererCrash = ValueNotifier<String?>(null);

  /// Called (debounced by the receiver) when a tab navigates somewhere new,
  /// so the tab's current URL — not its original URL — is what persists.
  void Function(String serviceId, String tabId, String url)? onTabUrlChanged;

  int _clock = 0;

  static String sessionKey(String serviceId, String tabId) =>
      '$serviceId::$tabId';

  int get capacity => _lru.capacity;
  String? get activeId => _lru.activeId;

  /// The service currently in the foreground, if any.
  String? get activeServiceId => _lru.activeId;

  /// The selected tab of the foreground service, if any.
  String? get activeTabId => activeSession?.tabId;

  /// The foreground tab's session, if any.
  WebSession? get activeSession {
    final serviceId = _lru.activeId;
    if (serviceId == null) return null;
    final group = sessionsFor(serviceId);
    if (group.isEmpty) return null;
    final wanted = group.first.service.activeTabId;
    return sessionFor(serviceId, wanted) ?? group.first;
  }

  bool get hasActive => _lru.activeId != null;
  bool get isEmpty => _sessions.isEmpty;

  /// Every live WebView, across all services and tabs.
  List<WebSession> get live => List<WebSession>.unmodifiable(_sessions.values);

  /// Service ids with at least one live tab, oldest first. Drives the
  /// `WebLayer` child list.
  List<String> get liveServiceIds => List<String>.unmodifiable(
    _lru.order.where((id) => sessionsFor(id).isNotEmpty),
  );

  /// One snapshot per loaded service, oldest first.
  List<ServiceItem> get liveServices => List<ServiceItem>.unmodifiable(
    <ServiceItem>[
      for (final id in liveServiceIds) sessionsFor(id).first.service,
    ],
  );

  /// Every live tab session of one service.
  List<WebSession> sessionsFor(String serviceId) =>
      List<WebSession>.unmodifiable(
        _sessions.values.where((s) => s.serviceId == serviceId),
      );

  WebSession? sessionFor(String serviceId, [String? tabId]) {
    if (tabId != null) return _sessions[sessionKey(serviceId, tabId)];
    final group = sessionsFor(serviceId);
    if (group.isEmpty) return null;
    final wanted = group.first.service.activeTabId;
    return _sessions[sessionKey(serviceId, wanted)] ?? group.first;
  }

  /// Whether any tab of the service is loaded.
  bool isLive(String id) => _sessions.keys.any((k) => k.startsWith('$id::'));

  /// Index into `[sentinel, ...liveServices]`, used by the `IndexedStack`.
  int get activeIndex => _lru.activeIndex;

  void setExternalLinkPolicy(ExternalLinkPolicy policy) {
    _linkPolicy = policy;
  }

  /// Creates or reuses a session for every tab of [service] and makes the
  /// service the visible one. Tabs that were already warm keep their exact
  /// page state; only new tabs load.
  WebSession acquire(ServiceItem service, {String? tabId}) {
    for (final tab in service.tabs) {
      final key = sessionKey(service.id, tab.id);
      var session = _sessions[key];
      session ??= _sessions[key] = _create(service, tab);
      session.service = service;
      session.lastUsedAt = ++_clock;
    }
    _lru.touch(service.id);
    _evictOverflow();
    final activeTab = tabId ?? service.activeTabId;
    final session = sessionFor(service.id, activeTab) ?? sessionsFor(service.id).first;
    _notify();
    return session;
  }

  /// Switches the selected tab inside an already-visible service without
  /// touching any other service's state.
  void selectTab(String serviceId, String tabId) {
    final session = _sessions[sessionKey(serviceId, tabId)];
    if (session == null) return;
    for (final s in sessionsFor(serviceId)) {
      s.service = s.service.copyWith(activeTabId: tabId);
      s.lastUsedAt = ++_clock;
    }
    _lru.touch(serviceId);
    _notify();
  }

  /// Refreshes snapshots after a model change and makes the live sessions
  /// match the service's tab list: sessions for removed tabs are dropped,
  /// sessions for new tabs are created warm. The `main` tab tracks the
  /// service's default address, so when that address changed the stale page
  /// is dropped and the new origin loads instead of showing the old page.
  void noteServiceUpdated(ServiceItem service) {
    if (!isLive(service.id)) return;
    final wanted = <String>{for (final tab in service.tabs) tab.id};
    for (final key in _sessions.keys.toList(growable: false)) {
      final session = _sessions[key]!;
      if (session.serviceId != service.id) continue;
      if (!wanted.contains(session.tabId)) {
        _disposeSessionKey(key);
        continue;
      }
      final tab = service.tabs.firstWhere((t) => t.id == session.tabId);
      final tabOrigin = originOf(tab.url);
      if (tab.id == 'main' &&
          tabOrigin != null &&
          session.origin != tabOrigin) {
        // The service address was edited: reload this tab from the new
        // origin rather than serving the old page.
        _disposeSessionKey(key);
      } else {
        session.service = service;
      }
    }
    for (final tab in service.tabs) {
      final key = sessionKey(service.id, tab.id);
      var session = _sessions[key];
      session ??= _sessions[key] = _create(service, tab);
      session.service = service;
      session.lastUsedAt = ++_clock;
    }
    if (sessionsFor(service.id).isEmpty) _lru.forget(service.id);
    _notify();
  }

  /// Drops sessions whose tabs no longer exist (e.g. after a tab was closed
  /// in the model) and refreshes snapshots. Sessions are never reloaded here:
  /// closing a tab must not disturb the surviving tabs.
  void syncTabsFor(ServiceItem service) {
    if (!isLive(service.id)) return;
    noteServiceUpdated(service);
  }

  /// Drops every service group except [ids] — the import path.
  void pruneExcept(Set<String> ids) {
    var changed = false;
    for (final key in _sessions.keys.toList(growable: false)) {
      if (!ids.contains(_sessions[key]!.serviceId)) {
        _disposeSessionKey(key);
        changed = true;
      }
    }
    if (changed) _notify();
  }

  /// Drops all sessions without discarding anything else. Used by Reset.
  void closeAll() {
    if (_sessions.isEmpty) return;
    for (final key in _sessions.keys.toList(growable: false)) {
      _disposeSessionKey(key);
    }
    _notify();
  }

  /// Hides the service view without destroying anything. This is what the back
  /// button does once page history is exhausted, and what leaving TailDeck via
  /// system navigation amounts to: *deactivate*, never dispose, so every
  /// service stays exactly where it was.
  void deactivate() {
    if (_lru.activeId == null) return;
    _lru.deactivate();
    _notify();
  }

  /// Explicitly drops one service — every tab — the `Close session` action.
  /// Kept under this name so existing callers keep compiling.
  void close(String id) => closeService(id);

  void closeService(String serviceId) {
    if (!isLive(serviceId)) return;
    for (final key in _sessions.keys.toList(growable: false)) {
      if (_sessions[key]!.serviceId == serviceId) _disposeSessionKey(key);
    }
    _notify();
  }

  /// Drops a warm session when its address changed, so the next open loads the
  /// new origin instead of showing the old page (risk register §15).
  void invalidateIfOriginChanged(ServiceItem service) {
    noteServiceUpdated(service);
  }

  void setCapacity(int value) {
    final next = value.clamp(K.minSessionCapacity, K.maxSessionCapacity);
    if (next == _lru.capacity) return;
    _lru.setCapacity(next);
    _evictOverflow();
    _notify();
  }

  Future<void> reload(String serviceId, [String? tabId]) async {
    final session = sessionFor(serviceId, tabId);
    if (session == null) return;
    session.loadError.value = null;
    await session.controller.reload();
    await _syncHistory(session);
  }

  Future<void> goBack(String serviceId, [String? tabId]) async {
    final session = sessionFor(serviceId, tabId);
    if (session == null) return;
    if (!await session.controller.canGoBack()) return;
    await session.controller.goBack();
    await _syncHistory(session);
  }

  Future<void> goForward(String serviceId, [String? tabId]) async {
    final session = sessionFor(serviceId, tabId);
    if (session == null) return;
    if (!await session.controller.canGoForward()) return;
    await session.controller.goForward();
    await _syncHistory(session);
  }

  /// Loads [url] into one tab, e.g. after the address bar was edited. The new
  /// URL is reported through [onTabUrlChanged] like any other navigation, so
  /// it persists.
  Future<void> loadUrl(String serviceId, String tabId, Uri url) async {
    final session = sessionFor(serviceId, tabId);
    if (session == null) return;
    session.loadError.value = null;
    try {
      await session.controller.loadRequest(url);
    } on Object {
      session.loadError.value = 'Could not load the page';
    }
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
    for (final key in _sessions.keys.toList(growable: false)) {
      _disposeSessionKey(key);
    }
    lastRendererCrash.dispose();
    super.dispose();
  }

  // -- internals ---------------------------------------------------------

  WebSession _create(ServiceItem service, ServiceTab tab) {
    final controller = WebViewController();
    final session = WebSession(
      serviceId: service.id,
      tabId: tab.id,
      controller: controller,
      origin: originOf(tab.url.isEmpty ? service.url : tab.url) ?? '',
      service: service,
    );
    unawaited(_configure(session, service, tab));
    return session;
  }

  Future<void> _configure(
    WebSession session,
    ServiceItem service,
    ServiceTab tab,
  ) async {
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
        // General panning/scrolling for every site, not just mobile-shaped
        // ones: desktop-oriented pages (server dashboards, editors, admin
        // consoles) routinely exceed the phone viewport in one or both axes,
        // and the user must be able to reach the oversized parts. These are
        // deliberately unconditional — no per-site opt-in.
        await android.enableZoom(true);
        await android.setVerticalScrollBarEnabled(true);
        await android.setHorizontalScrollBarEnabled(true);
        await android.setUseWideViewPort(true);
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
          onUrlChange: (change) {
            final url = change.url;
            if (url == null || url.isEmpty) return;
            final uri = Uri.tryParse(url);
            if (uri == null) return;
            if (uri.scheme != 'http' && uri.scheme != 'https') return;
            // Remember where this tab actually is, so a restart resumes the
            // current page rather than the tab's original URL.
            onTabUrlChanged?.call(session.serviceId, session.tabId, url);
            unawaited(_syncHistory(session));
          },
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

    final rawTarget = tab.url.isEmpty ? service.url : tab.url;
    final target = rawTarget.isEmpty
        ? null
        : Uri.tryParse(rawTarget) ?? service.uri;
    if (target == null || target.host.isEmpty) {
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
    // `evictionCandidates` never returns the active service, so if everything
    // left is on screen we simply stay over budget for now. Eviction drops
    // whole services (all their tabs together), never one tab of a group.
    for (final victim in _lru.evictionCandidates()) {
      closeService(victim);
    }
  }

  void _disposeSessionKey(String key) {
    final session = _sessions.remove(key);
    if (session == null) return;
    if (sessionsFor(session.serviceId).isEmpty) {
      _lru.forget(session.serviceId);
    }
    final identifier = session.webViewIdentifier;
    if (identifier != null) _webViewIds.remove(identifier);
    unawaited(session.dispose());
  }

  /// A renderer was reclaimed by the OS. The native guard keeps the app alive;
  /// our job is to drop the now-unusable WebView and say so.
  void handleRenderProcessGone(int webViewIdentifier) {
    final serviceId = _webViewIds.remove(webViewIdentifier);
    if (serviceId == null) return;
    final group = sessionsFor(serviceId);
    if (group.isEmpty) return;

    lastRendererCrash.value = group.first.service.name;
    closeService(serviceId);
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }
}
