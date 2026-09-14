import 'package:flutter_test/flutter_test.dart';
import 'package:taildeck/core/url_utils.dart';

void main() {
  group('parseServiceUrl normalises', () {
    // The table from ARCHITECTURE.md §7, as literal expectations.
    const cases = <String, String>{
      '100.114.10.5:3000': 'http://100.114.10.5:3000',
      '100.114.10.5': 'http://100.114.10.5',
      'http://100.114.10.5:3000/': 'http://100.114.10.5:3000',
      'grafana.local:3000': 'http://grafana.local:3000',
      '192.168.1.50:8123': 'http://192.168.1.50:8123',
      'example.com': 'https://example.com',
      '  100.114.10.5:3000  ': 'http://100.114.10.5:3000',
      '100.114.10.5:3000/admin': 'http://100.114.10.5:3000/admin',
      'https://100.114.10.5:8443': 'https://100.114.10.5:8443',
      'localhost:8080': 'http://localhost:8080',
      // Explicit default port is folded away.
      '100.114.10.5:80': 'http://100.114.10.5',
      // A public host gets TLS by default; a non-default port survives.
      'example.com:8443': 'https://example.com:8443',
      // 10/8 is private space too.
      '10.0.0.7:9090': 'http://10.0.0.7:9090',
      // MagicDNS short name: a bare label is a tailnet host, not a public one.
      'omaipai:3000': 'http://omaipai:3000',
      'omaipai': 'http://omaipai',
    };

    cases.forEach((input, expected) {
      test('"$input" becomes "$expected"', () {
        final result = parseServiceUrl(input);
        expect(result, isA<UrlParseOk>(), reason: 'should parse: $input');
        expect((result as UrlParseOk).normalized, expected);
      });
    });
  });

  group('parseServiceUrl rejects', () {
    void expectFailure(String input, String message) {
      test('"$input" reports "$message"', () {
        final result = parseServiceUrl(input);
        expect(result, isA<UrlParseFailure>());
        expect((result as UrlParseFailure).message, message);
      });
    }

    expectFailure('', kUrlEmptyMessage);
    expectFailure('    ', kUrlEmptyMessage);
    expectFailure('http://', kUrlEmptyMessage);
    expectFailure('ftp://100.114.10.5', kUrlSchemeMessage);
    expectFailure('100.114.10.5:99999', kUrlPortMessage);
    expectFailure('100.114.10.5:0', kUrlPortMessage);
    expectFailure('100.114.10.5:abc', kUrlPortMessage);
    expectFailure('100.114.10.5:3000 extra', kUrlSpaceMessage);
    expectFailure('her**o', kUrlHostMessage);
  });

  group('derived views', () {
    test('displayHost drops the scheme and default port', () {
      expect(displayHostOf('http://100.114.10.5:3000'), '100.114.10.5:3000');
      expect(displayHostOf('https://example.com'), 'example.com');
      expect(displayHostOf('100.114.10.5'), '100.114.10.5');
    });

    test('displayHost falls back to the raw text while input is invalid', () {
      expect(displayHostOf('not a url'), 'not a url');
    });

    test('origin keeps scheme and port but no path', () {
      expect(
        originOf('http://100.114.10.5:3000/admin'),
        'http://100.114.10.5:3000',
      );
      expect(originOf(''), isNull);
      expect(originOf('her**o'), isNull);
    });

    test('isValidServiceUrl mirrors the parse result', () {
      expect(isValidServiceUrl('100.114.10.5:3000'), isTrue);
      expect(isValidServiceUrl(''), isFalse);
    });
  });

  group('private-host detection', () {
    test('recognises Tailscale CGNAT, RFC1918 and loopback', () {
      for (final host in <String>[
        '100.64.0.1', // lower bound of 100.64.0.0/10
        '100.127.255.255', // upper bound
        '10.0.0.1',
        '172.16.0.1',
        '192.168.1.1',
        '127.0.0.1',
        'localhost',
        'my-box.ts.net',
        'printer.local',
      ]) {
        expect(isPrivateHost(host), isTrue, reason: host);
      }
    });

    test('rejects public addresses and the CGNAT shoulders', () {
      for (final host in <String>[
        '100.63.255.255', // just below the Tailscale range
        '100.128.0.1', // just above it
        '172.32.0.1', // just outside 172.16/12
        '8.8.8.8',
        'github.com',
      ]) {
        expect(isPrivateHost(host), isFalse, reason: host);
      }
    });

    test('isTailnetUri drives the external-link policy', () {
      expect(isTailnetUri(Uri.parse('http://100.114.10.5:3000')), isTrue);
      expect(isTailnetUri(Uri.parse('https://example.com')), isFalse);
      // WebView internals must never be treated as an external link.
      expect(isTailnetUri(Uri.parse('about:blank')), isTrue);
    });
  });
}
