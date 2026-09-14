/// URL normalisation — ARCHITECTURE.md §7.
///
/// The whole point of the app is not having to type `http://100.` in a browser,
/// so turning `100.114.10.5:3000` into something loadable is a first-class
/// feature rather than a `TextField` afterthought. Pure functions, no Flutter,
/// so the table in the doc is directly testable.
library;

const String kUrlEmptyMessage = 'Enter a host, e.g. 100.114.10.5:3000';
const String kUrlSpaceMessage = "Addresses can't contain spaces";
const String kUrlSchemeMessage = 'Only http and https are supported';
const String kUrlPortMessage = 'Port must be 1-65535';
const String kUrlHostMessage = "That doesn't look like a host or IP address";

/// Outcome of parsing user input. Sealed so callers must handle both arms.
sealed class UrlParseResult {
  const UrlParseResult();
}

final class UrlParseOk extends UrlParseResult {
  const UrlParseOk({
    required this.uri,
    required this.normalized,
    required this.displayHost,
    required this.origin,
  });

  /// Fully-formed URI handed to the WebView and the probe.
  final Uri uri;

  /// Canonical form: `http://100.114.10.5:3000` (default port and trailing
  /// slash omitted). This is what gets persisted.
  final String normalized;

  /// What the card subtitle shows: `100.114.10.5:3000`.
  final String displayHost;

  /// `scheme://host[:port]` with no path — the identity of the service.
  final String origin;
}

final class UrlParseFailure extends UrlParseResult {
  const UrlParseFailure(this.message);
  final String message;
}

final RegExp _schemePattern = RegExp(r'^([A-Za-z][A-Za-z0-9+.\-]*)://');
final RegExp _whitespace = RegExp(r'\s');
final RegExp _dnsHostPattern = RegExp(
  r'^[a-z0-9]([a-z0-9\-_]*[a-z0-9])?(\.[a-z0-9]([a-z0-9\-_]*[a-z0-9])?)*$',
);
final RegExp _ipv6Pattern = RegExp(r'^[0-9a-fA-F:.]+$');

/// Normalises arbitrary user input into a loadable URL.
UrlParseResult parseServiceUrl(String raw) {
  final input = raw.trim();
  if (input.isEmpty) return const UrlParseFailure(kUrlEmptyMessage);
  if (_whitespace.hasMatch(input)) return const UrlParseFailure(kUrlSpaceMessage);

  // 1. Optional scheme.
  String? scheme;
  var rest = input;
  final schemeMatch = _schemePattern.firstMatch(input);
  if (schemeMatch != null) {
    scheme = schemeMatch.group(1)!.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return const UrlParseFailure(kUrlSchemeMessage);
    }
    rest = input.substring(schemeMatch.end);
  }
  if (rest.isEmpty) return const UrlParseFailure(kUrlEmptyMessage);

  // 2. Split authority from path. A real path is preserved verbatim; a bare
  //    trailing slash is dropped so `host:3000/` and `host:3000` agree.
  final slash = rest.indexOf('/');
  final authority = slash == -1 ? rest : rest.substring(0, slash);
  final rawPath = slash == -1 ? '' : rest.substring(slash);
  final path = rawPath == '/' ? '' : rawPath;
  if (authority.isEmpty) return const UrlParseFailure(kUrlEmptyMessage);

  // 3. Host and port. Bracket form covers IPv6 literals.
  String host;
  String? portText;
  if (authority.startsWith('[')) {
    final close = authority.indexOf(']');
    if (close == -1) return const UrlParseFailure(kUrlHostMessage);
    host = authority.substring(1, close);
    final tail = authority.substring(close + 1);
    if (tail.startsWith(':')) {
      portText = tail.substring(1);
    } else if (tail.isNotEmpty) {
      return const UrlParseFailure(kUrlHostMessage);
    }
  } else {
    final colon = authority.lastIndexOf(':');
    if (colon == -1) {
      host = authority;
    } else {
      host = authority.substring(0, colon);
      portText = authority.substring(colon + 1);
    }
  }

  host = host.toLowerCase();
  if (!_isValidHost(host)) return const UrlParseFailure(kUrlHostMessage);

  int? port;
  if (portText != null) {
    final parsed = int.tryParse(portText);
    if (parsed == null || parsed < 1 || parsed > 65535) {
      return const UrlParseFailure(kUrlPortMessage);
    }
    port = parsed;
  }

  // 4. Infer the scheme when the user left it out. Private hosts are almost
  //    always plain HTTP; a public-looking hostname gets TLS by default.
  scheme ??= isPrivateHost(host) ? 'http' : 'https';
  final effectivePort = port ?? (scheme == 'https' ? 443 : 80);
  final isDefaultPort =
      (scheme == 'https' && effectivePort == 443) ||
      (scheme == 'http' && effectivePort == 80);

  final hostForUri = host.contains(':') ? '[$host]' : host;
  final authorityOut = isDefaultPort ? hostForUri : '$hostForUri:$effectivePort';
  final origin = '$scheme://$authorityOut';
  final normalized = '$origin$path';

  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.host.isEmpty) {
    return const UrlParseFailure(kUrlHostMessage);
  }

  return UrlParseOk(
    uri: uri,
    normalized: normalized,
    displayHost: isDefaultPort ? host : '$host:$effectivePort',
    origin: origin,
  );
}

/// Convenience for callers that only care whether the input is usable.
bool isValidServiceUrl(String raw) => parseServiceUrl(raw) is UrlParseOk;

/// Short form for a card subtitle, falling back to the raw text when the
/// address does not parse yet.
String displayHostOf(String raw) {
  final result = parseServiceUrl(raw);
  return result is UrlParseOk ? result.displayHost : raw;
}

/// Origin of an already-normalised URL, or null when it does not parse.
String? originOf(String raw) {
  final result = parseServiceUrl(raw);
  return result is UrlParseOk ? result.origin : null;
}

/// True for RFC1918 space, loopback, `.local`, `.ts.net`, Tailscale's CGNAT
/// range `100.64.0.0/10`, and single-label names.
///
/// The single-label rule matters in practice: with MagicDNS on, a tailnet host
/// is reachable as plain `omaipai`, and defaulting that to `https://` would
/// send it to a host that cannot answer on 443.
bool isPrivateHost(String host) {
  final lower = host.toLowerCase();
  if (lower == 'localhost') return true;
  if (lower.endsWith('.local') ||
      lower.endsWith('.ts.net') ||
      lower.endsWith('.internal')) {
    return true;
  }
  final octets = _ipv4(lower);
  if (octets == null) {
    // Not an IPv4 literal: a bare name with no dot is a local/tailnet host.
    return !lower.contains('.');
  }
  final a = octets[0];
  final b = octets[1];
  if (a == 10 || a == 127) return true;
  if (a == 172 && b >= 16 && b <= 31) return true;
  if (a == 192 && b == 168) return true;
  if (a == 100 && b >= 64 && b <= 127) return true;
  return false;
}

/// True when [uri] points inside the tailnet or at the local machine. Drives
/// the external-link policy: private stays in-app, public goes to the browser.
bool isTailnetUri(Uri uri) {
  if (uri.scheme == 'about' || uri.scheme == 'data' || uri.scheme == 'blob') {
    return true;
  }
  final host = uri.host;
  if (host.isEmpty) return false;
  return isPrivateHost(host);
}

bool _isValidHost(String host) {
  if (host.isEmpty) return false;
  if (host.contains(':')) return _ipv6Pattern.hasMatch(host);
  return _dnsHostPattern.hasMatch(host);
}

List<int>? _ipv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return null;
  final out = <int>[];
  for (final part in parts) {
    if (part.isEmpty || part.length > 3) return null;
    final value = int.tryParse(part);
    if (value == null || value < 0 || value > 255) return null;
    out.add(value);
  }
  return out;
}
