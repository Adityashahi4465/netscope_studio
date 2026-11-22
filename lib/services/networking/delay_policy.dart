import 'dart:math';

/// Simulated application echo delay, not network loss or TCP congestion control.
abstract interface class DelayPolicy {
  Duration delayForProbe(int sequence);
}

class NoDelayPolicy implements DelayPolicy {
  const NoDelayPolicy();

  @override
  Duration delayForProbe(int sequence) => Duration.zero;
}

/// Uniform +/- jitter around a base delay, clamped at zero. The server bounds
/// the resulting delay by its operation timeout. A seed makes simulation repeatable.
class JitterDelayPolicy implements DelayPolicy {
  final Duration delay;
  final Duration jitter;
  final Random _random;

  JitterDelayPolicy({
    this.delay = Duration.zero,
    this.jitter = Duration.zero,
    int? seed,
  }) : _random = Random(seed);

  @override
  Duration delayForProbe(int sequence) {
    final spread = jitter.inMicroseconds.abs();
    final offset = spread == 0 ? 0 : _random.nextInt(spread * 2 + 1) - spread;
    return Duration(microseconds: max(0, delay.inMicroseconds + offset));
  }
}
