import '../core/constants.dart';

/// Pure LRU bookkeeping for the WebView pool.
///
/// Deliberately free of any plugin or Flutter dependency so the eviction rules
/// — the part of the design most likely to harbour a subtle bug — can be unit
/// tested without an Android device. [WebSessionRegistry] owns the actual
/// WebViews; this class only decides which ones must die.
///
/// Order is oldest-first, so `first` is the next eviction candidate.
class SessionLru {
  SessionLru(int capacity)
    : _capacity = capacity.clamp(K.minSessionCapacity, K.maxSessionCapacity);

  int _capacity;
  final List<String> _order = <String>[];
  String? _activeId;

  int get capacity => _capacity;
  String? get activeId => _activeId;
  int get length => _order.length;

  /// Oldest first.
  List<String> get order => List<String>.unmodifiable(_order);

  /// Index into `[sentinel, ...live]` for the `IndexedStack`. 0 means "nothing
  /// is showing", i.e. the grid.
  int get activeIndex {
    final id = _activeId;
    if (id == null) return 0;
    final index = _order.indexOf(id);
    return index == -1 ? 0 : index + 1;
  }

  /// Marks [id] as both most recently used and currently visible.
  void touch(String id) {
    _order
      ..remove(id)
      ..add(id);
    _activeId = id;
  }

  /// Hides the current session without forgetting it — the back button's
  /// "return to the grid" step.
  void deactivate() => _activeId = null;

  void forget(String id) {
    _order.remove(id);
    if (_activeId == id) _activeId = null;
  }

  void setCapacity(int value) {
    _capacity = value.clamp(K.minSessionCapacity, K.maxSessionCapacity);
  }

  /// How many entries exceed capacity.
  int get overflowCount {
    final excess = _order.length - _capacity;
    return excess > 0 ? excess : 0;
  }

  /// Ids that must be dropped to respect the capacity, oldest first.
  ///
  /// The active session is **never** included, even when that means staying
  /// over budget: evicting what is on screen would blank the page the user is
  /// looking at, which is worse than a temporarily oversized pool.
  List<String> evictionCandidates() {
    final victims = <String>[];
    var excess = overflowCount;
    for (final id in _order) {
      if (excess <= 0) break;
      if (id == _activeId) continue;
      victims.add(id);
      excess--;
    }
    return victims;
  }
}
