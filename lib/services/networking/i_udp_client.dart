import '../../core/type_defs.dart';
import '../../modals/benchmark_config.dart';
import '../../modals/udp_result.dart';

abstract interface class IUdpClient {
  /// udpDatagramSize includes the 36-byte application header. Default pacing
  /// is one datagram/ms. rateLimitMbps, when set, is an application send cap.
  /// The measured bulk interval includes the final collection/control exchange.
  FutureEither<UdpResult> run(
    BenchmarkConfig config, {
    int experimentId = 1,
    int runIndex = 0,
    Duration packetInterval = const Duration(milliseconds: 1),
    Duration collectionWindow = const Duration(milliseconds: 100),
  });

  FutureEitherVoid cancel();
}
