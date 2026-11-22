import '../constants/network_constants.dart';
import '../core/enums/protocol_type.dart';
import '../core/enums/simulation_type.dart';
import 'simulation_config.dart';

enum BenchmarkPreset {
  quick('Quick Benchmark'),
  standard('Standard Comparison'),
  highThroughput('High-Throughput Test'),
  latencyJitter('Latency & Jitter Test'),
  udpLoss('UDP Packet Loss Test'),
  custom('Custom Configuration');

  const BenchmarkPreset(this.label);

  final String label;
}

class BenchmarkConfig {
  final ProtocolType protocol;
  final String host;
  final int tcpPort;
  final int udpPort;

  /// Total application bytes for the TCP bulk phase.
  final int tcpPayloadBytes;
  final int udpDatagramSize;

  /// Datagrams sent in the UDP bulk phase.
  final int packetCount;
  final int repetitions;
  final int rttProbes;
  final int timeoutMs;
  final SimulationConfig simulation;

  const BenchmarkConfig({
    this.protocol = ProtocolType.both,
    this.host = NetworkConstants.defaultHost,
    this.tcpPort = NetworkConstants.defaultTcpPort,
    this.udpPort = NetworkConstants.defaultUdpPort,
    this.tcpPayloadBytes = 1024 * 1024,
    this.udpDatagramSize = NetworkConstants.defaultUdpDatagramSize,
    this.packetCount = 500,
    this.repetitions = 1,
    this.rttProbes = 20,
    this.timeoutMs = NetworkConstants.defaultTimeoutMs,
    this.simulation = SimulationConfig.none,
  });

  int get udpPayloadBytesTotal => udpDatagramSize * packetCount;

  factory BenchmarkConfig.fromPreset(BenchmarkPreset preset) {
    switch (preset) {
      case BenchmarkPreset.quick:
      case BenchmarkPreset.custom:
        return const BenchmarkConfig();
      case BenchmarkPreset.standard:
        return const BenchmarkConfig(
          tcpPayloadBytes: 5 * 1024 * 1024,
          packetCount: 1000,
          repetitions: 3,
          rttProbes: 50,
        );
      case BenchmarkPreset.highThroughput:
        return const BenchmarkConfig(
          tcpPayloadBytes: 50 * 1024 * 1024,
          udpDatagramSize: 1400,
          packetCount: 20000,
          repetitions: 3,
          rttProbes: 20,
        );
      case BenchmarkPreset.latencyJitter:
        return const BenchmarkConfig(
          packetCount: 200,
          repetitions: 3,
          rttProbes: 200,
          simulation: SimulationConfig(
            type: SimulationType.jitter,
            delayMs: 20,
            jitterMs: 10,
          ),
        );
      case BenchmarkPreset.udpLoss:
        return const BenchmarkConfig(
          packetCount: 1000,
          repetitions: 3,
          simulation: SimulationConfig(
            type: SimulationType.udpLoss,
            lossPercent: 25,
          ),
        );
    }
  }

  BenchmarkConfig copyWith({
    ProtocolType? protocol,
    String? host,
    int? tcpPort,
    int? udpPort,
    int? tcpPayloadBytes,
    int? udpDatagramSize,
    int? packetCount,
    int? repetitions,
    int? rttProbes,
    int? timeoutMs,
    SimulationConfig? simulation,
  }) {
    return BenchmarkConfig(
      protocol: protocol ?? this.protocol,
      host: host ?? this.host,
      tcpPort: tcpPort ?? this.tcpPort,
      udpPort: udpPort ?? this.udpPort,
      tcpPayloadBytes: tcpPayloadBytes ?? this.tcpPayloadBytes,
      udpDatagramSize: udpDatagramSize ?? this.udpDatagramSize,
      packetCount: packetCount ?? this.packetCount,
      repetitions: repetitions ?? this.repetitions,
      rttProbes: rttProbes ?? this.rttProbes,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      simulation: simulation ?? this.simulation,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'protocol': protocol.name,
    'host': host,
    'tcpPort': tcpPort,
    'udpPort': udpPort,
    'tcpPayloadBytes': tcpPayloadBytes,
    'udpDatagramSize': udpDatagramSize,
    'packetCount': packetCount,
    'repetitions': repetitions,
    'rttProbes': rttProbes,
    'timeoutMs': timeoutMs,
    'simulation': simulation.toMap(),
  };

  factory BenchmarkConfig.fromMap(Map<String, dynamic> map) {
    return BenchmarkConfig(
      protocol: ProtocolType.fromName(map['protocol'] as String?),
      host: map['host'] as String? ?? NetworkConstants.defaultHost,
      tcpPort: (map['tcpPort'] as num).toInt(),
      udpPort: (map['udpPort'] as num).toInt(),
      tcpPayloadBytes: (map['tcpPayloadBytes'] as num).toInt(),
      udpDatagramSize: (map['udpDatagramSize'] as num).toInt(),
      packetCount: (map['packetCount'] as num).toInt(),
      repetitions: (map['repetitions'] as num).toInt(),
      rttProbes: (map['rttProbes'] as num).toInt(),
      timeoutMs: (map['timeoutMs'] as num).toInt(),
      simulation: SimulationConfig.fromMap(
        Map<String, dynamic>.from(map['simulation'] as Map),
      ),
    );
  }
}
