import 'dart:convert';

import '../../../core/utility/formatters.dart';
import '../../../modals/benchmark_result.dart';
import '../../../modals/experiment_model.dart';
import '../../../modals/simulation_config.dart';
import '../../../services/benchmark/comparison_service.dart';
import '../../../services/benchmark/metrics_service.dart';

class ChartPoint {
  final String label;
  final double? tcp;
  final double? udp;
  const ChartPoint(this.label, this.tcp, this.udp);
}

enum ComparisonMetric {
  throughput('Received throughput', 'Mbps'),
  rtt('Average RTT', 'ms'),
  variation('Mean absolute RTT variation', 'ms'),
  delivery('Delivery success', '%');

  final String label;
  final String unit;
  const ComparisonMetric(this.label, this.unit);

  double? read(AggregateMetrics m) {
    if (m.runs == 0) return null;
    return switch (this) {
      throughput => m.throughputMbps,
      rtt => m.sampleCount == 0 ? null : m.avgRttMs,
      variation => m.variationPairs == 0 ? null : m.meanAbsRttVariationMs,
      delivery => m.deliveryPercent,
    };
  }
}

class ComparisonReport {
  final List<ExperimentModel> experiments;
  final Map<ComparisonMetric, List<ChartPoint>> measurements;
  final List<ChartPoint> repetitions;
  final List<ChartPoint> conditions;
  final List<String> conditionLabels;
  final List<String> insights;

  ComparisonReport._(
    this.experiments,
    this.measurements,
    this.repetitions,
    this.conditions,
    this.conditionLabels,
    this.insights,
  );

  factory ComparisonReport.from(
    List<ExperimentModel> items,
    MetricsService metrics,
    ComparisonService comparison,
  ) {
    final results = [for (final e in items) e.result];
    final measurements = {
      for (final metric in ComparisonMetric.values)
        metric: [
          for (var i = 0; i < results.length; i++)
            ChartPoint(
              'E${i + 1}',
              metric.read(results[i].tcpAggregate),
              metric.read(results[i].udpAggregate),
            ),
        ],
    };
    final repetitions = <ChartPoint>[];
    final groups = <String, List<BenchmarkResult>>{};
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      final tcp = {
        for (final r in result.tcpRuns)
          r.runIndex: metrics.throughput(r.bytesAcked, r.transferSeconds),
      };
      final udp = {
        for (final r in result.udpRuns)
          r.runIndex: metrics.throughput(r.bytesReceived, r.transferSeconds),
      };
      final indices = {...tcp.keys, ...udp.keys}.toList()..sort();
      for (final run in indices) {
        repetitions.add(ChartPoint('E${i + 1}/R$run', tcp[run], udp[run]));
      }
      groups
          .putIfAbsent(jsonEncode(result.config.simulation.toMap()), () => [])
          .add(result);
    }
    final conditions = <ChartPoint>[];
    final descriptions = <String>[];
    for (final group in groups.values) {
      final label = 'S${conditions.length + 1}';
      final tcp = metrics.tcp(group.expand((r) => r.tcpRuns));
      final udp = metrics.udp(group.expand((r) => r.udpRuns));
      conditions.add(
        ChartPoint(
          label,
          ComparisonMetric.throughput.read(tcp),
          ComparisonMetric.throughput.read(udp),
        ),
      );
      descriptions.add('$label · ${describe(group.first.config.simulation)}');
    }
    return ComparisonReport._(
      List.unmodifiable(items),
      Map.unmodifiable(measurements),
      List.unmodifiable(repetitions),
      List.unmodifiable(conditions),
      List.unmodifiable(descriptions),
      List.unmodifiable(comparison.insights(results)),
    );
  }

  static String describe(SimulationConfig s) =>
      '${s.type.label} · ${Formatters.percent(s.lossPercent)} UDP discard · ${s.delayMs} ± ${s.jitterMs} ms echo delay'
      ' · ${s.hasRateLimit ? Formatters.mbps(s.rateLimitMbps) : 'Uncapped'}${s.seed == null ? '' : ' · seed ${s.seed}'}';
}
