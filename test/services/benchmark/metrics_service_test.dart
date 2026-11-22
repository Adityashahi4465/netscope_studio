import 'package:flutter_test/flutter_test.dart';

import '../../../lib/modals/tcp_result.dart';
import '../../../lib/modals/udp_result.dart';
import '../../../lib/services/benchmark/metrics_service.dart';
import '../../../lib/services/simulation/network_simulator.dart';

void main() {
  const metrics = MetricsService();
  test(
    'weighted goodput, unique delivery, pooled RTTs and within-run variation',
    () {
      final m = metrics.udp(const [
        UdpResult(
          runIndex: 1,
          rttSamplesMs: [1, 5, 3],
          packetsSent: 8,
          uniqueReceived: 6,
          bytesReceived: 600,
          transferSeconds: 1,
          duplicates: 2,
          probeTimeouts: 1,
        ),
        UdpResult(
          runIndex: 2,
          rttSamplesMs: [21],
          packetsSent: 2,
          uniqueReceived: 1,
          bytesReceived: 100,
          transferSeconds: 3,
        ),
      ]);
      expect(m.throughputMbps, .0014);
      expect(
        [m.minRttMs, m.avgRttMs, m.maxRttMs, m.medianRttMs, m.p95RttMs],
        [1, 7.5, 21, 4, 21],
      );
      expect(m.meanAbsRttVariationMs, 3);
      expect(
        [m.sampleCount, m.variationPairs, m.runs, m.timeouts, m.duplicates],
        [4, 2, 2, 1, 2],
      );
      expect([m.lossPercent, m.deliveryPercent], [30, 70]);
    },
  );
  test(
    'TCP counts receiver-acknowledged bytes and empty denominators are safe',
    () {
      final m = metrics.tcp(const [
        TcpResult(
          runIndex: 1,
          bytesSent: 400,
          bytesAcked: 200,
          transferSeconds: 1,
        ),
      ]);
      expect(m.throughputMbps, .0016);
      expect(m.deliveryPercent, 50);
      expect(metrics.throughput(100, 0), 0);
      expect(metrics.udp([]).avgRttMs, 0);
      expect(metrics.udp([]).deliveryPercent, 0);
    },
  );
  test('pacer uses absolute deadlines and permits uncapped writes', () {
    const cap = SendRatePacer(1);
    expect(cap.deadline(125000), const Duration(seconds: 1));
    expect(
      cap.remaining(125000, const Duration(milliseconds: 900)),
      const Duration(milliseconds: 100),
    );
    expect(const SendRatePacer(0).deadline(1000), Duration.zero);
  });
}
