import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'state/web_session_registry.dart';
import 'theme/app_theme.dart';
import 'ui/home/home_screen.dart';
import 'ui/web/web_layer.dart';

class TailDeckApp extends StatelessWidget {
  const TailDeckApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TailDeck',
    debugShowCheckedModeBanner: false,
    theme: buildTailDeckTheme(),
    home: const RootShell(),
  );
}

/// Owns the single back-navigation contract from ARCHITECTURE.md §6, and hosts
/// the grid and the WebView layer as siblings.
///
/// Home and the web layer are **stacked, not pushed**. Home is never disposed,
/// and each WebView stays mounted while its service is inactive, which is what
/// makes "no tab strip, but state is preserved" work.
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell>
    with WidgetsBindingObserver {
  late final WebSessionRegistry _registry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _registry = ref.read(sessionRegistryProvider);
    _registry.lastRendererCrash.addListener(_onRendererCrash);
  }

  @override
  void dispose() {
    _registry.lastRendererCrash.removeListener(_onRendererCrash);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The OS reclaimed a WebView renderer. The native guard stopped that from
  /// killing the app; all that is left is to explain why the page vanished.
  void _onRendererCrash() {
    final name = _registry.lastRendererCrash.value;
    if (name == null || !mounted) return;

    // Clear on the next turn of the loop: an identical crash later must still
    // notify, and clearing inline would re-enter the notifier.
    scheduleMicrotask(() => _registry.lastRendererCrash.value = null);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$name ran out of memory. Tap the card to reload.'),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.invalidate(vpnStateProvider);
    unawaited(ref.read(probeProvider.notifier).probeStale());
  }

  /// Back: page history first, then out to the grid — and out to the grid means
  /// *deactivate*, never dispose, so the session stays warm.
  Future<void> _back(WebSessionRegistry registry) async {
    final activeId = registry.activeId;
    if (activeId == null) return;

    final session = registry.sessionFor(activeId);
    if (session != null) {
      try {
        if (await session.controller.canGoBack()) {
          await session.controller.goBack();
          return;
        }
      } on Object {
        // A history query that fails should not trap the user in the page.
      }
    }
    registry.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(sessionRegistryProvider);

    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) => PopScope(
        // When the grid is showing, let Android close the app natively so the
        // predictive-back animation still runs.
        canPop: registry.activeId == null,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          unawaited(_back(registry));
        },
        child: Scaffold(
          backgroundColor: AppColors.bg,
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const HomeScreen(),
              Positioned.fill(
                child: WebLayer(
                  registry: registry,
                  onBack: () => _back(registry),
                  onExit: registry.deactivate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
