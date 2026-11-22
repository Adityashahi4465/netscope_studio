import 'benchmark_config.dart';
import 'tcp_result.dart';
import 'udp_result.dart';

/// Aggregated metrics across repetitions for one protocol.
/// Computed by MetricsService, never in widgets.
class AggregateMetrics {
  final int runs;
  final int sampleCount;
  final int variationPairs;
  final double throughputMbps;
  final double minRttMs;
  final double avgRttMs;
  final double maxRttMs;
  final double medianRttMs;
  final double p95RttMs;

  /// Mean absolute difference between consecutive successful RTT samples.
  final double meanAbsRttVariationMs;
  final double lossPercent;
  final double deliveryPercent;
  final int timeouts;
  final int duplicates;

  const AggregateMetrics({
    this.runs = 0,
    this.sampleCount = 0,
    this.variationPairs = 0,
    this.throughputMbps = 0,
    this.minRttMs = 0,
    this.avgRttMs = 0,
    this.maxRttMs = 0,
    this.medianRttMs = 0,
    this.p95RttMs = 0,
    this.meanAbsRttVariationMs = 0,
    this.lossPercent = 0,
    this.deliveryPercent = 0,
    this.timeouts = 0,
    this.duplicates = 0,
  });

  static const AggregateMetrics empty = AggregateMetrics();

  Map<String, dynamic> toMap() => <String, dynamic>{
    'runs': runs,
    'sampleCount': sampleCount,
    'variationPairs': variationPairs,
    'throughputMbps': throughputMbps,
    'minRttMs': minRttMs,
    'avgRttMs': avgRttMs,
    'maxRttMs': maxRttMs,
    'medianRttMs': medianRttMs,
    'p95RttMs': p95RttMs,
    'meanAbsRttVariationMs': meanAbsRttVariationMs,
    'lossPercent': lossPercent,
    'deliveryPercent': deliveryPercent,
    'timeouts': timeouts,
    'duplicates': duplicates,
  };

  factory AggregateMetrics.fromMap(Map<String, dynamic> m) => AggregateMetrics(
    runs: (m['runs'] as num).toInt(),
    sampleCount: (m['sampleCount'] as num?)?.toInt() ?? 0,
    variationPairs: (m['variationPairs'] as num?)?.toInt() ?? 0,
    throughputMbps: (m['throughputMbps'] as num).toDouble(),
    minRttMs: (m['minRttMs'] as num).toDouble(),
    avgRttMs: (m['avgRttMs'] as num).toDouble(),
    maxRttMs: (m['maxRttMs'] as num).toDouble(),
    medianRttMs: (m['medianRttMs'] as num).toDouble(),
    p95RttMs: (m['p95RttMs'] as num).toDouble(),
    meanAbsRttVariationMs: (m['meanAbsRttVariationMs'] as num).toDouble(),
    lossPercent: (m['lossPercent'] as num).toDouble(),
    deliveryPercent: (m['deliveryPercent'] as num).toDouble(),
    timeouts: (m['timeouts'] as num).toInt(),
    duplicates: (m['duplicates'] as num).toInt(),
  );
}

class BenchmarkResult {
  final String id;
  final DateTime completedAt;
  final double totalSeconds;
  final BenchmarkConfig config;
  final List<TcpResult> tcpRuns;
  final List<UdpResult> udpRuns;
  final AggregateMetrics tcpAggregate;
  final AggregateMetrics udpAggregate;

  const BenchmarkResult({
    required this.id,
    required this.completedAt,
    required this.config,
    this.totalSeconds = 0,
    this.tcpRuns = const <TcpResult>[],
    this.udpRuns = const <UdpResult>[],
    this.tcpAggregate = AggregateMetrics.empty,
    this.udpAggregate = AggregateMetrics.empty,
  });

  bool get hasTcp => tcpRuns.isNotEmpty;
  bool get hasUdp => udpRuns.isNotEmpty;

  BenchmarkResult copyWith({
    AggregateMetrics? tcpAggregate,
    AggregateMetrics? udpAggregate,
  }) {
    return BenchmarkResult(
      id: id,
      completedAt: completedAt,
      totalSeconds: totalSeconds,
      config: config,
      tcpRuns: tcpRuns,
      udpRuns: udpRuns,
      tcpAggregate: tcpAggregate ?? this.tcpAggregate,
      udpAggregate: udpAggregate ?? this.udpAggregate,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'completedAt': completedAt.toIso8601String(),
    'totalSeconds': totalSeconds,
    'config': config.toMap(),
    'tcpRuns': tcpRuns.map((TcpResult r) => r.toMap()).toList(),
    'udpRuns': udpRuns.map((UdpResult r) => r.toMap()).toList(),
    'tcpAggregate': tcpAggregate.toMap(),
    'udpAggregate': udpAggregate.toMap(),
  };

  factory BenchmarkResult.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> asMap(Object? o) =>
        Map<String, dynamic>.from(o! as Map);

    return BenchmarkResult(
      id: map['id'] as String,
      completedAt: DateTime.parse(map['completedAt'] as String),
      totalSeconds: (map['totalSeconds'] as num).toDouble(),
      config: BenchmarkConfig.fromMap(asMap(map['config'])),
      tcpRuns: (map['tcpRuns'] as List)
          .map((Object? e) => TcpResult.fromMap(asMap(e)))
          .toList(growable: false),
      udpRuns: (map['udpRuns'] as List)
          .map((Object? e) => UdpResult.fromMap(asMap(e)))
          .toList(growable: false),
      tcpAggregate: AggregateMetrics.fromMap(asMap(map['tcpAggregate'])),
      udpAggregate: AggregateMetrics.fromMap(asMap(map['udpAggregate'])),
    );
  }
}
