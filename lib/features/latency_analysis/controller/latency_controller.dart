import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/protocol_type.dart';
import '../../../modals/benchmark_result.dart';
import '../../../services/benchmark/metrics_service.dart';
import '../../dashboard/controller/benchmark_controller.dart';

class LatencySelection {
  final ProtocolType protocol;
  final int run;
  const LatencySelection({this.protocol = ProtocolType.tcp, this.run = 0});
}

class LatencyController extends StateNotifier<LatencySelection> {
  LatencyController() : super(const LatencySelection());
  void protocol(ProtocolType value) =>
      state = LatencySelection(protocol: value);
  void run(int value) =>
      state = LatencySelection(protocol: state.protocol, run: value);
}

final latencyControllerProvider =
    StateNotifierProvider.autoDispose<LatencyController, LatencySelection>(
      (ref) => LatencyController(),
    );
final latencyReportProvider = Provider.autoDispose(
  (ref) => LatencyReport.from(
    ref.watch(benchmarkControllerProvider).result,
    ref.watch(latencyControllerProvider),
  ),
);

class RttBin {
  final double lower;
  final double upper;
  final int count;
  const RttBin(this.lower, this.upper, this.count);
}

class LatencyReport {
  final ProtocolType protocol;
  final int runIndex;
  final List<int> runs;
  final List<double> samples;
  final AggregateMetrics metrics;
  final List<RttBin> histogram;
  final String? experimentId;

  const LatencyReport({
    required this.protocol,
    required this.runIndex,
    required this.runs,
    required this.samples,
    required this.metrics,
    required this.histogram,
    this.experimentId,
  });

  factory LatencyReport.from(
    BenchmarkResult? result,
    LatencySelection selection,
  ) {
    final tcp = selection.protocol == ProtocolType.tcp;
    final runs = <int>[
      if (tcp)
        ...?result?.tcpRuns.map((run) => run.runIndex)
      else
        ...?result?.udpRuns.map((run) => run.runIndex),
    ];
    final index = runs.contains(selection.run)
        ? selection.run
        : runs.firstOrNull ?? 0;
    const service = MetricsService();
    final metrics = tcp
        ? service.tcp(result?.tcpRuns.where((r) => r.runIndex == index) ?? [])
        : service.udp(result?.udpRuns.where((r) => r.runIndex == index) ?? []);
    final samples = List<double>.unmodifiable(
      tcp
          ? result?.tcpRuns
                    .where((r) => r.runIndex == index)
                    .expand((r) => r.rttSamplesMs) ??
                []
          : result?.udpRuns
                    .where((r) => r.runIndex == index)
                    .expand((r) => r.rttSamplesMs) ??
                [],
    );
    return LatencyReport(
      protocol: selection.protocol,
      runIndex: index,
      runs: List.unmodifiable(runs),
      samples: samples,
      metrics: metrics,
      histogram: bins(samples),
      experimentId: result?.id,
    );
  }

  static List<RttBin> bins(List<double> samples) {
    if (samples.isEmpty) return const [];
    final low = samples.reduce(min);
    final high = samples.reduce(max);
    final width = high == low ? 1.0 : (high - low) / 8;
    final start = high == low ? max(0.0, low - 0.5) : low;
    final counts = List<int>.filled(high == low ? 1 : 8, 0);
    for (final value in samples) {
      counts[((value - start) / width).floor().clamp(0, counts.length - 1)]++;
    }
    return List<RttBin>.unmodifiable(
      List.generate(
        counts.length,
        (i) => RttBin(start + i * width, start + (i + 1) * width, counts[i]),
      ),
    );
  }
}
