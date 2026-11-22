import 'dart:async';

import '../../core/type_defs.dart';
import '../../modals/benchmark_config.dart';
import '../../modals/benchmark_result.dart';
import '../networking/network_failure.dart';

class CancelToken {
  final _events = StreamController<void>.broadcast(sync: true);
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  Stream<void> get onCancel => _events.stream;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _events.add(null);
    unawaited(_events.close());
  }

  void check() {
    if (_cancelled) {
      throw const NetworkFailure(
        NetworkFailureCode.cancelled,
        'Benchmark cancelled.',
      );
    }
  }
}

class BenchmarkProgress {
  final String phase;
  final int runIndex;
  final double percent;
  final bool tcpOnline;
  final bool udpOnline;
  final AggregateMetrics tcp;
  final AggregateMetrics udp;
  const BenchmarkProgress(
    this.phase,
    this.runIndex,
    this.percent, {
    this.tcpOnline = false,
    this.udpOnline = false,
    this.tcp = AggregateMetrics.empty,
    this.udp = AggregateMetrics.empty,
  });
}

abstract interface class IBenchmarkService {
  Stream<BenchmarkProgress> get progress;
  FutureEither<BenchmarkResult> run(BenchmarkConfig config, CancelToken token);
}
