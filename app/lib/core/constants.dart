/// Central tunables.
///
/// Everything the architecture doc quotes as a number lives here so code and
/// `docs/ARCHITECTURE.md` cannot drift apart.
abstract final class K {
  // Grid -----------------------------------------------------------------
  static const int gridColumns = 2;
  static const int gridRows = 5;
  static const int maxServices = gridColumns * gridRows;
  static const double gridGap = 14;
  static const double screenPadding = 16;

  // WebView sessions -----------------------------------------------------
  static const int defaultSessionCapacity = 3;
  static const int minSessionCapacity = 1;
  static const int maxSessionCapacity = 5;

  // Reachability probing ------------------------------------------------
  static const Duration connectTimeout = Duration(milliseconds: 1500);
  static const Duration httpTimeout = Duration(seconds: 2);
  static const int probeConcurrency = 4;
  static const Duration probeStagger = Duration(milliseconds: 120);
  static const int defaultProbeIntervalSec = 45;
  static const List<int> probeIntervalChoices = <int>[30, 45, 60];
  static const Duration probeFreshness = Duration(seconds: 10);

  // UI timings ----------------------------------------------------------
  static const Duration validateDebounce = Duration(milliseconds: 300);
  static const Duration saveDebounce = Duration(milliseconds: 300);
  static const Duration progressFade = Duration(milliseconds: 250);
  static const Duration pillIdleDelay = Duration(milliseconds: 2500);
  static const Duration pillFade = Duration(milliseconds: 400);
}
