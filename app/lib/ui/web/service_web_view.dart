import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants.dart';
import '../../../state/providers.dart';
import '../../../state/web_session_registry.dart';
import '../home/service_actions.dart';
import 'widgets/floating_back_pill.dart';
import 'widgets/service_toolbar.dart';
import 'widgets/web_error_view.dart';

/// Screen 2 — `docs/UI_SPEC.md` §3.
///
/// A slim toolbar (back, forward, title, reload, overflow) over the page, plus
/// an error overlay when the main frame fails. No tab strip and no address bar.
class ServiceWebView extends ConsumerStatefulWidget {
  const ServiceWebView({
    super.key,
    required this.session,
    required this.onBack,
    required this.onExit,
  });

  final WebSession session;

  /// Back in page history, or out to the grid when history is exhausted.
  final Future<void> Function() onBack;

  /// Straight to the grid, skipping history (the pill's long press).
  final VoidCallback onExit;

  @override
  ConsumerState<ServiceWebView> createState() => _ServiceWebViewState();
}

class _ServiceWebViewState extends ConsumerState<ServiceWebView> {
  Timer? _pillTimer;
  bool _pillIdle = false;

  @override
  void initState() {
    super.initState();
    _bumpPill();
  }

  @override
  void dispose() {
    _pillTimer?.cancel();
    super.dispose();
  }

  void _bumpPill() {
    _pillTimer?.cancel();
    if (_pillIdle && mounted) setState(() => _pillIdle = false);
    _pillTimer = Timer(K.pillIdleDelay, () {
      if (mounted) setState(() => _pillIdle = true);
    });
  }

  Future<void> _retry() async {
    final session = widget.session;
    session.loadError.value = null;
    try {
      await session.controller.reload();
    } on Object {
      session.loadError.value = 'Could not load the page';
    }
  }

  void _handleAction(ServiceToolbarAction action) {
    final session = widget.session;
    final registry = ref.read(sessionRegistryProvider);

    switch (action) {
      case ServiceToolbarAction.openExternal:
        unawaited(
          ref.read(platformBridgeProvider).openExternal(session.service.url),
        );
      case ServiceToolbarAction.copyAddress:
        unawaited(
          Clipboard.setData(ClipboardData(text: session.service.url)),
        );
        showToast(context, 'Address copied');
      case ServiceToolbarAction.editService:
        unawaited(editService(context, ref, session.service));
      case ServiceToolbarAction.unloadPage:
        registry.close(session.serviceId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final showPill = ref.watch(
      settingsProvider.select((settings) => settings.showFloatingBack),
    );
    final registry = ref.read(sessionRegistryProvider);

    return Column(
      children: <Widget>[
        ServiceToolbar(
          service: session.service,
          canGoBack: session.canGoBack,
          canGoForward: session.canGoForward,
          loading: session.loading,
          progress: session.progress,
          onBack: () {
            _bumpPill();
            unawaited(widget.onBack());
          },
          onForward: () =>
              unawaited(registry.goForward(session.serviceId)),
          onReload: () => unawaited(registry.reload(session.serviceId)),
          onClose: widget.onExit,
          onAction: _handleAction,
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              WebViewWidget(
                key: ValueKey<String>('webview-${session.serviceId}'),
                controller: session.controller,
              ),
              ValueListenableBuilder<String?>(
                valueListenable: session.loadError,
                builder: (context, error, _) {
                  if (error == null) return const SizedBox.shrink();
                  return WebErrorView(
                    service: session.service,
                    error: error,
                    onRetry: () => unawaited(_retry()),
                    onOpenExternal: () => unawaited(
                      ref
                          .read(platformBridgeProvider)
                          .openExternal(session.service.url),
                    ),
                  );
                },
              ),
              if (showPill)
                FloatingBackPill(
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
  }
}
