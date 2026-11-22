import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../core/failure.dart';
import '../../core/type_defs.dart';
import 'frame_buffer.dart';
import 'network_failure.dart';
import 'packet_protocol.dart';

/// UDP control uses a reserved first-frame sequence, without changing the v1
/// packet layout. Replies are bounded dataChunk frames plus a final summary.
class UdpControlCodec {
  static const int marker = PacketProtocol.maxUnsigned32;
  static const int maxResponseBytes = 256 * 1024;

  static bool accepts(Packet packet) =>
      packet.type == MessageType.dataChunk && packet.sequence == marker;

  static Either<Failure, Map<String, Object?>> decode(Uint8List bytes) {
    try {
      final Object? decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Control body must be an object.');
      }
      return right(decoded);
    } on Object catch (error) {
      return left(
        NetworkFailure(
          NetworkFailureCode.malformedPacket,
          'Invalid UDP control body.',
          cause: error,
        ),
      );
    }
  }

  static Either<Failure, List<Packet>> response(
    int experimentId,
    Map<String, Object?> body,
  ) {
    try {
      final bytes = utf8.encode(jsonEncode(body));
      if (bytes.length > maxResponseBytes) {
        throw const FormatException('Control response exceeds size limit.');
      }
      final packets = <Packet>[];
      for (
        var offset = 0;
        offset < bytes.length;
        offset += PacketProtocol.maxPayloadLength
      ) {
        packets.add(
          Packet(
            type: MessageType.dataChunk,
            experimentId: experimentId,
            sequence: packets.length,
            total: bytes.length,
            payload: bytes.sublist(
              offset,
              min(bytes.length, offset + PacketProtocol.maxPayloadLength),
            ),
          ),
        );
      }
      packets.add(
        Packet(
          type: MessageType.summary,
          experimentId: experimentId,
          sequence: packets.length,
          total: bytes.length,
        ),
      );
      return right(List<Packet>.unmodifiable(packets));
    } on Object catch (error) {
      return left(
        NetworkFailure(
          NetworkFailureCode.malformedPacket,
          'Cannot encode UDP control response.',
          cause: error,
        ),
      );
    }
  }
}

class UdpControlChannel {
  Socket? _socket;
  ConnectionTask<Socket>? _connecting;
  bool _busy = false;
  bool _cancelled = false;

  FutureEither<Map<String, Object?>> request({
    required int port,
    required int experimentId,
    required Map<String, Object?> body,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (_busy) {
      return left(
        const NetworkFailure(
          NetworkFailureCode.busy,
          'UDP control transaction is already active.',
        ),
      );
    }
    if (port <= 0 ||
        port > 65535 ||
        experimentId <= 0 ||
        experimentId > PacketProtocol.maxUnsigned32 ||
        timeout <= Duration.zero) {
      return left(
        const NetworkFailure(
          NetworkFailureCode.invalidInput,
          'Invalid UDP control connection.',
        ),
      );
    }
    _busy = true;
    _cancelled = false;
    final clock = Stopwatch()..start();
    StreamIterator<Packet>? incoming;
    Duration remaining() {
      if (_cancelled) {
        throw const NetworkFailure(
          NetworkFailureCode.cancelled,
          'UDP control transaction cancelled.',
        );
      }
      final duration = timeout - clock.elapsed;
      if (duration <= Duration.zero) {
        throw TimeoutException('UDP control timed out.');
      }
      return duration;
    }

    try {
      const protocol = PacketProtocol();
      final request = protocol
          .encode(
            Packet(
              type: MessageType.dataChunk,
              experimentId: experimentId,
              sequence: UdpControlCodec.marker,
              payload: utf8.encode(jsonEncode(body)),
            ),
          )
          .fold((failure) => throw failure, (bytes) => bytes);
      final task = await Socket.startConnect(
        InternetAddress.loopbackIPv4,
        port,
      );
      _connecting = task;
      if (_cancelled) task.cancel();
      final socket = await task.socket.timeout(
        remaining(),
        onTimeout: () {
          task.cancel();
          throw TimeoutException('UDP control connect timed out.');
        },
      );
      _socket = socket;
      _connecting = null;
      remaining();
      socket.setOption(SocketOption.tcpNoDelay, true);
      incoming = StreamIterator<Packet>(_frames(socket));
      socket.add(request);
      await socket.flush().timeout(remaining());
      final response = BytesBuilder(copy: false);
      var sequence = 0;
      int? total;
      while (await incoming.moveNext().timeout(remaining())) {
        final packet = incoming.current;
        if (packet.experimentId != experimentId ||
            packet.sequence != sequence ||
            packet.total <= 0 ||
            packet.total > UdpControlCodec.maxResponseBytes ||
            (total != null && total != packet.total)) {
          throw const NetworkFailure(
            NetworkFailureCode.malformedPacket,
            'Invalid UDP control frame.',
          );
        }
        total = packet.total;
        if (packet.type == MessageType.summary) {
          if (response.length != total) {
            throw const NetworkFailure(
              NetworkFailureCode.byteCountMismatch,
              'Incomplete UDP control response.',
            );
          }
          final map = UdpControlCodec.decode(response.takeBytes())
              .fold((failure) => throw failure, (map) => map);
          if (map['ok'] != true) {
            final codeName = map['code'];
            final code = NetworkFailureCode.values.firstWhere(
              (value) => value.name == codeName,
              orElse: () => NetworkFailureCode.io,
            );
            throw NetworkFailure(
              code,
              map['message'] is String
                  ? map['message']! as String
                  : 'UDP control rejected.',
            );
          }
          return right(map);
        }
        if (packet.type != MessageType.dataChunk ||
            response.length + packet.payload.length > total) {
          throw const NetworkFailure(
            NetworkFailureCode.malformedPacket,
            'Unexpected UDP control payload.',
          );
        }
        response.add(packet.payload);
        sequence++;
      }
      throw const NetworkFailure(
        NetworkFailureCode.disconnected,
        'TCP control closed before its summary.',
      );
    } on Object catch (error) {
      return left(
        _cancelled
            ? const NetworkFailure(
                NetworkFailureCode.cancelled,
                'UDP control transaction cancelled.',
              )
            : NetworkFailure.from(error),
      );
    } finally {
      clock.stop();
      _connecting?.cancel();
      _connecting = null;
      _socket?.destroy();
      _socket = null;
      try {
        await incoming?.cancel();
      } on Object {
        // The transaction's error has already been converted into a Failure.
      }
      _busy = false;
    }
  }

  Stream<Packet> _frames(Socket socket) async* {
    final buffer = FrameBuffer();
    await for (final bytes in socket) {
      for (final packet
          in buffer
              .add(bytes)
              .fold((failure) => throw failure, (packets) => packets)) {
        yield packet;
      }
    }
    buffer.finish().fold((failure) => throw failure, (_) {});
  }

  FutureEitherVoid cancel() async {
    _cancelled = true;
    _connecting?.cancel();
    _socket?.destroy();
    return right(null);
  }
}
