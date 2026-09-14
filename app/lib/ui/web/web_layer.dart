import 'package:flutter/material.dart';

import '../../state/web_session_registry.dart';
import 'service_web_view.dart';

/// Hosts every live WebView and decides which one is visible.
///
/// This widget must stay mounted for the whole app lifetime. That is the whole
/// trick behind having **no tab strip** yet keeping page state: rather than
/// pushing and popping a route (which would dispose the `WebViewWidget` and its
/// native WebView), we keep the sessions in an [IndexedStack] and change which
/// index is painted.
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
      final live = registry.live;
      if (live.isEmpty) return const SizedBox.shrink();

      return IndexedStack(
        index: registry.activeIndex,
        sizing: StackFit.expand,
        children: <Widget>[
          const SizedBox.expand(),
          for (final session in live)
            ServiceWebView(
              key: ValueKey<String>(session.serviceId),
              session: session,
              onBack: onBack,
              onExit: onExit,
            ),
        ],
      );
    },
  );
}
