import '../core/enums/simulation_type.dart';

/// Application-level impairment settings (simulated, not measured).
class SimulationConfig {
  final SimulationType type;
  final double lossPercent;
  final int delayMs;
  final int jitterMs;

  /// 0 means unlimited.
  final double rateLimitMbps;
  final int? seed;

  const SimulationConfig({
    this.type = SimulationType.normal,
    this.lossPercent = 0,
    this.delayMs = 0,
    this.jitterMs = 0,
    this.rateLimitMbps = 0,
    this.seed,
  });

  static const SimulationConfig none = SimulationConfig();

  bool get hasDelay => delayMs > 0 || jitterMs > 0;
  bool get hasRateLimit => rateLimitMbps > 0;
  bool get hasLoss => lossPercent > 0;

  SimulationConfig copyWith({
    SimulationType? type,
    double? lossPercent,
    int? delayMs,
    int? jitterMs,
    double? rateLimitMbps,
    int? seed,
    bool clearSeed = false,
  }) {
    return SimulationConfig(
      type: type ?? this.type,
      lossPercent: lossPercent ?? this.lossPercent,
      delayMs: delayMs ?? this.delayMs,
      jitterMs: jitterMs ?? this.jitterMs,
      rateLimitMbps: rateLimitMbps ?? this.rateLimitMbps,
      seed: clearSeed ? null : (seed ?? this.seed),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'type': type.name,
    'lossPercent': lossPercent,
    'delayMs': delayMs,
    'jitterMs': jitterMs,
    'rateLimitMbps': rateLimitMbps,
    'seed': seed,
  };

  factory SimulationConfig.fromMap(Map<String, dynamic> map) {
    return SimulationConfig(
      type: SimulationType.fromName(map['type'] as String?),
      lossPercent: (map['lossPercent'] as num? ?? 0).toDouble(),
      delayMs: (map['delayMs'] as num? ?? 0).toInt(),
      jitterMs: (map['jitterMs'] as num? ?? 0).toInt(),
      rateLimitMbps: (map['rateLimitMbps'] as num? ?? 0).toDouble(),
      seed: (map['seed'] as num?)?.toInt(),
    );
  }
}
