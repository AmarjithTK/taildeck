import 'package:flutter/material.dart';

import '../../state/web_session_registry.dart';
import 'service_web_view.dart';

/// Hosts every loaded service and decides which one is visible.
///
/// This widget must stay mounted for the whole app lifetime. That is the whole
/// trick behind preserving page state: rather than pushing and popping a route
/// (which would dispose the `WebViewWidget` and its native WebView), we keep
/// the services in an [IndexedStack] and change which index is painted, and
/// each service in turn keeps every one of its tabs mounted. Leaving TailDeck
/// via system navigation, Recents, or the home button only changes which index
/// is painted — nothing is disposed, so everything resumes where it was.
///
/// Index 0 is a transparent sentinel meaning "the grid is showing". An
/// `IndexedStack` always paints exactly one child and only hit-tests that one,
/// so with index 0 selected the grid underneath receives all touches and no
/// WebView is painted.
class WebLayer extends StatelessWidget {
  const WebLayer({
    super.key,
    required this.registry,
    required this.onBack,
    required this.onExit,
  });

  final WebSessionRegistry registry;
  final Future<void> Function() onBack;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: registry,
    builder: (context, _) {
      final services = registry.liveServices;
      if (services.isEmpty) return const SizedBox.shrink();

      return IndexedStack(
        index: registry.activeIndex,
        sizing: StackFit.expand,
        children: <Widget>[
          const SizedBox.expand(),
          for (final service in services)
            ServiceWebView(
              key: ValueKey<String>(service.id),
              serviceId: service.id,
              onBack: onBack,
              onExit: onExit,
            ),
        ],
      );
    },
  );
}
