enum SimulationType {
  normal('Normal network'),
  udpLoss('UDP packet loss'),
  latency('Added latency'),
  jitter('Added jitter'),
  bandwidth('Send-rate limit');

  const SimulationType(this.label);

  final String label;

  static SimulationType fromName(String? name) =>
      SimulationType.values.firstWhere(
        (SimulationType e) => e.name == name,
        orElse: () => SimulationType.normal,
      );
}
