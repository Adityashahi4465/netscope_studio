import '../../core/type_defs.dart';
import '../../modals/benchmark_config.dart';
import '../../modals/tcp_result.dart';

abstract interface class ITcpClient {
  /// One connection, sequential RTT probes, then a separate bulk phase.
  /// Simulation settings are applied by the server's DelayPolicy in this phase.
  FutureEither<TcpResult> run(
    BenchmarkConfig config, {
    int experimentId = 1,
    int runIndex = 0,
  });

  FutureEitherVoid cancel();
}
