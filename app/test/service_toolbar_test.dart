import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taildeck/theme/app_theme.dart';
import 'package:taildeck/ui/web/widgets/service_toolbar.dart';

Widget _harness({
  bool canGoBack = false,
  bool canGoForward = false,
  bool loading = false,
  String urlText = 'http://100.114.169.45:3080',
  VoidCallback? onBack,
  VoidCallback? onForward,
  VoidCallback? onFullscreen,
  VoidCallback? onReload,
  VoidCallback? onUrlSubmit,
}) => MaterialApp(
  theme: buildTailDeckTheme(),
  home: Scaffold(
    body: ServiceToolbar(
      canGoBack: ValueNotifier<bool>(canGoBack),
      canGoForward: ValueNotifier<bool>(canGoForward),
      loading: ValueNotifier<bool>(loading),
      progress: ValueNotifier<double>(0),
      urlController: TextEditingController(text: urlText),
      urlFocus: FocusNode(),
      onUrlSubmit: onUrlSubmit ?? () {},
      onBack: onBack ?? () {},
      onForward: onForward ?? () {},
      onFullscreen: onFullscreen ?? () {},
      onReload: onReload ?? () {},
      onAction: (_) {},
    ),
  ),
);

void main() {
  testWidgets('shows the tab address once, editable in the appbar', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    // The URL appears exactly once — no repeated host line above or below.
    expect(find.text('http://100.114.169.45:3080'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('back is disabled without history; leaving is system back', (
    tester,
  ) async {
    // No close button: leaving is system back's job, so the row works the
    // page instead of duplicating navigation.
    await tester.pumpWidget(_harness(canGoBack: false, canGoForward: false));
    expect(find.byIcon(Icons.close), findsNothing);

    final back = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_back),
    );
    expect(back.onPressed, isNull, reason: 'back disabled without history');

    // And back enables once you have navigated.
    await tester.pumpWidget(_harness(canGoBack: true, canGoForward: true));
    await tester.pump();
    expect(find.byIcon(Icons.close), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.arrow_back),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('fullscreen fires its callback', (tester) async {
    var fullscreen = 0;
    await tester.pumpWidget(
      _harness(onFullscreen: () => fullscreen++),
    );

    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pump();

    expect(fullscreen, 1);
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
