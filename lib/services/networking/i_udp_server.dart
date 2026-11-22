import '../../constants/network_constants.dart';
import '../../core/type_defs.dart';
import 'tcp_control_handler.dart';
import 'udp_audit.dart';

/// Pass this service as TcpServer(controlHandler: udpServer) to host control
/// transactions on the same listener used for TCP benchmark connections.
abstract interface class IUdpServer implements TcpControlHandler {
  int? get boundPort;
  int get rejectedDatagrams;

  FutureEither<int> start({
    int port = NetworkConstants.defaultUdpPort,
    Duration sessionTimeout = const Duration(minutes: 2),
  });

  FutureEither<UdpAudit> audit(
    int experimentId, {
    Duration collectionWindow = const Duration(milliseconds: 100),
  });

  FutureEitherVoid stop();
}
