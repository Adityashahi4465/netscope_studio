import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../constants/network_constants.dart';
import '../../core/type_defs.dart';
import '../../modals/benchmark_config.dart';
import '../../modals/tcp_result.dart';
import 'frame_buffer.dart';
import 'i_tcp_client.dart';
import 'network_failure.dart';
import 'packet_protocol.dart';

class TcpClient implements ITcpClient {
  final PacketProtocol _protocol = const PacketProtocol();
  Socket? _socket;
  ConnectionTask<Socket>? _connecting;
  bool _running = false;
  bool _cancelled = false;

  @override
  FutureEither<TcpResult> run(
    BenchmarkConfig config, {
    int experimentId = 1,
    int runIndex = 0,
  }) async {
    if (_running) {
      return left(
        const NetworkFailure(
          NetworkFailureCode.busy,
          'This TCP client already has an active run.',
        ),
      );
    }
    if (config.host != NetworkConstants.defaultHost ||
        config.tcpPort <= 0 ||
        config.tcpPort > 65535 ||
        config.tcpPayloadBytes <= 0 ||
        config.tcpPayloadBytes > NetworkConstants.maxTcpPayloadBytes ||
        config.rttProbes < 0 ||
        config.rttProbes > NetworkConstants.maxRttProbes ||
        config.timeoutMs <= 0 ||
        experimentId <= 0 ||
        experimentId > PacketProtocol.maxUnsigned32 ||
        runIndex < 0) {
      return left(
        const NetworkFailure(
          NetworkFailureCode.invalidInput,
          'Invalid loopback TCP run configuration.',
        ),
      );
    }
    _running = true;
    _cancelled = false;
    final timeout = Duration(milliseconds: config.timeoutMs);
    final clock = Stopwatch()..start();
    StreamIterator<Packet>? incoming;
    try {
      final task = await Socket.startConnect(
        InternetAddress.loopbackIPv4,
        config.tcpPort,
      );
      _connecting = task;
      // Always observe task.socket, including cancellation during startConnect.
      if (_cancelled) task.cancel();
      final socket = await task.socket.timeout(
        timeout,
        onTimeout: () {
          task.cancel();
          throw TimeoutException('TCP connect timed out.');
        },
      );
      _socket = socket;
      _connecting = null;
      _checkCancelled();
      socket.setOption(SocketOption.tcpNoDelay, true);
      incoming = StreamIterator<Packet>(_frames(socket));
      await _send(
        socket,
        Packet(
          type: MessageType.handshake,
          experimentId: experimentId,
          total: config.tcpPayloadBytes,
        ),
        timeout,
      );
      await _receive(
        incoming,
        timeout,
        type: MessageType.ack,
        experiment: experimentId,
        sequence: 0,
        total: 0,
      );

      final samples = <double>[];
      for (var index = 0; index < config.rttProbes; index++) {
        final sentAt = clock.elapsedMicroseconds;
        await _send(
          socket,
          Packet(
            type: MessageType.rttProbe,
            experimentId: experimentId,
            sequence: index,
            total: config.tcpPayloadBytes,
            timestampUs: sentAt,
          ),
          timeout,
        );
        final echo = await _receive(
          incoming,
          timeout,
          type: MessageType.rttEcho,
          experiment: experimentId,
          sequence: index,
          total: config.tcpPayloadBytes,
        );
        if (echo.timestampUs != sentAt) {
          throw const NetworkFailure(
            NetworkFailureCode.malformedPacket,
            'RTT timestamp mismatch.',
          );
        }
        samples.add((clock.elapsedMicroseconds - sentAt) / 1000);
      }

      // Bulk timing includes application framing, socket backpressure and the
      // receiver acknowledgement. It excludes connect, handshake and RTT probes.
      final bulk = Stopwatch()..start();
      var sent = 0;
      var sequence = 0;
      final payload = Uint8List(NetworkConstants.tcpChunkSize);
      while (sent < config.tcpPayloadBytes) {
        _checkCancelled();
        final count = min(payload.length, config.tcpPayloadBytes - sent);
        await _send(
          socket,
          Packet(
            type: MessageType.dataChunk,
            experimentId: experimentId,
            sequence: sequence++,
            total: config.tcpPayloadBytes,
            timestampUs: clock.elapsedMicroseconds,
            payload: Uint8List.sublistView(payload, 0, count),
          ),
          timeout,
        );
        sent += count;
      }
      final ack = await _receive(
        incoming,
        timeout,
        type: MessageType.ack,
        experiment: experimentId,
        sequence: sequence,
        total: sent,
      );
      bulk.stop();
      await _receive(
        incoming,
        timeout,
        type: MessageType.summary,
        experiment: experimentId,
        sequence: sequence,
        total: ack.total,
      );
      await _send(
        socket,
        Packet(
          type: MessageType.close,
          experimentId: experimentId,
          total: sent,
        ),
        timeout,
      );
      _checkCancelled();
      final seconds = bulk.elapsedMicroseconds / Duration.microsecondsPerSecond;
      return right(
        TcpResult(
          runIndex: runIndex,
          rttSamplesMs: List<double>.unmodifiable(samples),
          bytesSent: sent,
          bytesAcked: ack.total,
          transferSeconds: seconds,
          throughputMbps: seconds > 0 ? ack.total * 8 / seconds / 1000000 : 0,
          completed: true,
        ),
      );
    } on Object catch (error) {
      return left(
        _cancelled
            ? const NetworkFailure(
                NetworkFailureCode.cancelled,
                'TCP run cancelled.',
              )
            : NetworkFailure.from(error),
      );
    } finally {
      clock.stop();
      _connecting?.cancel();
      _connecting = null;
      _socket?.destroy();
      _socket = null;
      await incoming?.cancel();
      _running = false;
    }
  }

  Stream<Packet> _frames(Socket socket) async* {
    final buffer = FrameBuffer();
    await for (final bytes in socket) {
      yield* Stream<Packet>.fromIterable(
        buffer
            .add(bytes)
            .fold((failure) => throw failure, (packets) => packets),
      );
    }
    buffer.finish().fold((failure) => throw failure, (_) {});
  }

  Future<Packet> _receive(
    StreamIterator<Packet> incoming,
    Duration timeout, {
    required MessageType type,
    required int experiment,
    required int sequence,
    required int total,
  }) async {
    _checkCancelled();
    if (!await incoming.moveNext().timeout(timeout)) {
      throw const NetworkFailure(
        NetworkFailureCode.disconnected,
        'TCP peer closed before the expected response.',
      );
    }
    _checkCancelled();
    final packet = incoming.current;
    if (packet.type != type ||
        packet.experimentId != experiment ||
        packet.sequence != sequence) {
      throw const NetworkFailure(
        NetworkFailureCode.malformedPacket,
        'Unexpected TCP response.',
      );
    }
    if (packet.total != total) {
      throw const NetworkFailure(
        NetworkFailureCode.byteCountMismatch,
        'TCP acknowledgement or expected byte count mismatch.',
      );
    }
    return packet;
  }

  Future<void> _send(Socket socket, Packet packet, Duration timeout) async {
    _checkCancelled();
    socket.add(
      _protocol
          .encode(packet)
          .fold((failure) => throw failure, (bytes) => bytes),
    );
    await socket.flush().timeout(timeout);
  }

  void _checkCancelled() {
    if (_cancelled) {
      throw const NetworkFailure(
        NetworkFailureCode.cancelled,
        'TCP run cancelled.',
      );
    }
  }

  @override
  FutureEitherVoid cancel() async {
    _cancelled = true;
    _connecting?.cancel();
    _socket?.destroy();
    return right(null);
  }
}
