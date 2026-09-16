import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform/app_orientation.dart';
import 'data/models/service_item.dart';
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
/// and each loaded service — every tab of it — stays mounted while inactive,
/// which is what preserves exact page state across service switches,
/// backgrounding, Recents, and restarts (with persisted tab URLs covering a
/// cold start).
///
/// There is a deliberate split in back-navigation duties:
/// * Android system back / leaving TailDeck only *deactivates* the service —
///   state is preserved, nothing navigates.
/// * The explicit webpage Back control (toolbar, pill) walks the active tab's
///   WebView history, and only leaves to the grid once history is exhausted.
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
    _registry.addListener(_applyActiveOrientation);
    // Settle the orientation once the first frame exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyActiveOrientation();
    });
  }

  @override
  void dispose() {
    _registry.lastRendererCrash.removeListener(_onRendererCrash);
    _registry.removeListener(_applyActiveOrientation);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Restores the foreground service's orientation lock, or the system default
  /// on the grid. A service's lock never leaks onto the grid or onto another
  /// service: every activation re-applies.
  void _applyActiveOrientation() {
    final session = _registry.activeSession;
    unawaited(applyAppOrientation(session?.service.orientation ?? _gridOrientation));
  }

  /// The grid follows the system rotation policy rather than holding whatever
  /// the last service locked.
  static const _gridOrientation = AppOrientation.system;

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
    // Resume re-probes stale cards only. Sessions are never reloaded here:
    // returning from the background or Recents must resume the exact state
    // the user left, not recreate pages from their default URLs.
    ref.invalidate(vpnStateProvider);
    unawaited(ref.read(probeProvider.notifier).probeStale());
  }

  /// Explicit webpage Back: page history of the active tab first, then out to
  /// the grid — and out to the grid means *deactivate*, never dispose, so
  /// every session stays warm.
  Future<void> _back(WebSessionRegistry registry) async {
    final session = registry.activeSession;
    if (session == null) return;

    try {
      if (await session.controller.canGoBack()) {
        await session.controller.goBack();
        return;
      }
    } on Object {
      // A history query that fails should not trap the user in the page.
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
        // predictive-back animation still runs. Leaving this way preserves
        // state: the sessions stay mounted and Android resumes the task.
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
