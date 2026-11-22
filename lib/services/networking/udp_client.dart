import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../constants/network_constants.dart';
import '../../core/type_defs.dart';
import '../../modals/benchmark_config.dart';
import '../../modals/packet_record.dart';
import '../../modals/udp_result.dart';
import 'i_udp_client.dart';
import 'network_failure.dart';
import 'packet_protocol.dart';
import 'udp_audit.dart';
import 'udp_control_channel.dart';

class UdpClient implements IUdpClient {
  final PacketProtocol _protocol = const PacketProtocol();
  final UdpControlChannel _control = UdpControlChannel();
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
  Completer<void>? _interrupted;
  Completer<Packet?>? _probe;
  NetworkFailure? _fatal;
  bool _running = false;
  bool _cancelled = false;
  bool _cleaningUp = false;

  @override
  FutureEither<UdpResult> run(
    BenchmarkConfig config, {
    int experimentId = 1,
    int runIndex = 0,
    Duration packetInterval = const Duration(milliseconds: 1),
    Duration collectionWindow = const Duration(milliseconds: 100),
  }) async {
    if (_running) {
      return left(
        const NetworkFailure(
          NetworkFailureCode.busy,
          'This UDP client already has an active run.',
        ),
      );
    }
    final simulation = config.simulation;
    final rateIntervalUs = simulation.hasRateLimit
        ? config.udpDatagramSize * 8 / simulation.rateLimitMbps
        : 0.0;
    if (config.host != NetworkConstants.defaultHost ||
        config.tcpPort <= 0 ||
        config.tcpPort > 65535 ||
        config.udpPort <= 0 ||
        config.udpPort > 65535 ||
        config.udpDatagramSize < NetworkConstants.minUdpDatagramSize ||
        config.udpDatagramSize > NetworkConstants.maxUdpDatagramSize ||
        config.packetCount <= 0 ||
        config.packetCount > NetworkConstants.maxPacketCount ||
        config.rttProbes < 0 ||
        config.rttProbes > NetworkConstants.maxRttProbes ||
        config.timeoutMs <= 0 ||
        config.timeoutMs > NetworkConstants.maxTimeoutMs ||
        experimentId <= 0 ||
        experimentId > PacketProtocol.maxUnsigned32 ||
        runIndex < 0 ||
        packetInterval < Duration.zero ||
        packetInterval.inMilliseconds > config.timeoutMs ||
        collectionWindow < Duration.zero ||
        collectionWindow.inMilliseconds > 1000 ||
        collectionWindow.inMilliseconds >= config.timeoutMs ||
        !simulation.lossPercent.isFinite ||
        simulation.lossPercent < 0 ||
        simulation.lossPercent > 100 ||
        simulation.delayMs < 0 ||
        simulation.delayMs > NetworkConstants.maxDelayMs ||
        simulation.jitterMs < 0 ||
        simulation.jitterMs > NetworkConstants.maxJitterMs ||
        !simulation.rateLimitMbps.isFinite ||
        simulation.rateLimitMbps < 0 ||
        simulation.rateLimitMbps > NetworkConstants.maxRateLimitMbps ||
        !rateIntervalUs.isFinite ||
        rateIntervalUs > config.timeoutMs * 1000 ||
        (simulation.seed != null &&
            (simulation.seed! < 0 ||
                simulation.seed! > PacketProtocol.maxUnsigned32))) {
      return left(
        const NetworkFailure(
          NetworkFailureCode.invalidInput,
          'Invalid loopback UDP run configuration or datagram size.',
        ),
      );
    }
    _running = true;
    _cancelled = false;
    _cleaningUp = false;
    _fatal = null;
    _interrupted = Completer<void>();
    final timeout = Duration(milliseconds: config.timeoutMs);
    final clock = Stopwatch()..start();
    var registered = false;
    var expectedProbe = -1;
    var expectedTimestamp = -1;
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
        reuseAddress: false,
      );
      _socket = socket;
      _check();
      socket.writeEventsEnabled = false;
      _subscription = socket.listen((event) {
        if (_cleaningUp || _cancelled || _socket != socket) return;
        try {
          if (event == RawSocketEvent.closed && !_cleaningUp) {
            _abort(
              const NetworkFailure(
                NetworkFailureCode.disconnected,
                'UDP socket closed unexpectedly.',
              ),
            );
          }
          if (event != RawSocketEvent.read) return;
          Datagram? datagram;
          while ((datagram = socket.receive()) != null) {
            final response = datagram!;
            if (response.address.address != NetworkConstants.defaultHost ||
                response.port != config.udpPort ||
                response.data.length > NetworkConstants.maxUdpDatagramSize) {
              continue;
            }
            _protocol.decode(response.data).fold((_) {}, (packet) {
              if (packet.type == MessageType.rttEcho &&
                  packet.experimentId == experimentId &&
                  packet.total == config.packetCount &&
                  packet.sequence == expectedProbe &&
                  packet.timestampUs == expectedTimestamp &&
                  _probe != null &&
                  !_probe!.isCompleted) {
                _probe!.complete(packet);
              }
            });
          }
        } on Object catch (error) {
          _abort(NetworkFailure.from(error));
        }
      }, onError: (Object error) => _abort(NetworkFailure.from(error)));
      final begin = await _control.request(
        port: config.tcpPort,
        experimentId: experimentId,
        timeout: timeout,
        body: <String, Object?>{
          'operation': 'begin',
          'clientPort': socket.port,
          'packetCount': config.packetCount,
          'datagramSize': config.udpDatagramSize,
          'rttProbes': config.rttProbes,
          'lossPercent': simulation.lossPercent,
          'seed': simulation.seed,
          'delayMs': simulation.delayMs,
          'jitterMs': simulation.jitterMs,
        },
      );
      final registration = begin.fold((failure) => throw failure, (map) => map);
      registered = true;
      if (registration['udpPort'] != config.udpPort) {
        throw const NetworkFailure(
          NetworkFailureCode.invalidInput,
          'TCP control belongs to a different UDP server port.',
        );
      }
      _check();
      final samples = <double>[];
      var probeTimeouts = 0;
      for (var sequence = 0; sequence < config.rttProbes; sequence++) {
        _check();
        expectedProbe = sequence;
        expectedTimestamp = clock.elapsedMicroseconds;
        final probe = Completer<Packet?>();
        _probe = probe;
        await _send(
          Packet(
            type: MessageType.rttProbe,
            experimentId: experimentId,
            sequence: sequence,
            total: config.packetCount,
            timestampUs: expectedTimestamp,
          ),
          config.udpPort,
          timeout,
        );
        final echo = await probe.future.timeout(timeout, onTimeout: () => null);
        _check();
        if (echo == null) {
          probeTimeouts++;
        } else {
          samples.add((clock.elapsedMicroseconds - expectedTimestamp) / 1000);
        }
        _probe = null;
      }
      expectedProbe = -1;
      expectedTimestamp = -1;

      final payload = Uint8List(
        config.udpDatagramSize - PacketProtocol.headerSize,
      );
      final sentAt = <int>[];
      final bulk = Stopwatch()..start();
      final capIntervalUs = rateIntervalUs.ceil();
      final interval = Duration(
        microseconds: max(packetInterval.inMicroseconds, capIntervalUs),
      );
      for (var sequence = 0; sequence < config.packetCount; sequence++) {
        _check();
        final timestamp = clock.elapsedMicroseconds;
        await _send(
          Packet(
            type: MessageType.dataChunk,
            experimentId: experimentId,
            sequence: sequence,
            total: config.packetCount,
            timestampUs: timestamp,
            payload: payload,
          ),
          config.udpPort,
          timeout,
        );
        sentAt.add(timestamp);
        if (sequence + 1 < config.packetCount) await _wait(interval);
      }
      final response = await _control.request(
        port: config.tcpPort,
        experimentId: experimentId,
        timeout: timeout,
        body: <String, Object?>{
          'operation': 'audit',
          'collectionWindowMs': collectionWindow.inMilliseconds,
        },
      );
      _check();
      final audit = response.fold(
        (failure) => throw failure,
        (map) =>
            UdpAudit.fromMap(map)
                .fold((failure) => throw failure, (audit) => audit),
      );
      bulk.stop();
      if (audit.experimentId != experimentId ||
          audit.packetCount != config.packetCount ||
          audit.datagramSize != config.udpDatagramSize ||
          audit.seed != registration['seed'] ||
          (audit.lossPercent - simulation.lossPercent).abs() > 0.000001 ||
          audit.collectionWindowMs != collectionWindow.inMilliseconds) {
        throw const NetworkFailure(
          NetworkFailureCode.malformedPacket,
          'UDP audit does not match the registered run.',
        );
      }
      final records = List<PacketRecord>.unmodifiable(
        List.generate(
          config.packetCount,
          (sequence) => PacketRecord(
            sequence: sequence,
            status: audit.receivedSequences.contains(sequence)
                ? PacketStatus.delivered
                : audit.droppedSequences.contains(sequence)
                ? PacketStatus.droppedBySimulation
                : PacketStatus.missing,
            sizeBytes: config.udpDatagramSize,
            sentAtUs: sentAt[sequence],
          ),
        ),
      );
      final seconds = bulk.elapsedMicroseconds / Duration.microsecondsPerSecond;
      return right(
        UdpResult(
          runIndex: runIndex,
          rttSamplesMs: List<double>.unmodifiable(samples),
          probeTimeouts: probeTimeouts,
          packetsSent: sentAt.length,
          uniqueReceived: audit.receivedSequences.length,
          duplicates: audit.duplicates,
          outOfOrder: audit.outOfOrderSequences.length,
          droppedBySimulation: audit.droppedSequences.length,
          bytesReceived: audit.bytesReceived,
          transferSeconds: seconds,
          goodputMbps: seconds > 0
              ? audit.bytesReceived * 8 / seconds / 1000000
              : 0,
          packetRecords: records,
        ),
      );
    } on Object catch (error) {
      return left(
        _cancelled
            ? const NetworkFailure(
                NetworkFailureCode.cancelled,
                'UDP run cancelled.',
              )
            : _fatal ?? NetworkFailure.from(error),
      );
    } finally {
      _cleaningUp = true;
      clock.stop();
      _probe = null;
      _socket?.close();
      _socket = null;
      try {
        await _subscription?.cancel();
        if (registered) {
          // Release is best effort. A lost registration response is reclaimed
          // by the server's session expiry instead of deleting another run.
          await UdpControlChannel().request(
            port: config.tcpPort,
            experimentId: experimentId,
            timeout: Duration(milliseconds: min(config.timeoutMs, 250)),
            body: <String, Object?>{'operation': 'release'},
          );
        }
      } on Object {
        // Preserve the run's measured result or already-classified Failure.
      }
      _subscription = null;
      _interrupted = null;
      _running = false;
    }
  }

  Future<void> _send(Packet packet, int port, Duration timeout) async {
    final bytes = _protocol
        .encode(packet)
        .fold((failure) => throw failure, (bytes) => bytes);
    final clock = Stopwatch()..start();
    while (true) {
      _check();
      final sent = _socket!.send(bytes, InternetAddress.loopbackIPv4, port);
      if (sent == bytes.length) return;
      if (sent != 0) {
        throw const NetworkFailure(
          NetworkFailureCode.io,
          'UDP socket reported a partial datagram send.',
        );
      }
      if (clock.elapsed >= timeout) {
        throw TimeoutException('UDP send timed out.');
      }
      await _wait(const Duration(milliseconds: 1));
    }
  }

  Future<void> _wait(Duration duration) async {
    final done = Completer<void>();
    final timer = Timer(duration, done.complete);
    try {
      await Future.any<void>(<Future<void>>[done.future, _interrupted!.future]);
      _check();
    } finally {
      timer.cancel();
    }
  }

  void _abort(NetworkFailure failure) {
    if (_cleaningUp) return;
    _fatal ??= failure;
    if (_interrupted != null && !_interrupted!.isCompleted) {
      _interrupted!.complete();
    }
    if (_probe != null && !_probe!.isCompleted) _probe!.complete(null);
    unawaited(_control.cancel());
  }

  void _check() {
    if (_cancelled) {
      throw const NetworkFailure(
        NetworkFailureCode.cancelled,
        'UDP run cancelled.',
      );
    }
    if (_fatal != null) throw _fatal!;
  }

  @override
  FutureEitherVoid cancel() async {
    _cancelled = true;
    if (_interrupted != null && !_interrupted!.isCompleted) {
      _interrupted!.complete();
    }
    if (_probe != null && !_probe!.isCompleted) _probe!.complete(null);
    _socket?.close();
    return _control.cancel();
  }
}
