import 'package:flutter_test/flutter_test.dart';
import 'package:taildeck/core/constants.dart';
import 'package:taildeck/state/session_lru.dart';

/// These are the acceptance criteria from ARCHITECTURE.md §5.2 and §14 (M2),
/// testable without an Android device because the policy is deliberately
/// separated from the WebView plumbing.
void main() {
  test('a fourth service evicts the least recently used', () {
    final lru = SessionLru(3);
    for (final id in <String>['a', 'b', 'c']) {
      lru.touch(id);
      expect(lru.evictionCandidates(), isEmpty);
    }

    lru.touch('d');
    expect(lru.order, <String>['a', 'b', 'c', 'd']);
    expect(lru.activeId, 'd');
    expect(lru.overflowCount, 1);
    expect(lru.evictionCandidates(), <String>['a']);
  });

  test('re-opening a service makes it the most recent', () {
    final lru = SessionLru(3);
    for (final id in <String>['a', 'b', 'c']) {
      lru.touch(id);
    }
    lru.touch('a');
    expect(lru.order, <String>['b', 'c', 'a']);

    lru.touch('d');
    // 'b' is now the oldest, not 'a'.
    expect(lru.evictionCandidates(), <String>['b']);
  });

  test('the active session is never an eviction candidate', () {
    final lru = SessionLru(1);
    lru.touch('a');
    lru.touch('b');
    expect(lru.activeId, 'b');
    expect(lru.evictionCandidates(), <String>['a']);
    expect(lru.evictionCandidates(), isNot(contains('b')));
  });

  test('shrinking the capacity queues the oldest for eviction', () {
    final lru = SessionLru(5);
    for (final id in <String>['a', 'b', 'c', 'd', 'e']) {
      lru.touch(id);
    }
    lru.setCapacity(3);
    expect(lru.overflowCount, 2);
    expect(lru.evictionCandidates(), <String>['a', 'b']);

    lru.forget('a');
    lru.forget('b');
    expect(lru.evictionCandidates(), isEmpty);
  });

  test('forget drops the entry and clears the active id', () {
    final lru = SessionLru(3);
    lru.touch('a');
    lru.forget('a');
    expect(lru.length, 0);
    expect(lru.activeId, isNull);
  });

  test('activeIndex maps to the sentinel plus the live order', () {
    final lru = SessionLru(3);
    expect(lru.activeIndex, 0, reason: 'nothing showing');

    lru.touch('a');
    expect(lru.activeIndex, 1);
    lru.touch('b');
    expect(lru.activeIndex, 2);

    lru.touch('a');
    expect(lru.order, <String>['b', 'a']);
    expect(lru.activeIndex, 2);

    lru.deactivate();
    expect(lru.activeIndex, 0, reason: 'grid showing again');
    // Deactivating must not forget anything.
    expect(lru.length, 2);
    expect(lru.activeId, isNull);
  });

  test('capacity is clamped to the supported range', () {
    expect(SessionLru(0).capacity, K.minSessionCapacity);
    expect(SessionLru(-5).capacity, K.minSessionCapacity);
    expect(SessionLru(99).capacity, K.maxSessionCapacity);
  });
}
