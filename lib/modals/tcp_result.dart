/// Measured results of a single TCP run (RTT phase + bulk phase).
class TcpResult {
  final int runIndex;

  // RTT phase
  final List<double> rttSamplesMs;
  final int probeTimeouts;

  // Bulk phase
  final int bytesSent;
  final int bytesAcked;
  final double transferSeconds;
  final double throughputMbps;
  final bool completed;
  final String? failureMessage;

  const TcpResult({
    required this.runIndex,
    this.rttSamplesMs = const <double>[],
    this.probeTimeouts = 0,
    this.bytesSent = 0,
    this.bytesAcked = 0,
    this.transferSeconds = 0,
    this.throughputMbps = 0,
    this.completed = false,
    this.failureMessage,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'runIndex': runIndex,
    'rttSamplesMs': rttSamplesMs,
    'probeTimeouts': probeTimeouts,
    'bytesSent': bytesSent,
    'bytesAcked': bytesAcked,
    'transferSeconds': transferSeconds,
    'throughputMbps': throughputMbps,
    'completed': completed,
    'failureMessage': failureMessage,
  };

  factory TcpResult.fromMap(Map<String, dynamic> map) => TcpResult(
    runIndex: (map['runIndex'] as num).toInt(),
    rttSamplesMs: (map['rttSamplesMs'] as List)
        .map((Object? e) => (e! as num).toDouble())
        .toList(growable: false),
    probeTimeouts: (map['probeTimeouts'] as num).toInt(),
    bytesSent: (map['bytesSent'] as num).toInt(),
    bytesAcked: (map['bytesAcked'] as num).toInt(),
    transferSeconds: (map['transferSeconds'] as num).toDouble(),
    throughputMbps: (map['throughputMbps'] as num).toDouble(),
    completed: map['completed'] as bool,
    failureMessage: map['failureMessage'] as String?,
  );
}
