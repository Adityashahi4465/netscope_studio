enum PacketStatus {
  delivered,
  droppedBySimulation,
  timedOut,
  duplicate,
  missing;

  static PacketStatus fromName(String? name) => PacketStatus.values.firstWhere(
    (PacketStatus e) => e.name == name,
    orElse: () => PacketStatus.missing,
  );
}

/// One UDP datagram's observed fate. Kept per sequence number.
class PacketRecord {
  final int sequence;
  final PacketStatus status;
  final int sizeBytes;

  /// Microseconds since the run started (monotonic Stopwatch).
  final int sentAtUs;

  const PacketRecord({
    required this.sequence,
    required this.status,
    required this.sizeBytes,
    this.sentAtUs = 0,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'sequence': sequence,
    'status': status.name,
    'sizeBytes': sizeBytes,
    'sentAtUs': sentAtUs,
  };

  factory PacketRecord.fromMap(Map<String, dynamic> map) => PacketRecord(
    sequence: (map['sequence'] as num).toInt(),
    status: PacketStatus.fromName(map['status'] as String?),
    sizeBytes: (map['sizeBytes'] as num).toInt(),
    sentAtUs: (map['sentAtUs'] as num? ?? 0).toInt(),
  );
}
