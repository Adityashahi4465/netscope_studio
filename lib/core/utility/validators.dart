import 'package:fpdart/fpdart.dart';

import '../../constants/network_constants.dart';
import '../../modals/benchmark_config.dart';
import '../failure.dart';

class Validators {
  Validators._();

  /// Validates every field. Returns the first problem found.
  static Either<Failure, BenchmarkConfig> validateConfig(BenchmarkConfig c) {
    final String? error = _firstError(c);
    return error == null ? Right(c) : Left(Failure(error));
  }

  static String? _firstError(BenchmarkConfig c) {
    final String host = c.host.trim();
    if (host.isEmpty) return 'Host cannot be empty.';
    if (!_isLocalHost(host)) {
      return 'Only local hosts are supported: localhost or 127.0.0.1.';
    }

    final String? tcpPortError = portError(c.tcpPort, 'TCP port');
    if (tcpPortError != null) return tcpPortError;
    final String? udpPortError = portError(c.udpPort, 'UDP port');
    if (udpPortError != null) return udpPortError;

    if (c.tcpPayloadBytes < NetworkConstants.minTcpPayloadBytes ||
        c.tcpPayloadBytes > NetworkConstants.maxTcpPayloadBytes) {
      return 'TCP payload must be between 1 KB and 256 MB.';
    }
    if (c.udpDatagramSize < NetworkConstants.minUdpDatagramSize ||
        c.udpDatagramSize > NetworkConstants.maxUdpDatagramSize) {
      return 'UDP datagram size must be between '
          '${NetworkConstants.minUdpDatagramSize} and '
          '${NetworkConstants.maxUdpDatagramSize} bytes.';
    }
    if (c.packetCount < NetworkConstants.minPacketCount ||
        c.packetCount > NetworkConstants.maxPacketCount) {
      return 'Packet count must be between '
          '${NetworkConstants.minPacketCount} and '
          '${NetworkConstants.maxPacketCount}.';
    }
    if (c.repetitions < NetworkConstants.minRepetitions ||
        c.repetitions > NetworkConstants.maxRepetitions) {
      return 'Repetitions must be between '
          '${NetworkConstants.minRepetitions} and '
          '${NetworkConstants.maxRepetitions}.';
    }
    if (c.rttProbes < NetworkConstants.minRttProbes ||
        c.rttProbes > NetworkConstants.maxRttProbes) {
      return 'RTT probes must be between '
          '${NetworkConstants.minRttProbes} and '
          '${NetworkConstants.maxRttProbes}.';
    }
    if (c.timeoutMs < NetworkConstants.minTimeoutMs ||
        c.timeoutMs > NetworkConstants.maxTimeoutMs) {
      return 'Timeout must be between ${NetworkConstants.minTimeoutMs} and '
          '${NetworkConstants.maxTimeoutMs} ms.';
    }

    final s = c.simulation;
    if (!s.lossPercent.isFinite ||
        s.lossPercent < 0 ||
        s.lossPercent > NetworkConstants.maxLossPercent) {
      return 'Simulated loss must be between 0 and '
          '${NetworkConstants.maxLossPercent.toInt()}%.';
    }
    if (s.delayMs < 0 || s.delayMs > NetworkConstants.maxDelayMs) {
      return 'Added delay must be between 0 and '
          '${NetworkConstants.maxDelayMs} ms.';
    }
    if (s.jitterMs < 0 || s.jitterMs > NetworkConstants.maxJitterMs) {
      return 'Delay variation must be between 0 and '
          '${NetworkConstants.maxJitterMs} ms.';
    }
    if (s.jitterMs > s.delayMs) {
      return 'Delay variation cannot exceed the added delay.';
    }
    if (!s.rateLimitMbps.isFinite ||
        s.rateLimitMbps < 0 ||
        s.rateLimitMbps > NetworkConstants.maxRateLimitMbps) {
      return 'Rate limit must be between 0 (unlimited) and '
          '${NetworkConstants.maxRateLimitMbps.toInt()} Mbps.';
    }
    if (s.seed != null && (s.seed! < 0 || s.seed! > 0xffffffff)) {
      return 'Seed must be between 0 and 4294967295.';
    }
    final minimumBits = c.protocol.includesUdp ? c.udpDatagramSize * 8 : 8;
    if (s.hasRateLimit && minimumBits / s.rateLimitMbps > c.timeoutMs * 1000) {
      return 'Send-rate cap is too low for the operation timeout.';
    }
    return null;
  }

  static bool _isLocalHost(String host) =>
      host == 'localhost' || host == '127.0.0.1' || host == '::1';

  static String? portError(int port, String label) {
    if (port < NetworkConstants.minPort || port > NetworkConstants.maxPort) {
      return '$label must be between ${NetworkConstants.minPort} and '
          '${NetworkConstants.maxPort}.';
    }
    return null;
  }

  /// Parses an integer field; returns null if invalid. Use in form fields.
  static int? parseInt(String? text) => int.tryParse((text ?? '').trim());

  /// Parses a double field; returns null if invalid.
  static double? parseDouble(String? text) =>
      double.tryParse((text ?? '').trim());
}
