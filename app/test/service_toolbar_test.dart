import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taildeck/data/models/icon_ref.dart';
import 'package:taildeck/data/models/service_item.dart';
import 'package:taildeck/theme/app_theme.dart';
import 'package:taildeck/ui/web/widgets/service_toolbar.dart';

ServiceItem _service() => ServiceItem(
  id: 'a',
  name: 'DSH',
  url: 'http://100.114.169.45:3080',
  icon: const IconRef(
    kind: IconKind.monogram,
    value: 'D',
    accent: 0xFF22C55E,
  ),
  sortOrder: 0,
  createdAt: DateTime.utc(2026),
);

Widget _harness({
  bool canGoBack = false,
  bool canGoForward = false,
  bool loading = false,
  VoidCallback? onBack,
  VoidCallback? onForward,
  VoidCallback? onReload,
  VoidCallback? onClose,
}) => MaterialApp(
  theme: buildTailDeckTheme(),
  home: Scaffold(
    body: ServiceToolbar(
      service: _service(),
      canGoBack: ValueNotifier<bool>(canGoBack),
      canGoForward: ValueNotifier<bool>(canGoForward),
      loading: ValueNotifier<bool>(loading),
      progress: ValueNotifier<double>(0),
      onBack: onBack ?? () {},
      onForward: onForward ?? () {},
      onReload: onReload ?? () {},
      onClose: onClose ?? () {},
      onAction: (_) {},
    ),
  ),
);

void main() {
  testWidgets('identifies the service', (tester) async {
    await tester.pumpWidget(_harness());
    expect(find.text('DSH'), findsOneWidget);
    expect(find.text('100.114.169.45:3080'), findsOneWidget);
  });

  testWidgets('close is always available, even with no history', (
    tester,
  ) async {
    // Back is disabled without history, but close never is: there must always
    // be a visible way out of the service.
    await tester.pumpWidget(_harness(canGoBack: false, canGoForward: false));
    expect(find.byIcon(Icons.close), findsOneWidget);

    final back = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_back),
    );
    expect(back.onPressed, isNull, reason: 'back disabled without history');

    // And it stays available once you have navigated.
    await tester.pumpWidget(_harness(canGoBack: true, canGoForward: true));
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.arrow_back),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('close fires its callback', (tester) async {
    var closes = 0;
    await tester.pumpWidget(_harness(onClose: () => closes++));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(closes, 1);
  });

  testWidgets('forward is disabled without forward history', (tester) async {
    await tester.pumpWidget(_harness(canGoForward: false));
    final disabled = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_forward),
    );
    expect(disabled.onPressed, isNull);

    await tester.pumpWidget(_harness(canGoForward: true));
    await tester.pump();
    final enabled = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_forward),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('reload fires its callback', (tester) async {
    var reloads = 0;
    await tester.pumpWidget(_harness(onReload: () => reloads++));

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    expect(reloads, 1);
  });

  testWidgets('back fires its callback', (tester) async {
    var backs = 0;
    await tester.pumpWidget(_harness(canGoBack: true, onBack: () => backs++));

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(backs, 1);
  });

  testWidgets('the overflow exposes the remaining actions', (tester) async {
    await tester.pumpWidget(_harness());

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Open in browser'), findsOneWidget);
    expect(find.text('Copy address'), findsOneWidget);
    expect(find.text('Service settings'), findsOneWidget);
    expect(find.text('Unload page'), findsOneWidget);
  });
}
