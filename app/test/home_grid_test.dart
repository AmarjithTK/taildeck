import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taildeck/core/constants.dart';
import 'package:taildeck/state/providers.dart';
import 'package:taildeck/theme/app_theme.dart';
import 'package:taildeck/ui/home/home_screen.dart';
import 'package:taildeck/ui/home/widgets/add_service_card.dart';
import 'package:taildeck/ui/home/widgets/service_card.dart';

Map<String, dynamic> _serviceJson(
  String id,
  String name,
  String url,
  int order,
) => <String, dynamic>{
  'id': id,
  'name': name,
  'url': url,
  'icon': <String, dynamic>{
    'kind': 'monogram',
    'value': name.substring(0, 1),
    'accent': 0xFF22C55E,
  },
  'sortOrder': order,
  'pinned': false,
  // Probes off so the scheduler leaves no pending timers behind in the test.
  'probeEnabled': false,
  'desktopMode': false,
  'createdAt': '2026-05-16T10:00:00.000Z',
};

Future<Widget> _harness(List<Map<String, dynamic>> services) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'taildeck.settings.v1': jsonEncode(<String, dynamic>{
      'schema': 1,
      'autoProbe': false,
    }),
    if (services.isNotEmpty)
      'taildeck.services.v1': jsonEncode(<String, dynamic>{
        'schema': 1,
        'items': services,
      }),
  });
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      theme: buildTailDeckTheme(),
      home: const Scaffold(body: HomeScreen()),
    ),
  );
}

/// A phone-shaped viewport. The grid sizes cards from the available height, so
/// the default 800x600 test surface would squash them into overflow.
void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('an empty grid invites the first service', (tester) async {
    _usePhoneViewport(tester);
    await tester.pumpWidget(await _harness(<Map<String, dynamic>>[]));
    await tester.pumpAndSettle();

    expect(find.text('Add your first service'), findsOneWidget);
    expect(find.byType(ServiceCard), findsNothing);
  });

  testWidgets('two services fill two slots and leave seven ghosts', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    await tester.pumpWidget(
      await _harness(<Map<String, dynamic>>[
        _serviceJson('a', 'Omaipai', 'http://100.114.10.5:3000', 0),
        _serviceJson('b', 'Dipsy Carness', 'http://100.114.10.6:8080', 1),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ServiceCard), findsNWidgets(2));
    // Exactly one slot invites a new service; the rest keep the rhythm.
    expect(find.byType(AddServiceCard), findsOneWidget);
    expect(find.byType(GhostSlot), findsNWidgets(K.maxServices - 3));

    expect(find.text('Omaipai'), findsOneWidget);
    expect(find.text('Dipsy Carness'), findsOneWidget);
    // The card shows the short form the user typed, without the scheme.
    expect(find.text('100.114.10.5:3000'), findsOneWidget);
    expect(find.text('http://100.114.10.5:3000'), findsNothing);
  });

  testWidgets('a full grid offers no add slot', (tester) async {
    _usePhoneViewport(tester);
    await tester.pumpWidget(
      await _harness(<Map<String, dynamic>>[
        for (var i = 0; i < K.maxServices; i++)
          _serviceJson(
            'svc$i',
            'Service $i',
            'http://100.114.10.${i + 1}:3000',
            i,
          ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ServiceCard), findsNWidgets(K.maxServices));
    expect(find.byType(AddServiceCard), findsNothing);
    expect(find.byType(GhostSlot), findsNothing);
  });

  testWidgets('cards render at the documented 2 x 5 geometry', (tester) async {
    _usePhoneViewport(tester);
    await tester.pumpWidget(
      await _harness(<Map<String, dynamic>>[
        for (var i = 0; i < 4; i++)
          _serviceJson('svc$i', 'Service $i', 'http://100.114.10.${i + 1}:3000', i),
      ]),
    );
    await tester.pumpAndSettle();

    final first = tester.getTopLeft(find.byType(ServiceCard).first);
    final second = tester.getTopLeft(find.byType(ServiceCard).at(1));

    // Two columns: same row, side by side.
    expect(second.dy, closeTo(first.dy, 0.5));
    expect(second.dx, greaterThan(first.dx));
  });
}
