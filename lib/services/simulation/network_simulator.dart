import 'dart:math';

import '../../constants/network_constants.dart';
import '../../core/enums/simulation_type.dart';
import '../../modals/simulation_config.dart';
import '../networking/delay_policy.dart';
import '../networking/udp_drop_policy.dart';

/// Impairment is applied inside the application. Only RTT echoes are delayed.
class NetworkSimulator {
  const NetworkSimulator();

  SimulationConfig preset(SimulationType type) => switch (type) {
    SimulationType.normal => SimulationConfig.none,
    SimulationType.udpLoss => SimulationConfig(type: type, lossPercent: 25),
    SimulationType.latency => SimulationConfig(type: type, delayMs: 20),
    SimulationType.jitter => SimulationConfig(
      type: type,
      delayMs: 20,
      jitterMs: 10,
    ),
    SimulationType.bandwidth => SimulationConfig(type: type, rateLimitMbps: 10),
  };

  DelayPolicy delay(SimulationConfig config) => config.hasDelay
      ? JitterDelayPolicy(
          delay: Duration(milliseconds: config.delayMs),
          jitter: Duration(milliseconds: config.jitterMs),
          seed: config.seed,
        )
      : const NoDelayPolicy();

  UdpDropPolicy drop(SimulationConfig config) => UdpDropPolicy(
    probability: config.lossPercent / 100,
    seed: config.seed ?? Random().nextInt(0x100000000),
  );

  SendRatePacer pacer(SimulationConfig config) =>
      SendRatePacer(config.rateLimitMbps);
}

/// Absolute payload-byte deadlines avoid cumulative timer drift. TCP splits
/// writes into roughly 10 ms of traffic, up to the existing frame size.
class SendRatePacer {
  final double mbps;
  const SendRatePacer(this.mbps);

  int get chunkSize => mbps <= 0
      ? NetworkConstants.tcpChunkSize
      : (mbps * 1250).ceil().clamp(1, NetworkConstants.tcpChunkSize);

  Duration deadline(int bytes) => mbps <= 0
      ? Duration.zero
      : Duration(microseconds: (bytes * 8 / mbps).ceil());

  Duration remaining(int bytes, Duration elapsed) {
    final wait = deadline(bytes) - elapsed;
    return wait.isNegative ? Duration.zero : wait;
  }
}
