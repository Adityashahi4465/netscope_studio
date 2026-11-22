import 'dart:async';
import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../constants/network_constants.dart';
import '../../core/type_defs.dart';
import 'delay_policy.dart';
import 'frame_buffer.dart';
import 'i_tcp_server.dart';
import 'network_failure.dart';
import 'packet_protocol.dart';
import 'tcp_control_handler.dart';

class TcpServer implements ITcpServer {
  final DelayPolicy delayPolicy;
  final TcpControlHandler? controlHandler;
  final PacketProtocol _protocol = const PacketProtocol();
  final Map<Socket, Future<void>> _clients = <Socket, Future<void>>{};
  ServerSocket? _server;
  StreamSubscription<Socket>? _subscription;
  Completer<void>? _starting;
  Completer<void>? _shutdown;
  bool _stopping = false;
  Duration _timeout = const Duration(seconds: 30);

  TcpServer({this.delayPolicy = const NoDelayPolicy(), this.controlHandler});

  @override
  int? get boundPort => _server?.port;

  @override
  FutureEither<int> start({
    int port = NetworkConstants.defaultTcpPort,
    Duration idleTimeout = const Duration(seconds: 30),
  }) async {
    if (_server != null || _starting != null || _stopping) {
      return left(
        const NetworkFailure(
          NetworkFailureCode.busy,
          'TCP server is already running or changing state.',
        ),
      );
    }
    if (port < 0 || port > 65535 || idleTimeout <= Duration.zero) {
      return left(
        const NetworkFailure(
          NetworkFailureCode.invalidInput,
          'Invalid server port or timeout.',
        ),
      );
    }
    final starting = Completer<void>();
    _starting = starting;
    try {
      _timeout = idleTimeout;
      final shutdown = Completer<void>();
      _shutdown = shutdown;
      final server = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
        shared: false,
      );
      _server = server;
      _subscription = server.listen(
        (socket) {
          // _serve catches every per-client error; one peer cannot stop others.
          final task = _serve(socket, shutdown.future);
          _clients[socket] = task;
          unawaited(task.then((_) => _clients.remove(socket)));
        },
        onError: (Object error) {
          unawaited(stop());
        },
      );
      return right(server.port);
    } on Object catch (error) {
      return left(NetworkFailure.from(error, binding: true));
    } finally {
      _starting = null;
      starting.complete();
    }
  }

  Future<void> _serve(Socket socket, Future<void> shutdown) async {
    final buffer = FrameBuffer();
    int? experiment;
    var expected = 0;
    var received = 0;
    var nextChunk = 0;
    var nextProbe = 0;
    var completed = false;
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
      await for (final bytes in socket.timeout(_timeout)) {
        final packets = buffer
            .add(bytes)
            .fold((failure) => throw failure, (packets) => packets);
        for (final packet in packets) {
          if (experiment == null) {
            final handler = controlHandler;
            if (handler != null && handler.accepts(packet)) {
              final responses = (await handler.handle(packet))
                  .fold((failure) => throw failure, (packets) => packets);
              for (final response in responses) {
                await _send(socket, response);
              }
              return;
            }
            if (packet.type != MessageType.handshake ||
                packet.sequence != 0 ||
                packet.total <= 0 ||
                packet.total > NetworkConstants.maxTcpPayloadBytes) {
              throw _invalid('Expected handshake with a bounded byte count.');
            }
            experiment = packet.experimentId;
            expected = packet.total;
            await _send(
              socket,
              Packet(type: MessageType.ack, experimentId: experiment),
            );
            continue;
          }
          if (packet.experimentId != experiment || packet.total != expected) {
            throw _invalid('Experiment or expected byte count changed.');
          }
          switch (packet.type) {
            case MessageType.rttProbe:
              if (received != 0 ||
                  completed ||
                  packet.sequence != nextProbe ||
                  nextProbe >= NetworkConstants.maxRttProbes) {
                throw _invalid('RTT probes must precede bulk data in order.');
              }
              nextProbe++;
              final delay = delayPolicy.delayForProbe(packet.sequence);
              if (delay < Duration.zero || delay > _timeout) {
                throw _invalid('Simulated echo delay exceeds server timeout.');
              }
              await _delay(delay, shutdown);
              await _send(
                socket,
                Packet(
                  type: MessageType.rttEcho,
                  experimentId: experiment,
                  sequence: packet.sequence,
                  total: expected,
                  timestampUs: packet.timestampUs,
                ),
              );
            case MessageType.dataChunk:
              if (completed ||
                  packet.sequence != nextChunk ||
                  received + packet.payload.length > expected) {
                throw _invalid('Invalid bulk sequence or excess payload.');
              }
              nextChunk++;
              received += packet.payload.length;
              if (received == expected) {
                completed = true;
                for (final type in <MessageType>[
                  MessageType.ack,
                  MessageType.summary,
                ]) {
                  await _send(
                    socket,
                    Packet(
                      type: type,
                      experimentId: experiment,
                      sequence: nextChunk,
                      total: received,
                    ),
                  );
                }
              }
            case MessageType.close:
              if (!completed) throw _invalid('Close before bulk completion.');
              return;
            case MessageType.handshake:
            case MessageType.rttEcho:
            case MessageType.ack:
            case MessageType.summary:
              throw _invalid('Unexpected client message.');
          }
        }
      }
      buffer.finish().fold((failure) => throw failure, (_) {});
    } on Object {
      // Invalid, timed-out and abruptly disconnected peers are isolated here.
      // The client detects an absent acknowledgement as a fallible run result.
    } finally {
      socket.destroy();
    }
  }

  Future<void> _send(Socket socket, Packet packet) async {
    socket.add(
      _protocol
          .encode(packet)
          .fold((failure) => throw failure, (bytes) => bytes),
    );
    await socket.flush().timeout(_timeout);
  }

  Future<void> _delay(Duration duration, Future<void> shutdown) async {
    if (duration == Duration.zero) return;
    final done = Completer<void>();
    final timer = Timer(duration, done.complete);
    try {
      await Future.any<void>(<Future<void>>[done.future, shutdown]);
    } finally {
      timer.cancel();
    }
  }

  NetworkFailure _invalid(String message) =>
      NetworkFailure(NetworkFailureCode.malformedPacket, message);

  @override
  FutureEitherVoid stop() async {
    if (_stopping) {
      return left(
        const NetworkFailure(
          NetworkFailureCode.busy,
          'TCP server is already stopping.',
        ),
      );
    }
    _stopping = true;
    try {
      await _starting?.future;
      _shutdown?.complete();
      _shutdown = null;
      final tasks = _clients.values.toList(growable: false);
      for (final socket in _clients.keys.toList(growable: false)) {
        socket.destroy();
      }
      await _subscription?.cancel();
      await _server?.close();
      await Future.wait(tasks);
      return right(null);
    } on Object catch (error) {
      return left(NetworkFailure.from(error));
    } finally {
      _subscription = null;
      _server = null;
      _clients.clear();
      _stopping = false;
    }
  }
}
