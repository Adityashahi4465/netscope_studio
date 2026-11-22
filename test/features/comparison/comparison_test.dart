import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../lib/core/enums/protocol_type.dart';
import '../../../lib/core/enums/simulation_type.dart';
import '../../../lib/core/utility/csv_exporter.dart';
import '../../../lib/features/comparison/controller/comparison_controller.dart';
import '../../../lib/features/comparison/controller/comparison_report.dart';
import '../../../lib/features/comparison/widgets/comparison_chart.dart';
import '../../../lib/main.dart';
import '../../../lib/services/providers.dart';
import '../../../lib/modals/benchmark_config.dart';
import '../../../lib/modals/experiment_model.dart';
import '../../../lib/modals/simulation_config.dart';
import '../../../lib/services/benchmark/benchmark_service.dart';
import '../../../lib/services/benchmark/comparison_service.dart';
import '../../../lib/services/benchmark/i_benchmark_service.dart';
import '../../../lib/services/benchmark/metrics_service.dart';
import '../../../lib/services/database/database_service.dart';
import '../../../lib/services/experiment_repository.dart';
import '../../../lib/theme/app_colors.dart';
import '../../../lib/theme/app_theme.dart';

void main() {
  late ExperimentRepository repo;
  final experiments = <ExperimentModel>[];
  setUpAll(() async {
    final folder = await Directory.systemTemp.createTemp('netscope-compare-');
    final db = DatabaseService(path: p.join(folder.path, 'test.db'));
    repo = ExperimentRepository(db);
    final service = BenchmarkService();
    addTearDown(() async {
      service.dispose();
      await db.close();
      await folder.delete(recursive: true);
    });
    final tcp = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final udp = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final local = BenchmarkConfig(
      tcpPort: tcp.port,
      udpPort: udp.port,
      tcpPayloadBytes: 4096,
      packetCount: 16,
      rttProbes: 1,
      repetitions: 2,
    );
    udp.close();
    await tcp.close();
    final configs = [
      local,
      local.copyWith(
        protocol: ProtocolType.udp,
        simulation: const SimulationConfig(
          type: SimulationType.udpLoss,
          lossPercent: 25,
          seed: 17,
        ),
      ),
    ];
    for (final config in configs) {
      final result = (await service.run(
        config,
        CancelToken(),
      )).fold((f) => fail(f.message), (r) => r);
      final entry = ExperimentModel(
        id: result.id,
        name: config.protocol.label,
        createdAt: result.completedAt,
        result: result,
      );
      (await repo.save(entry)).fold((f) => fail(f.message), (_) {});
      experiments.add(entry);
    }
  });

  test('compare two saved real runs, pool conditions, and retain the latest selection', () async {
    final controller = ComparisonController(
      repo,
      const MetricsService(),
      const ComparisonService(),
      const CsvExporter(),
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.state.available, hasLength(2));
    expect(controller.state.report, isNull);
    final first = controller.toggle(experiments.first.id);
    final second = controller.toggle(experiments.last.id);
    await Future.wait([first, second]);
    final report = controller.state.report!;
    expect(report.experiments.map((e) => e.id), experiments.map((e) => e.id));
    expect(report.repetitions.map((e) => e.label), [
      'E1/R1',
      'E1/R2',
      'E2/R1',
      'E2/R2',
    ]);
    expect(report.conditions, hasLength(2));
    expect(report.conditionLabels.last, contains('25.0% UDP discard'));
    expect(
      report.measurements[ComparisonMetric.throughput]!.first.tcp,
      experiments.first.result.tcpAggregate.throughputMbps,
    );
    expect(report.measurements[ComparisonMetric.throughput]!.last.tcp, isNull);
    expect(report.measurements[ComparisonMetric.variation]!.first.udp, isNull);
    expect(report.insights.join(' '), contains('OS scheduling'));
    await controller.toggle(experiments.first.id);
    expect(controller.state.report!.experiments.single.id, experiments.last.id);
    await controller.toggle(experiments.last.id);
    expect(controller.state.report, isNull);
  });

  testWidgets(
    'comparison route renders saved selections, six charts and measured insights',
    (tester) async {
      final scope = ProviderContainer(
        overrides: [experimentRepositoryProvider.overrideWithValue(repo)],
      );
      final keepAlive = scope.listen(comparisonControllerProvider, (_, _) {});
      addTearDown(() {
        keepAlive.close();
        scope.dispose();
      });
      await tester.runAsync(() async {
        await AppTheme.loadFonts();
        final controller = scope.read(comparisonControllerProvider.notifier);
        await controller.refresh();
        for (final item in experiments) {
          await controller.toggle(item.id);
        }
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(container: scope, child: const MyApp()),
      );
      await tester.tap(find.byTooltip('TCP vs UDP'));
      await tester.pumpAndSettle();
      expect(find.text('TCP vs UDP comparison'), findsOneWidget);
      for (final item in experiments) {
        expect(
          tester.widget<CheckboxListTile>(find.byKey(ValueKey(item.id))).value,
          isTrue,
        );
      }
      final page = find
          .ancestor(
            of: find.text('TCP vs UDP comparison'),
            matching: find.byType(ListView),
          )
          .first;
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: page, matching: find.byType(Scrollable)).first,
      );
      final titles = <String>{};
      for (var i = 0; i < 40; i++) {
        titles.addAll(
          tester
              .widgetList<ComparisonChart>(find.byType(ComparisonChart))
              .map((chart) => chart.title),
        );
        if (find.text('Measured insights').evaluate().isNotEmpty) break;
        scroll.position.jumpTo(scroll.position.pixels + 240);
        await tester.pumpAndSettle();
      }
      expect(
        titles,
        containsAll([
          'Received throughput',
          'Average RTT',
          'Mean absolute RTT variation',
          'Delivery success',
          'Throughput per repetition',
          'Throughput across simulated conditions',
        ]),
      );
      expect(find.text('Measured insights'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chart distinguishes measured zero and missing protocol in a narrow window',
    (tester) async {
      await tester.runAsync(AppTheme.loadFonts);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SizedBox(
              width: 260,
              child: ComparisonChart(
                title: 'Received throughput',
                unit: 'Mbps',
                points: [ChartPoint('E1', 4, 2), ChartPoint('E2', null, 0)],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups.first.barRods.map((r) => r.color), [
        AppColors.tcp,
        AppColors.udp,
      ]);
      expect(chart.data.barGroups.last.barRods.single.toY, 0);
      expect(find.text('TCP'), findsOneWidget);
      expect(find.text('UDP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
