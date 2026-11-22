import 'packet_record.dart';

/// Measured results of a single UDP run (RTT phase + bulk phase).
class UdpResult {
  final int runIndex;

  // RTT phase
  final List<double> rttSamplesMs;
  final int probeTimeouts;

  // Bulk phase (counts come from the server's audit summary)
  final int packetsSent;
  final int uniqueReceived;
  final int duplicates;
  final int outOfOrder;
  final int droppedBySimulation;
  final int bytesReceived;
  final double transferSeconds;
  final double goodputMbps;
  final List<PacketRecord> packetRecords;

  const UdpResult({
    required this.runIndex,
    this.rttSamplesMs = const <double>[],
    this.probeTimeouts = 0,
    this.packetsSent = 0,
    this.uniqueReceived = 0,
    this.duplicates = 0,
    this.outOfOrder = 0,
    this.droppedBySimulation = 0,
    this.bytesReceived = 0,
    this.transferSeconds = 0,
    this.goodputMbps = 0,
    this.packetRecords = const <PacketRecord>[],
  });

  /// Datagrams sent but never uniquely received.
  int get lostPackets => (packetsSent - uniqueReceived).clamp(0, packetsSent);

  /// Lost datagrams not explained by the simulated drop policy.
  int get unexplainedLoss =>
      (lostPackets - droppedBySimulation).clamp(0, packetsSent);

  Map<String, dynamic> toMap() => <String, dynamic>{
    'runIndex': runIndex,
    'rttSamplesMs': rttSamplesMs,
    'probeTimeouts': probeTimeouts,
    'packetsSent': packetsSent,
    'uniqueReceived': uniqueReceived,
    'duplicates': duplicates,
    'outOfOrder': outOfOrder,
    'droppedBySimulation': droppedBySimulation,
    'bytesReceived': bytesReceived,
    'transferSeconds': transferSeconds,
    'goodputMbps': goodputMbps,
    'packetRecords': packetRecords.map((PacketRecord p) => p.toMap()).toList(),
  };

  factory UdpResult.fromMap(Map<String, dynamic> map) => UdpResult(
    runIndex: (map['runIndex'] as num).toInt(),
    rttSamplesMs: (map['rttSamplesMs'] as List)
        .map((Object? e) => (e! as num).toDouble())
        .toList(growable: false),
    probeTimeouts: (map['probeTimeouts'] as num).toInt(),
    packetsSent: (map['packetsSent'] as num).toInt(),
    uniqueReceived: (map['uniqueReceived'] as num).toInt(),
    duplicates: (map['duplicates'] as num).toInt(),
    outOfOrder: (map['outOfOrder'] as num).toInt(),
    droppedBySimulation: (map['droppedBySimulation'] as num).toInt(),
    bytesReceived: (map['bytesReceived'] as num).toInt(),
    transferSeconds: (map['transferSeconds'] as num).toDouble(),
    goodputMbps: (map['goodputMbps'] as num).toDouble(),
    packetRecords: (map['packetRecords'] as List)
        .map(
          (Object? e) =>
              PacketRecord.fromMap(Map<String, dynamic>.from(e! as Map)),
        )
        .toList(growable: false),
  );
}
