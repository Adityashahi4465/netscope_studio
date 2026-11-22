import '../../modals/benchmark_result.dart';
import '../../modals/tcp_result.dart';
import '../../modals/udp_result.dart';

typedef _Observation = ({
  int receivedBytes,
  double seconds,
  int sent,
  int delivered,
  List<double> samples,
  int timeouts,
  int duplicates,
});

class MetricsService {
  const MetricsService();

  double throughput(int receivedBytes, double seconds) =>
      seconds <= 0 ? 0 : receivedBytes * 8 / (seconds * 1000000);

  AggregateMetrics tcp(Iterable<TcpResult> runs) => _aggregate(
    runs.map(
      (run) => (
        receivedBytes: run.bytesAcked,
        seconds: run.transferSeconds,
        sent: run.bytesSent,
        delivered: run.bytesAcked,
        samples: run.rttSamplesMs,
        timeouts: run.probeTimeouts,
        duplicates: 0,
      ),
    ),
  );

  AggregateMetrics udp(Iterable<UdpResult> runs) => _aggregate(
    runs.map(
      (run) => (
        receivedBytes: run.bytesReceived,
        seconds: run.transferSeconds,
        sent: run.packetsSent,
        delivered: run.uniqueReceived,
        samples: run.rttSamplesMs,
        timeouts: run.probeTimeouts,
        duplicates: run.duplicates,
      ),
    ),
  );

  /// Pool payload bytes and elapsed bulk time. Pool successful RTTs for
  /// percentiles (nearest-rank p95). Variation pairs never cross a run boundary.
  AggregateMetrics _aggregate(Iterable<_Observation> runs) {
    var count = 0;
    var bytes = 0;
    var seconds = 0.0;
    var sent = 0;
    var delivered = 0;
    var timeouts = 0;
    var duplicates = 0;
    var variation = 0.0;
    var pairs = 0;
    final samples = <double>[];
    for (final run in runs) {
      count++;
      bytes += run.receivedBytes;
      seconds += run.seconds;
      sent += run.sent;
      delivered += run.delivered;
      timeouts += run.timeouts;
      duplicates += run.duplicates;
      samples.addAll(run.samples);
      for (var i = 1; i < run.samples.length; i++) {
        variation += (run.samples[i] - run.samples[i - 1]).abs();
        pairs++;
      }
    }
    samples.sort();
    final n = samples.length;
    return AggregateMetrics(
      runs: count,
      sampleCount: n,
      variationPairs: pairs,
      throughputMbps: throughput(bytes, seconds),
      minRttMs: n == 0 ? 0 : samples.first,
      avgRttMs: n == 0 ? 0 : samples.reduce((a, b) => a + b) / n,
      maxRttMs: n == 0 ? 0 : samples.last,
      medianRttMs: n == 0 ? 0 : (samples[(n - 1) ~/ 2] + samples[n ~/ 2]) / 2,
      p95RttMs: n == 0 ? 0 : samples[(n * 0.95).ceil() - 1],
      meanAbsRttVariationMs: pairs == 0 ? 0 : variation / pairs,
      deliveryPercent: sent == 0 ? 0 : 100 * delivered / sent,
      lossPercent: sent == 0 ? 0 : 100 * (sent - delivered) / sent,
      duplicates: duplicates,
      timeouts: timeouts,
    );
  }
}
