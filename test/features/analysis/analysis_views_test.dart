import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/dashboard/controller/benchmark_controller.dart';
import '../../../lib/features/dashboard/controller/config_field.dart';
import '../../../lib/features/history/controller/history_controller.dart';
import '../../../lib/features/latency_analysis/widgets/latency_charts.dart';
import '../../../lib/features/packet_loss/widgets/delivery_map.dart';
import '../../../lib/features/protocol_visualizer/controller/visualizer_controller.dart';
import '../../../lib/main.dart';
import '../../../lib/services/database/database_service.dart';
import '../../../lib/services/providers.dart';
import '../../../lib/theme/app_theme.dart';

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('NETSCOPE_SCREENSHOTS')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('build/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets(
    'new screens render real measurements and resize without overflow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1100, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final folder = await tester.runAsync(
        () => Directory.systemTemp.createTemp('netscope-views-'),
      );
      final db = DatabaseService(path: '${folder!.path}/test.db');
      final scope = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        scope.dispose();
        await tester.runAsync(() async {
          await db.close();
          await folder.delete(recursive: true);
        });
      });
      await tester.runAsync(() async {
        await AppTheme.loadFonts();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        final controller = scope.read(benchmarkControllerProvider.notifier);
        final tcp = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final udp = await RawDatagramSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        controller.edit(ConfigField.tcpPort, '${tcp.port}');
        controller.edit(ConfigField.udpPort, '${udp.port}');
        udp.close();
        await tcp.close();
        controller.edit(ConfigField.packets, '300');
        controller.edit(ConfigField.probes, '3');
        await controller.start();
        expect(scope.read(benchmarkControllerProvider).result, isNotNull);
        await controller.save();
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: UncontrolledProviderScope(
            container: scope,
            child: const MyApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Latency analysis'));
      await tester.pumpAndSettle();
      final page = find
          .ancestor(
            of: find.text('Latency analysis'),
            matching: find.byType(ListView),
          )
          .first;
      final latencyScroll = tester.state<ScrollableState>(
        find.descendant(of: page, matching: find.byType(Scrollable)).first,
      );
      for (
        var i = 0;
        i < 20 && find.byType(LatencyCharts).evaluate().isEmpty;
        i++
      ) {
        latencyScroll.position.jumpTo(latencyScroll.position.pixels + 500);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byType(LatencyCharts));
      await tester.pumpAndSettle();
      expect(find.text('Measured per-probe RTT (ms)'), findsOneWidget);
      await capture(tester, 'latency');
      for (final width in [540.0, 360.0]) {
        tester.view.physicalSize = Size(width, 820);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await tester.tap(find.byTooltip('Packet loss'));
      await tester.pumpAndSettle();
      final map = find.byType(DeliveryMap);
      final lossPage = find
          .ancestor(
            of: find.text('UDP packet loss'),
            matching: find.byType(ListView),
          )
          .first;
      final lossScroll = tester.state<ScrollableState>(
        find.descendant(of: lossPage, matching: find.byType(Scrollable)).first,
      );
      for (var i = 0; i < 20 && map.evaluate().isEmpty; i++) {
        lossScroll.position.jumpTo(lossScroll.position.pixels + 500);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(map);
      await tester.pumpAndSettle();
      expect(find.text('Page 1 of 2'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Next sequence page'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next sequence page'));
      await tester.pumpAndSettle();
      expect(find.text('Page 2 of 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1100, 900);
      await tester.pumpAndSettle();
      await tester.ensureVisible(map);
      await tester.pumpAndSettle();
      await capture(tester, 'packet-loss');

      await tester.tap(find.byTooltip('Protocol visualizer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(scope.read(visualizerControllerProvider(null)).replay, isTrue);
      scope.read(visualizerControllerProvider(null).notifier).seek(1.8);
      await tester.pumpAndSettle();
      await capture(tester, 'visualizer');
      tester.view.physicalSize = const Size(360, 820);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Experiment history'));
      await tester.pump();
      await tester.runAsync(() async {
        await scope.read(historyControllerProvider.notifier).refresh();
      });
      await tester.pumpAndSettle();
      expect(scope.read(historyControllerProvider).items, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Search saved experiments'),
        'no-such-experiment',
      );
      await tester.pumpAndSettle();
      expect(find.text('No experiments match these filters.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Search saved experiments'),
        '',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open details'));
      await tester.runAsync(() async {
        final clock = Stopwatch()..start();
        while (scope.read(historyControllerProvider).openingId != null) {
          if (clock.elapsed > const Duration(seconds: 5)) {
            fail('Loading history details timed out.');
          }
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pumpAndSettle();
      final saved = scope.read(historyControllerProvider).detail!;
      expect(find.text('Measured repetitions'), findsOneWidget);
      await tester.ensureVisible(find.text('Replay recorded UDP requests'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replay recorded UDP requests'));
      await tester.pumpAndSettle();
      expect(
        scope.read(visualizerControllerProvider(saved.result)).replay,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
