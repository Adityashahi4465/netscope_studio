import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../lib/core/enums/benchmark_status.dart';
import '../lib/features/comparison/controller/comparison_controller.dart';
import '../lib/features/dashboard/controller/benchmark_controller.dart';
import '../lib/features/history/controller/history_controller.dart';
import '../lib/features/latency_analysis/view/latency_analysis_view.dart';
import '../lib/features/protocol_visualizer/controller/visualizer_controller.dart';
import '../lib/main.dart';
import '../lib/services/database/database_service.dart';
import '../lib/services/providers.dart';
import '../lib/theme/app_theme.dart';

Future<void> waitFor(
  WidgetTester tester,
  bool Function() complete, {
  String reason = 'UI operation',
}) async {
  final clock = Stopwatch()..start();
  while (!complete()) {
    if (clock.elapsed > const Duration(seconds: 30)) fail('$reason timed out.');
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'configure Quick, run real sockets, save, inspect, compare and replay',
    (tester) async {
      final folder = await Directory.systemTemp.createTemp(
        'netscope-integration-',
      );
      final db = DatabaseService(path: '${folder.path}/history.db');
      final scope = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        scope.dispose();
        await db.close();
        await folder.delete(recursive: true);
      });
      await AppTheme.loadFonts();
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const MyApp()),
      );
      await tester.pumpAndSettle();

      expect(
        scope.read(benchmarkControllerProvider).preset.label,
        'Quick Benchmark',
      );

      // Pick free loopback ports for this isolated test; benchmark servers and
      // clients still run inside the application via the normal service graph.
      final port = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final udp = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      final tcpPort = port.port;
      final udpPort = udp.port;
      udp.close();
      await port.close();
      await tester.tap(find.byTooltip('Run settings'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'TCP port'),
        '$tcpPort',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'UDP port'),
        '$udpPort',
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      // Editing ports marks the otherwise unchanged Quick workload as Custom.
      expect(scope.read(benchmarkControllerProvider).config.packetCount, 500);

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Start'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Start'));
      await waitFor(
        tester,
        () => !scope.read(benchmarkControllerProvider).status.isActive,
        reason: 'Real Quick Benchmark',
      );
      final state = scope.read(benchmarkControllerProvider);
      expect(state.status, BenchmarkStatus.completed, reason: state.error);
      expect(
        state.result!.tcpRuns.single.bytesAcked,
        state.config.tcpPayloadBytes,
      );
      expect(
        state.result!.udpRuns.single.packetsSent,
        state.config.packetCount,
      );
      expect(state.result!.tcpAggregate.throughputMbps, greaterThan(0));
      final id = state.result!.id;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Save'));
      await waitFor(
        tester,
        () => !scope.read(benchmarkControllerProvider).saving,
        reason: 'Save experiment',
      );
      expect(
        scope.read(benchmarkControllerProvider).notice,
        'Experiment saved.',
      );

      await tester.tap(find.byTooltip('Experiment history'));
      await tester.pumpAndSettle();
      await waitFor(
        tester,
        () => !scope.read(historyControllerProvider).loading,
        reason: 'Load history',
      );
      expect(scope.read(historyControllerProvider).items.single.id, id);
      await tester.ensureVisible(find.byType(Checkbox).first);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Compare selected (1)'));
      await tester.tap(find.text('Compare selected (1)'));
      await tester.pumpAndSettle();
      await waitFor(
        tester,
        () => scope.read(comparisonControllerProvider).report != null,
        reason: 'Compare saved measurements',
      );
      expect(scope.read(comparisonControllerProvider).selected, {id});
      expect(
        scope
            .read(comparisonControllerProvider)
            .report!
            .experiments
            .single
            .result
            .id,
        id,
      );
      expect(find.text('TCP vs UDP comparison'), findsOneWidget);

      await tester.tap(find.byTooltip('Latency analysis'));
      await tester.pumpAndSettle();
      expect(find.byType(LatencyAnalysisView), findsOneWidget);
      await tester.tap(find.byTooltip('Packet loss'));
      await tester.pumpAndSettle();
      expect(find.text('UDP packet loss'), findsOneWidget);
      await tester.tap(find.byTooltip('Protocol visualizer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(scope.read(visualizerControllerProvider(null)).replay, isTrue);
      await tester.ensureVisible(find.text('Play timeline'));
      await tester.tap(find.text('Play timeline'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Pause timeline'));
      await tester.pumpAndSettle();
      expect(
        scope.read(visualizerControllerProvider(null)).position,
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
