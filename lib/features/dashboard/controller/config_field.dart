import '../../../modals/benchmark_config.dart';

enum ConfigField {
  tcpPayload('TCP payload (bytes)'),
  datagram('UDP datagram (bytes)'),
  packets('UDP datagrams'),
  repetitions('Repetitions'),
  probes('RTT probes'),
  timeout('Timeout (ms)'),
  tcpPort('TCP port'),
  udpPort('UDP port'),
  loss('Simulated UDP loss (%)'),
  delay('Echo delay (ms)'),
  jitter('Delay variation (± ms)'),
  rate('Send-rate cap (Mbps)'),
  seed('Random seed (optional)');

  final String label;
  const ConfigField(this.label);

  String text(BenchmarkConfig c) => switch (this) {
    tcpPayload => c.tcpPayloadBytes,
    datagram => c.udpDatagramSize,
    packets => c.packetCount,
    repetitions => c.repetitions,
    probes => c.rttProbes,
    timeout => c.timeoutMs,
    tcpPort => c.tcpPort,
    udpPort => c.udpPort,
    loss => c.simulation.lossPercent,
    delay => c.simulation.delayMs,
    jitter => c.simulation.jitterMs,
    rate => c.simulation.rateLimitMbps,
    seed => c.simulation.seed ?? '',
  }.toString();

  BenchmarkConfig? apply(BenchmarkConfig c, String raw) {
    final input = raw.trim();
    final sim = c.simulation;
    if (this == seed && input.isEmpty) {
      return c.copyWith(simulation: sim.copyWith(clearSeed: true));
    }
    if (this == loss || this == rate) {
      final n = double.tryParse(input);
      if (n == null || !n.isFinite) return null;
      return c.copyWith(
        simulation: this == loss
            ? sim.copyWith(lossPercent: n)
            : sim.copyWith(rateLimitMbps: n),
      );
    }
    final n = int.tryParse(input);
    if (n == null) return null;
    return switch (this) {
      tcpPayload => c.copyWith(tcpPayloadBytes: n),
      datagram => c.copyWith(udpDatagramSize: n),
      packets => c.copyWith(packetCount: n),
      repetitions => c.copyWith(repetitions: n),
      probes => c.copyWith(rttProbes: n),
      timeout => c.copyWith(timeoutMs: n),
      tcpPort => c.copyWith(tcpPort: n),
      udpPort => c.copyWith(udpPort: n),
      seed => c.copyWith(simulation: sim.copyWith(seed: n)),
      delay => c.copyWith(simulation: sim.copyWith(delayMs: n)),
      jitter => c.copyWith(simulation: sim.copyWith(jitterMs: n)),
      _ => c,
    };
  }
}
