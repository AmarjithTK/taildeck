import 'package:flutter/services.dart';

import '../../data/models/service_item.dart';

/// Applies one service's orientation lock (or the system default).
///
/// Called whenever the foreground service changes and when a service's own
/// lock is edited. On the grid there is no foreground service, so the grid
/// restores the system default instead of holding the last service's lock —
/// the lock belongs to the service, never to TailDeck globally.
Future<void> applyAppOrientation(AppOrientation orientation) async {
  final orientations = switch (orientation) {
    AppOrientation.system => <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
    AppOrientation.portrait => <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
    AppOrientation.landscape => <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
  };
  try {
    await SystemChrome.setPreferredOrientations(orientations);
  } on Object {
    // Orientation is a preference, never a reason to break the view.
  }
}
