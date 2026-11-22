import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/enums/protocol_type.dart';
import '../../../lib/features/latency_analysis/controller/latency_controller.dart';
import '../../../lib/features/packet_loss/controller/packet_loss_controller.dart';
import '../../../lib/modals/benchmark_config.dart';
import '../../../lib/modals/benchmark_result.dart';
import '../../../lib/modals/packet_record.dart';
import '../../../lib/modals/udp_result.dart';
import '../../support/experiment_fixture.dart';

void main() {
  test(
    'latency report uses selected measured repetition and exact metrics',
    () {
      final report = LatencyReport.from(
        experimentFixture().result,
        const LatencySelection(),
      );
      expect(report.samples, [1, 2, 3, 4, 5]);
      expect(report.metrics.minRttMs, 1);
      expect(report.metrics.avgRttMs, 3);
      expect(report.metrics.maxRttMs, 5);
      expect(report.metrics.medianRttMs, 3);
      expect(report.metrics.p95RttMs, 5);
      expect(report.metrics.meanAbsRttVariationMs, 1);
      expect(report.histogram.fold(0, (sum, bin) => sum + bin.count), 5);
      final udp = LatencyReport.from(
        experimentFixture().result,
        const LatencySelection(protocol: ProtocolType.udp, run: 99),
      );
      expect(udp.runIndex, 0);
      expect(udp.samples, [2, 4, 6]);
      expect(udp.metrics.timeouts, 2);
      expect(udp.metrics.meanAbsRttVariationMs, 2);
    },
  );

  test('histogram handles empty, identical, zero, and boundary values', () {
    expect(LatencyReport.bins([]), isEmpty);
    final flat = LatencyReport.bins([0, 0, 0]);
    expect(flat.single.count, 3);
    expect(flat.single.lower, 0);
    expect(flat.single.upper, greaterThan(0));
    final bins = LatencyReport.bins([0, 1, 2, 3, 4, 5, 6, 7, 8]);
    expect(bins.last.count, 2);
    expect(bins.fold(0, (n, b) => n + b.count), 9);
    final empty = LatencyReport.from(null, const LatencySelection());
    expect(empty.runs, isEmpty);
    expect(empty.metrics.sampleCount, 0);
  });

  test(
    'delivery map pages real statuses without inventing missing evidence',
    () {
      final report = PacketLossReport.from(
        experimentFixture().result,
        const PacketLossSelection(),
      );
      expect(report.cells.length, 256);
      expect(report.pages, 2);
      expect(report.configuredLoss, 25);
      expect(report.observedLoss, 50);
      expect(report.cells[0].status, PacketStatus.droppedBySimulation);
      expect(report.cells[1].status, PacketStatus.missing);
      expect(report.cells[2].status, PacketStatus.delivered);
      final last = PacketLossReport.from(
        experimentFixture().result,
        const PacketLossSelection(page: 99),
      );
      expect(last.page, 1);
      expect(last.cells.first.sequence, 256);
      expect(last.cells.last.sequence, 299);
      final sparse = BenchmarkResult(
        id: 'legacy',
        completedAt: DateTime.utc(2026),
        config: const BenchmarkConfig(),
        udpRuns: const [UdpResult(runIndex: 0, packetsSent: 2)],
      );
      final unknown = PacketLossReport.from(
        sparse,
        const PacketLossSelection(),
      );
      expect(unknown.cells.every((cell) => cell.status == null), isTrue);
      expect(unknown.cells.first.label, contains('No recorded'));
      expect(PacketLossReport.from(null, const PacketLossSelection()).pages, 0);
    },
  );
}
