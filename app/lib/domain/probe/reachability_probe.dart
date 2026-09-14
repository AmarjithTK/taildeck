import 'dart:async';
import 'dart:io';

import '../../core/constants.dart';
import '../../data/models/probe_status.dart';

/// Two-phase reachability probe — ARCHITECTURE.md §8.1.
///
/// Phase one is a bare TCP connect. That is the truest signal available: host
/// up, port open, tunnel working, and independent of HTTP semantics, so a
/// service returning 500 still counts as reachable. Its duration is the
/// response time shown on the card.
///
/// Phase two optionally asks for an HTTP status, which is what distinguishes
/// "up" from "up but wants credentials".
class ReachabilityProbe {
  const ReachabilityProbe();

  Future<ProbeStatus> probe(Uri uri) async {
    final host = uri.host;
    final now = DateTime.now;
    if (host.isEmpty) {
      return ProbeStatus.offline(error: 'Host not found', checkedAt: now());
    }

    final port = uri.hasPort
        ? uri.port
        : (uri.scheme == 'https' ? 443 : 80);

    final stopwatch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: K.connectTimeout);
      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;
      final status = await _httpStatus(uri);
      return ProbeStatus.online(
        latencyMs: latency,
        httpStatus: status,
        checkedAt: now(),
      );
    } on SocketException catch (error) {
      return ProbeStatus.offline(
        error: describeSocketException(error),
        checkedAt: now(),
      );
    } on TimeoutException {
      return ProbeStatus.offline(
        error: 'Connection timed out',
        checkedAt: now(),
      );
    } on Object {
      return ProbeStatus.offline(error: 'Unreachable', checkedAt: now());
    } finally {
      socket?.destroy();
    }
  }

  /// Best-effort. A failure here does not downgrade the result: the TCP connect
  /// already proved the service is up.
  Future<int?> _httpStatus(Uri uri) async {
    final client = HttpClient()..connectionTimeout = K.httpTimeout;
    try {
      final request = await client.getUrl(uri).timeout(K.httpTimeout);
      // Report the redirect itself rather than chasing it — we only want the
      // status code, not the page.
      request.followRedirects = false;
      final response = await request.close().timeout(K.httpTimeout);
      final code = response.statusCode;
      return code;
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

/// Turns a [SocketException] into one of the copy-deck strings.
String describeSocketException(SocketException error) {
  final combined =
      '${error.message} ${error.osError?.message ?? ''}'.toLowerCase();
  if (combined.contains('refused')) return 'Connection refused';
  if (combined.contains('timed out') || combined.contains('timeout')) {
    return 'Connection timed out';
  }
  if (combined.contains('unreachable') || combined.contains('no route')) {
    return 'No route to host';
  }
  if (combined.contains('failed host lookup') ||
      combined.contains('not known') ||
      combined.contains('nodename')) {
    return 'Host not found';
  }
  if (combined.contains('reset')) return 'Connection reset';
  return 'Unreachable';
}
