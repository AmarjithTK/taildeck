import 'package:flutter/foundation.dart';

/// Result of the two-phase reachability probe — ARCHITECTURE.md §8.
enum ProbeState {
  /// Never probed, or checks are disabled for this service.
  unknown,

  /// A probe is in flight right now.
  checking,

  /// TCP connect succeeded. [ProbeStatus.httpStatus] may still be null.
  online,

  /// TCP connect failed, so we never reached HTTP.
  offline,
}

@immutable
class ProbeStatus {
  const ProbeStatus({
    required this.state,
    this.latencyMs,
    this.httpStatus,
    this.error,
    this.checkedAt,
  });

  const ProbeStatus.unknown() : this(state: ProbeState.unknown);

  const ProbeStatus.checking() : this(state: ProbeState.checking);

  const ProbeStatus.online({
    required int latencyMs,
    int? httpStatus,
    required DateTime checkedAt,
  }) : this(
         state: ProbeState.online,
         latencyMs: latencyMs,
         httpStatus: httpStatus,
         checkedAt: checkedAt,
       );

  const ProbeStatus.offline({
    required String error,
    required DateTime checkedAt,
  }) : this(
         state: ProbeState.offline,
         error: error,
         checkedAt: checkedAt,
       );

  final ProbeState state;

  /// TCP connect duration in milliseconds — the number shown on the card.
  final int? latencyMs;

  /// HTTP status from phase two, when it ran.
  final int? httpStatus;

  /// Human-readable failure reason, already mapped for display.
  final String? error;

  final DateTime? checkedAt;

  bool get isOnline => state == ProbeState.online;
  bool get isOffline => state == ProbeState.offline;
  bool get isChecking => state == ProbeState.checking;

  /// The service answered but is asking for credentials — worth its own
  /// message, because "unreachable" would be misleading.
  bool get needsAuth => httpStatus == 401 || httpStatus == 403;

  /// Compact subtitle fragment: `82 ms`, or the HTTP code when it adds signal.
  String? get summary {
    if (!isOnline || latencyMs == null) return null;
    final http = httpStatus;
    if (http != null && http != 200) return '$latencyMs ms \u00B7 HTTP $http';
    return '$latencyMs ms';
  }

  ProbeStatus copyWith({
    ProbeState? state,
    int? latencyMs,
    int? httpStatus,
    String? error,
    DateTime? checkedAt,
  }) => ProbeStatus(
    state: state ?? this.state,
    latencyMs: latencyMs ?? this.latencyMs,
    httpStatus: httpStatus ?? this.httpStatus,
    error: error ?? this.error,
    checkedAt: checkedAt ?? this.checkedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is ProbeStatus &&
      other.state == state &&
      other.latencyMs == latencyMs &&
      other.httpStatus == httpStatus &&
      other.error == error;

  @override
  int get hashCode => Object.hash(state, latencyMs, httpStatus, error);
}
