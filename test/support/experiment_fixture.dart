import '../../lib/modals/benchmark_config.dart';
import '../../lib/modals/benchmark_result.dart';
import '../../lib/modals/experiment_model.dart';
import '../../lib/modals/packet_record.dart';
import '../../lib/modals/simulation_config.dart';
import '../../lib/modals/tcp_result.dart';
import '../../lib/modals/udp_result.dart';
import '../../lib/services/benchmark/metrics_service.dart';

/// Synthetic fixtures exercise rendering/math only, never the benchmark service.
ExperimentModel experimentFixture({
  String id = 'fixture',
  int packetCount = 300,
}) {
  final time = DateTime.utc(2026, 11, 22, 8);
  const tcp = [
    TcpResult(
      runIndex: 0,
      rttSamplesMs: [1, 2, 3, 4, 5],
      bytesSent: 1024,
      bytesAcked: 1024,
      transferSeconds: 1,
      completed: true,
    ),
  ];
  final records = List.generate(
    packetCount,
    (i) => PacketRecord(
      sequence: i,
      status: i % 4 == 0
          ? PacketStatus.droppedBySimulation
          : i % 4 == 1
          ? PacketStatus.missing
          : PacketStatus.delivered,
      sizeBytes: 1024,
      sentAtUs: i * 1000,
    ),
  );
  final received = records
      .where((r) => r.status == PacketStatus.delivered)
      .length;
  final dropped = records
      .where((r) => r.status == PacketStatus.droppedBySimulation)
      .length;
  final udp = [
    UdpResult(
      runIndex: 0,
      rttSamplesMs: [2, 4, 6],
      probeTimeouts: 2,
      packetsSent: packetCount,
      uniqueReceived: received,
      droppedBySimulation: dropped,
      bytesReceived: received * 988,
      transferSeconds: 1,
      duplicates: 2,
      outOfOrder: 1,
      packetRecords: List.unmodifiable(records),
    ),
  ];
  const metrics = MetricsService();
  return ExperimentModel(
    id: id,
    name: 'Fixture $id',
    createdAt: time,
    result: BenchmarkResult(
      id: id,
      completedAt: time,
      config: BenchmarkConfig(
        packetCount: packetCount,
        simulation: const SimulationConfig(lossPercent: 25, seed: 17),
      ),
      tcpRuns: tcp,
      udpRuns: udp,
      tcpAggregate: metrics.tcp(tcp),
      udpAggregate: metrics.udp(udp),
    ),
  );
}
