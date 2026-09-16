import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/url_utils.dart';
import '../../../data/models/service_item.dart';
import '../../../platform/app_orientation.dart';
import '../../../state/providers.dart';
import '../../../state/web_session_registry.dart';
import '../../../theme/app_theme.dart';
import '../home/service_actions.dart';
import 'widgets/floating_back_pill.dart';
import 'widgets/service_toolbar.dart';
import 'widgets/web_error_view.dart';

/// One service on screen — `docs/UI_SPEC.md` §3.
///
/// A slim toolbar (back, forward, title, reload, overflow) over a per-service
/// tab strip and an editable address bar, over the page itself. Every tab
/// keeps its own mounted WebView, so switching tabs — or switching services
/// and coming back — resumes the exact page state. Leaving via system
/// navigation only *deactivates* the service; the explicit Back control walks
/// the active tab's WebView history.
class ServiceWebView extends ConsumerStatefulWidget {
  const ServiceWebView({
    super.key,
    required this.serviceId,
    required this.onBack,
    required this.onExit,
  });

  final String serviceId;

  /// Back in the active tab's page history, or out to the grid when history
  /// is exhausted.
  final Future<void> Function() onBack;

  /// Straight to the grid, skipping history (the pill's long press).
  final VoidCallback onExit;

  @override
  ConsumerState<ServiceWebView> createState() => _ServiceWebViewState();
}

class _ServiceWebViewState extends ConsumerState<ServiceWebView> {
  Timer? _pillTimer;
  bool _pillIdle = false;
  late final TextEditingController _urlController;
  late final FocusNode _urlFocus;
  AppOrientation? _appliedOrientation;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _urlFocus = FocusNode();
    _bumpPill();
  }

  @override
  void dispose() {
    _pillTimer?.cancel();
    _urlController.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  void _bumpPill() {
    _pillTimer?.cancel();
    if (_pillIdle && mounted) setState(() => _pillIdle = false);
    _pillTimer = Timer(K.pillIdleDelay, () {
      if (mounted) setState(() => _pillIdle = true);
    });
  }

  Future<void> _retry(WebSession session) async {
    session.loadError.value = null;
    try {
      await session.controller.reload();
    } on Object {
      session.loadError.value = 'Could not load the page';
    }
  }

  void _handleAction(ServiceItem service, ServiceToolbarAction action) {
    final notifier = ref.read(servicesProvider.notifier);
    final registry = ref.read(sessionRegistryProvider);
    final activeUrl = service.activeUrl.isEmpty
        ? service.url
        : service.activeUrl;

    switch (action) {
      case ServiceToolbarAction.openExternal:
        unawaited(ref.read(platformBridgeProvider).openExternal(activeUrl));
      case ServiceToolbarAction.copyAddress:
        unawaited(Clipboard.setData(ClipboardData(text: activeUrl)));
        showToast(context, 'Address copied');
      case ServiceToolbarAction.editService:
        unawaited(editService(context, ref, service));
      case ServiceToolbarAction.unloadPage:
        registry.closeService(service.id);
      case ServiceToolbarAction.orientationSystem:
        notifier.setOrientation(service.id, AppOrientation.system);
        unawaited(applyAppOrientation(AppOrientation.system));
      case ServiceToolbarAction.orientationPortrait:
        notifier.setOrientation(service.id, AppOrientation.portrait);
        unawaited(applyAppOrientation(AppOrientation.portrait));
      case ServiceToolbarAction.orientationLandscape:
        notifier.setOrientation(service.id, AppOrientation.landscape);
        unawaited(applyAppOrientation(AppOrientation.landscape));
    }
  }

  void _submitAddress(ServiceItem service) {
    final raw = _urlController.text;
    final parsed = parseServiceUrl(raw);
    if (parsed is! UrlParseOk) {
      showToast(context, 'That address doesn\u2019t look valid');
      _urlController.text = service.activeUrl;
      return;
    }
    _urlFocus.unfocus();
    unawaited(
      ref
          .read(servicesProvider.notifier)
          .navigateTab(service.id, service.activeTab.id, raw),
    );
  }

  Future<void> _renameTab(ServiceItem service, ServiceTab tab) async {
    final controller = TextEditingController(text: tab.label);
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename tab', style: TextStyle(fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Tab label'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (label == null || !mounted) return;
    ref.read(servicesProvider.notifier).renameTab(service.id, tab.id, label);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(
      servicesProvider.select(
        (services) => services
            .where((s) => s.id == widget.serviceId)
            .firstOrNull,
      ),
    );
    if (service == null) return const SizedBox.shrink();

    // The service's lock applies while it is in the foreground.
    if (_appliedOrientation != service.orientation) {
      _appliedOrientation = service.orientation;
      unawaited(applyAppOrientation(service.orientation));
    }

    final registry = ref.read(sessionRegistryProvider);
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) {
        final sessions = <WebSession>[
          for (final tab in service.tabs)
            ...switch (registry.sessionFor(service.id, tab.id)) {
              final session? => <WebSession>[session],
              null => const <WebSession>[],
            },
        ];
        if (sessions.isEmpty) return const SizedBox.shrink();

        final activeTab = service.activeTab;
        final activeSession =
            registry.sessionFor(service.id, activeTab.id) ?? sessions.first;

        // Keep the address bar on the tab's current URL. While the user is
        // editing, their keystrokes win; otherwise the field follows
        // navigation (including back/forward and link taps).
        if (!_urlFocus.hasFocus && _urlController.text != activeTab.url) {
          _urlController.text = activeTab.url;
        }

        return Column(
          children: <Widget>[
            ServiceToolbar(
              service: service,
              canGoBack: activeSession.canGoBack,
              canGoForward: activeSession.canGoForward,
              loading: activeSession.loading,
              progress: activeSession.progress,
              orientation: service.orientation,
              onBack: () {
                _bumpPill();
                unawaited(widget.onBack());
              },
              onForward: () => unawaited(
                registry.goForward(service.id, activeTab.id),
              ),
              onReload: () =>
                  unawaited(registry.reload(service.id, activeTab.id)),
              onClose: widget.onExit,
              onAction: (action) => _handleAction(service, action),
            ),
            _TabStrip(
              service: service,
              onSelect: (tab) => ref
                  .read(servicesProvider.notifier)
                  .setActiveTab(service.id, tab.id),
              onCloseTab: (tab) => ref
                  .read(servicesProvider.notifier)
                  .closeTab(service.id, tab.id),
              onAdd: service.tabs.length >= K.maxTabsPerService
                  ? null
                  : () => ref
                        .read(servicesProvider.notifier)
                        .addTab(service.id),
              onRename: (tab) => unawaited(_renameTab(service, tab)),
            ),
            _AddressBar(
              controller: _urlController,
              focus: _urlFocus,
              onSubmit: () => _submitAddress(service),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // Every tab stays mounted; only the selected one is
                  // painted. That is what preserves each tab's exact page
                  // state across tab switches, service switches,
                  // backgrounding, and Recents.
                  IndexedStack(
                    index: sessions.indexOf(activeSession),
                    sizing: StackFit.expand,
                    children: <Widget>[
                      for (final session in sessions)
                        WebViewWidget(
                          key: ValueKey<String>(
                            'webview-${session.serviceId}-${session.tabId}',
                          ),
                          controller: session.controller,
                        ),
                    ],
                  ),
                  ValueListenableBuilder<String?>(
                    valueListenable: activeSession.loadError,
                    builder: (context, error, _) {
                      if (error == null) return const SizedBox.shrink();
                      return WebErrorView(
                        service: service,
                        error: error,
                        onRetry: () => unawaited(_retry(activeSession)),
                        onOpenExternal: () => unawaited(
                          ref
                              .read(platformBridgeProvider)
                              .openExternal(
                                activeTab.url.isEmpty
                                    ? service.url
                                    : activeTab.url,
                              ),
                        ),
                      );
                    },
                  ),
                  _PillHost(
                    show: ref.watch(
                      settingsProvider.select(
                        (settings) => settings.showFloatingBack,
                      ),
                    ),
                    idle: _pillIdle,
                    onTap: () {
                      _bumpPill();
                      unawaited(widget.onBack());
                    },
                    onLongPress: widget.onExit,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PillHost extends StatelessWidget {
  const _PillHost({
    required this.show,
    required this.idle,
    required this.onTap,
    required this.onLongPress,
  });

  final bool show;
  final bool idle;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    return FloatingBackPill(
      idle: idle,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// The service's tabs: one chip per tab plus a new-tab button.
///
/// Tabs belong to this service only. Tapping a chip selects it without
/// touching any other tab's WebView; the × closes just that tab.
class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.service,
    required this.onSelect,
    required this.onCloseTab,
    required this.onAdd,
    required this.onRename,
  });

  final ServiceItem service;
  final ValueChanged<ServiceTab> onSelect;
  final ValueChanged<ServiceTab> onCloseTab;
  final VoidCallback? onAdd;
  final ValueChanged<ServiceTab> onRename;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          children: <Widget>[
            for (final tab in service.tabs)
              _TabChip(
                tab: tab,
                selected: tab.id == service.activeTabId,
                closable: service.tabs.length > 1,
                onSelect: () => onSelect(tab),
                onClose: () => onCloseTab(tab),
                onRename: () => onRename(tab),
              ),
            if (onAdd != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Icon(
                      Icons.add,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.tab,
    required this.selected,
    required this.closable,
    required this.onSelect,
    required this.onClose,
    required this.onRename,
  });

  final ServiceTab tab;
  final bool selected;
  final bool closable;
  final VoidCallback onSelect;
  final VoidCallback onClose;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      onTap: onSelect,
      onLongPress: onRename,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.border : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (closable)
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    ),
  );
}

/// The selected tab's address, editable. Submitting a new address navigates
/// the tab and persists the new URL — tabs are never pinned to the URL they
/// were created with.
class _AddressBar extends StatelessWidget {
  const _AddressBar({
    required this.controller,
    required this.focus,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(left: 12, right: 4),
              child: Icon(
                Icons.link,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focus,
                keyboardType: TextInputType.url,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => onSubmit(),
                style: AppText.mono.copyWith(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Address',
                  hintStyle: TextStyle(color: AppColors.textDisabled),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            SizedBox(
              width: 44,
              height: double.infinity,
              child: IconButton(
                onPressed: onSubmit,
                tooltip: 'Go',
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
