import '../../core/type_defs.dart';
import 'packet_protocol.dart';

/// Optional request/response extension hosted by the existing TCP listener.
abstract interface class TcpControlHandler {
  bool accepts(Packet request);
  FutureEither<List<Packet>> handle(Packet request);
}
