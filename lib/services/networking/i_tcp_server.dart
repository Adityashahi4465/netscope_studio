import '../../constants/network_constants.dart';
import '../../core/type_defs.dart';

abstract interface class ITcpServer {
  int? get boundPort;

  /// Binds IPv4 loopback only. Port zero asks the OS for an ephemeral port.
  FutureEither<int> start({
    int port = NetworkConstants.defaultTcpPort,
    Duration idleTimeout = const Duration(seconds: 30),
  });

  FutureEitherVoid stop();
}
