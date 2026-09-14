import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taildeck/core/constants.dart';
import 'package:taildeck/data/models/app_settings.dart';
import 'package:taildeck/data/models/icon_ref.dart';
import 'package:taildeck/data/models/service_item.dart';
import 'package:taildeck/domain/probe/reachability_probe.dart'
    show describeSocketException;
import 'package:taildeck/state/web_session_registry.dart' show describeLoadError;

void main() {
  group('ServiceItem JSON', () {
    test('round-trips every field', () {
      final original = ServiceItem(
        id: 'abc',
        name: 'Omaipai',
        url: 'http://100.114.10.5:3000',
        icon: const IconRef(
          kind: IconKind.material,
          value: 'smart_toy',
          accent: 0xFF22C55E,
        ),
        sortOrder: 3,
        pinned: true,
        probeEnabled: false,
        desktopMode: true,
        createdAt: DateTime.utc(2026, 5, 16, 10),
      );

      final restored = ServiceItem.fromJson(original.toJson());
      expect(restored, original);
      expect(restored.createdAt, original.createdAt);
    });

    test('survives a payload with missing fields', () {
      final restored = ServiceItem.fromJson(<String, dynamic>{'id': 'x'});
      expect(restored.id, 'x');
      expect(restored.name, 'Service');
      expect(restored.url, '');
      expect(restored.probeEnabled, isTrue);
      expect(restored.icon.kind, IconKind.monogram);
    });

    test('falls back to a monogram when the icon is unreadable', () {
      final restored = ServiceItem.fromJson(<String, dynamic>{
        'id': 'x',
        'name': 'Grafana',
        'icon': 'not-an-object',
      });
      expect(restored.icon.kind, IconKind.monogram);
      expect(restored.icon.value, 'G');
    });
  });

  group('ServiceItem derived values', () {
    ServiceItem build(String url) => ServiceItem(
      id: 'x',
      name: 'Test',
      url: url,
      icon: const IconRef(
        kind: IconKind.monogram,
        value: 'T',
        accent: 0xFF22C55E,
      ),
      sortOrder: 0,
      createdAt: DateTime.utc(2026),
    );

    test('a blank URL is "unconfigured" and says so', () {
      final item = build('');
      expect(item.isConfigured, isFalse);
      expect(item.displayHost, 'Tap to configure');
      expect(item.origin, isNull);
      expect(item.uri, isNull);
    });

    test('a configured service exposes host, origin and uri', () {
      final item = build('http://100.114.10.5:3000/admin');
      expect(item.isConfigured, isTrue);
      expect(item.displayHost, '100.114.10.5:3000');
      expect(item.origin, 'http://100.114.10.5:3000');
      expect(item.uri?.path, '/admin');
    });
  });

  group('AppSettings', () {
    test('defaults match the documented values', () {
      const settings = AppSettings();
      expect(settings.sessionCapacity, K.defaultSessionCapacity);
      expect(settings.autoProbe, isTrue);
      expect(settings.onlyProbeOnHome, isTrue);
      expect(settings.externalLinkPolicy, ExternalLinkPolicy.external);
    });

    test('round-trips through JSON', () {
      const original = AppSettings(
        sessionCapacity: 5,
        autoProbe: false,
        probeIntervalSec: 60,
        onlyProbeOnHome: false,
        showFloatingBack: false,
        externalLinkPolicy: ExternalLinkPolicy.block,
        desktopModeDefault: true,
      );
      expect(AppSettings.fromJson(original.toJson()), original);
    });

    test('an unknown link policy falls back rather than throwing', () {
      final settings = AppSettings.fromJson(<String, dynamic>{
        'externalLinkPolicy': 'teleport',
      });
      expect(settings.externalLinkPolicy, ExternalLinkPolicy.external);
    });

    test('copyWith clamps the session capacity', () {
      const settings = AppSettings();
      expect(
        settings.copyWith(sessionCapacity: 99).sessionCapacity,
        K.maxSessionCapacity,
      );
      expect(
        settings.copyWith(sessionCapacity: 0).sessionCapacity,
        K.minSessionCapacity,
      );
    });
  });

  group('error copy mapping', () {
    test('describeLoadError maps Chromium error strings', () {
      expect(
        describeLoadError('net::ERR_CONNECTION_REFUSED'),
        'Connection refused',
      );
      expect(
        describeLoadError('net::ERR_CONNECTION_TIMED_OUT'),
        'Connection timed out',
      );
      expect(
        describeLoadError('net::ERR_NAME_NOT_RESOLVED'),
        'Host not found',
      );
      expect(
        describeLoadError('net::ERR_ADDRESS_UNREACHABLE'),
        'No route to host',
      );
      expect(
        describeLoadError('net::ERR_CLEARTEXT_NOT_PERMITTED'),
        'Cleartext HTTP is blocked',
      );
      expect(
        describeLoadError('net::ERR_SSL_PROTOCOL_ERROR'),
        'TLS handshake failed',
      );
      expect(describeLoadError('something else'), 'Could not load the page');
      expect(describeLoadError(null), 'Could not load the page');
    });

    test('describeSocketException maps OS-level failures', () {
      expect(
        describeSocketException(
          const SocketException('Connection refused'),
        ),
        'Connection refused',
      );
      expect(
        describeSocketException(const SocketException('Connection timed out')),
        'Connection timed out',
      );
      expect(
        describeSocketException(
          const SocketException('Failed host lookup: \'foo\''),
        ),
        'Host not found',
      );
      expect(
        describeSocketException(const SocketException('Network is unreachable')),
        'No route to host',
      );
      // An unrecognised failure still yields something displayable.
      expect(
        describeSocketException(const SocketException('weird')),
        'Unreachable',
      );
    });
  });
}
