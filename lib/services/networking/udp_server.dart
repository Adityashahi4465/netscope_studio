import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fpdart/fpdart.dart';

import '../../constants/network_constants.dart';
import '../../core/type_defs.dart';
import 'delay_policy.dart';
import 'i_udp_server.dart';
import 'network_failure.dart';
import 'packet_protocol.dart';
import 'udp_audit.dart';
import 'udp_control_channel.dart';
import '../../modals/simulation_config.dart';
import '../simulation/network_simulator.dart';
import 'udp_drop_policy.dart';

class UdpServer implements IUdpServer {
  final DelayPolicy? delayPolicy;
  final PacketProtocol _protocol = const PacketProtocol();
  final Map<int, _UdpSession> _sessions = <int, _UdpSession>{};
  final Set<Timer> _echoTimers = <Timer>{};
  final Stopwatch _clock = Stopwatch()..start();
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
  Completer<void>? _starting;
  Completer<void>? _shutdown;
  Timer? _expiryTimer;
  bool _stopping = false;
  int _rejectedDatagrams = 0;
  Duration _sessionTimeout = const Duration(minutes: 2);

  /// An injected policy overrides registered simulated delay/jitter, for example
  /// to run deterministic teaching scenarios. Drop settings remain per run.
  UdpServer({this.delayPolicy});

  @override
  int? get boundPort => _socket?.port;

  @override
  int get rejectedDatagrams => _rejectedDatagrams;

  @override
  FutureEither<int> start({
    int port = NetworkConstants.defaultUdpPort,
    Duration sessionTimeout = const Duration(minutes: 2),
  }) async {
    if (_socket != null || _starting != null || _stopping) {
      return left(
        const NetworkFailure(
          NetworkFailureCode.busy,
          'UDP server is already running or changing state.',
        ),
      );
    }
    if (port < 0 || port > 65535 || sessionTimeout <= Duration.zero) {
      return left(_invalid('Invalid UDP server port or session timeout.'));
    }
    final starting = Completer<void>();
    _starting = starting;
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
        reuseAddress: false,
      );
      socket.writeEventsEnabled = false;
      _socket = socket;
      _shutdown = Completer<void>();
      _sessionTimeout = sessionTimeout;
      _rejectedDatagrams = 0;
      _subscription = socket.listen(
        (event) {
          if (_stopping || _socket != socket) return;
          try {
            if (event == RawSocketEvent.closed) {
              unawaited(stop());
              return;
            }
            if (event == RawSocketEvent.read) {
              // Drain each readiness notification; UDP datagram boundaries survive.
              Datagram? datagram;
              while ((datagram = socket.receive()) != null) {
                _receive(datagram!);
              }
            }
          } on Object {
            unawaited(stop());
          }
        },
        onError: (Object error) {
          unawaited(stop());
        },
      );
      _expiryTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _expire(),
      );
      return right(socket.port);
    } on Object catch (error) {
      return left(NetworkFailure.from(error, binding: true));
    } finally {
      _starting = null;
      starting.complete();
    }
  }

  void _receive(Datagram datagram) {
    try {
      if (datagram.address.address != NetworkConstants.defaultHost ||
          datagram.data.length > NetworkConstants.maxUdpDatagramSize) {
        _rejectedDatagrams++;
        return;
      }
      final packet = _protocol
          .decode(datagram.data)
          .fold((failure) => throw failure, (packet) => packet);
      final session = _sessions[packet.experimentId];
      if (session == null ||
          session.port != datagram.port ||
          session.sealed != null ||
          packet.total != session.count) {
        _rejectedDatagrams++;
        return;
      }
      session.lastActivityUs = _clock.elapsedMicroseconds;
      if (packet.type == MessageType.rttProbe &&
          !session.bulkStarted &&
          packet.sequence < session.probeCount) {
        if (!session.probes.add(packet.sequence)) return;
        final delay = session.delay.delayForProbe(packet.sequence);
        if (delay < Duration.zero ||
            delay.inMilliseconds >
                NetworkConstants.maxDelayMs + NetworkConstants.maxJitterMs) {
          throw _invalid('Invalid simulated UDP echo delay.');
        }
        final echo = _protocol
            .encode(
              Packet(
                type: MessageType.rttEcho,
                experimentId: packet.experimentId,
                sequence: packet.sequence,
                total: packet.total,
                timestampUs: packet.timestampUs,
              ),
            )
            .fold((failure) => throw failure, (bytes) => bytes);
        late final Timer timer;
        timer = Timer(delay, () {
          _echoTimers.remove(timer);
          session.timers.remove(timer);
          if (_socket == null || _sessions[packet.experimentId] != session) {
            return;
          }
          try {
            _socket!.send(echo, datagram.address, datagram.port);
          } on Object {
            // Echo delivery does not change evidence of received bulk requests.
          }
        });
        _echoTimers.add(timer);
        session.timers.add(timer);
        return;
      }
      if (packet.type != MessageType.dataChunk ||
          packet.sequence >= session.count ||
          datagram.data.length != session.size) {
        session.rejected++;
        _rejectedDatagrams++;
        return;
      }
      session.bulkStarted = true;
      if (session.drop.shouldDrop(packet.sequence)) {
        session.dropCount++;
        session.dropped.add(packet.sequence);
        return;
      }
      if (!session.received.add(packet.sequence)) {
        session.duplicates++;
        session.duplicateSequences.add(packet.sequence);
        return;
      }
      if (packet.sequence < session.highestSequence) {
        session.outOfOrder.add(packet.sequence);
      }
      session.highestSequence = max(session.highestSequence, packet.sequence);
      session.bytesReceived += packet.payload.length;
    } on Object {
      _rejectedDatagrams++;
    }
  }

  @override
  bool accepts(Packet request) => UdpControlCodec.accepts(request);

  @override
  FutureEither<List<Packet>> handle(Packet request) async {
    Map<String, Object?> response;
    try {
      if (!accepts(request) || request.total != 0 || request.timestampUs != 0) {
        throw _invalid('Invalid UDP control frame.');
      }
      if (_socket == null || _stopping) {
        throw const NetworkFailure(
          NetworkFailureCode.disconnected,
          'UDP server is not running.',
        );
      }
      final body = UdpControlCodec.decode(request.payload)
          .fold((failure) => throw failure, (body) => body);
      switch (body['operation']) {
        case 'begin':
          response = _begin(request.experimentId, body);
        case 'audit':
          final window = _integer(body, 'collectionWindowMs', 0, 1000);
          final result = await audit(
            request.experimentId,
            collectionWindow: Duration(milliseconds: window),
          );
          response = result.fold(
            (failure) => throw failure,
            (audit) => <String, Object?>{'ok': true, ...audit.toMap()},
          );
        case 'release':
          _remove(request.experimentId);
          response = <String, Object?>{'ok': true};
        default:
          throw _invalid('Unknown UDP control operation.');
      }
    } on Object catch (error) {
      final failure = NetworkFailure.from(error);
      response = <String, Object?>{
        'ok': false,
        'code': failure.code.name,
        'message': failure.message,
      };
    }
    return UdpControlCodec.response(request.experimentId, response);
  }

  Map<String, Object?> _begin(int experiment, Map<String, Object?> body) {
    _expire();
    if (_sessions.containsKey(experiment) || _sessions.length >= 16) {
      throw const NetworkFailure(
        NetworkFailureCode.busy,
        'UDP experiment exists or session limit reached.',
      );
    }
    final port = _integer(body, 'clientPort', 1, 65535);
    final count = _integer(
      body,
      'packetCount',
      1,
      NetworkConstants.maxPacketCount,
    );
    final size = _integer(
      body,
      'datagramSize',
      NetworkConstants.minUdpDatagramSize,
      NetworkConstants.maxUdpDatagramSize,
    );
    final probes = _integer(
      body,
      'rttProbes',
      0,
      NetworkConstants.maxRttProbes,
    );
    final seed = body['seed'] == null
        ? Random().nextInt(0x100000000)
        : _integer(body, 'seed', 0, PacketProtocol.maxUnsigned32);
    final loss = body['lossPercent'];
    if (loss is! num || !loss.isFinite || loss < 0 || loss > 100) {
      throw _invalid('Invalid simulated UDP drop percentage.');
    }
    final delay = _integer(body, 'delayMs', 0, NetworkConstants.maxDelayMs);
    final jitter = _integer(body, 'jitterMs', 0, NetworkConstants.maxJitterMs);
    final simulation = SimulationConfig(
      delayMs: delay,
      jitterMs: jitter,
      lossPercent: loss.toDouble(),
      seed: seed,
    );
    const simulator = NetworkSimulator();
    _sessions[experiment] = _UdpSession(
      port: port,
      count: count,
      size: size,
      probeCount: probes,
      drop: simulator.drop(simulation),
      delay: delayPolicy ?? simulator.delay(simulation),
      lastActivityUs: _clock.elapsedMicroseconds,
    );
    return <String, Object?>{'ok': true, 'seed': seed, 'udpPort': boundPort};
  }

  int _integer(Map<String, Object?> map, String key, int min, int max) {
    final value = map[key];
    if (value is! int || value < min || value > max) {
      throw _invalid('Invalid UDP control $key.');
    }
    return value;
  }

  @override
  FutureEither<UdpAudit> audit(
    int experimentId, {
    Duration collectionWindow = const Duration(milliseconds: 100),
  }) async {
    if (collectionWindow < Duration.zero ||
        collectionWindow.inMilliseconds > 1000) {
      return left(_invalid('Invalid UDP collection window.'));
    }
    final session = _sessions[experimentId];
    if (session == null) return left(_invalid('Unknown UDP experiment.'));
    if (session.sealed != null) return right(session.sealed!);
    if (session.sealing) {
      return left(
        const NetworkFailure(
          NetworkFailureCode.busy,
          'UDP audit is already collecting final arrivals.',
        ),
      );
    }
    session.sealing = true;
    final done = Completer<void>();
    final timer = Timer(collectionWindow, done.complete);
    try {
      // Independent transports have no cross-protocol ordering guarantee.
      // Continue receiving for a bounded window, then freeze the evidence.
      await Future.any<void>(<Future<void>>[done.future, _shutdown!.future]);
      if (_socket == null || _stopping || _sessions[experimentId] != session) {
        throw const NetworkFailure(
          NetworkFailureCode.disconnected,
          'UDP experiment closed during audit.',
        );
      }
      final audit = UdpAudit(
        experimentId: experimentId,
        packetCount: session.count,
        datagramSize: session.size,
        receivedSequences: session.received,
        droppedSequences: session.dropped,
        duplicateSequences: session.duplicateSequences,
        outOfOrderSequences: session.outOfOrder,
        duplicates: session.duplicates,
        simulationDropCount: session.dropCount,
        bytesReceived: session.bytesReceived,
        rejectedDatagrams: session.rejected,
        seed: session.drop.seed,
        lossPercent: session.drop.probability * 100,
        collectionWindowMs: collectionWindow.inMilliseconds,
      );
      session.sealed = audit;
      return right(audit);
    } on Object catch (error) {
      return left(NetworkFailure.from(error));
    } finally {
      timer.cancel();
      session.sealing = false;
    }
  }

  void _expire() {
    final now = _clock.elapsedMicroseconds;
    for (final entry in _sessions.entries.toList(growable: false)) {
      if (!entry.value.sealing &&
          now - entry.value.lastActivityUs > _sessionTimeout.inMicroseconds) {
        _remove(entry.key);
      }
    }
  }

  void _remove(int experiment) {
    final session = _sessions.remove(experiment);
    if (session == null) return;
    for (final timer in session.timers) {
      timer.cancel();
      _echoTimers.remove(timer);
    }
  }

  NetworkFailure _invalid(String message) =>
      NetworkFailure(NetworkFailureCode.invalidInput, message);

  @override
  FutureEitherVoid stop() async {
    if (_stopping) {
      return left(
        const NetworkFailure(
          NetworkFailureCode.busy,
          'UDP server is already stopping.',
        ),
      );
    }
    _stopping = true;
    try {
      await _starting?.future;
      _shutdown?.complete();
      _shutdown = null;
      _expiryTimer?.cancel();
      _expiryTimer = null;
      for (final timer in _echoTimers) {
        timer.cancel();
      }
      _echoTimers.clear();
      _socket?.close();
      await _subscription?.cancel();
      _sessions.clear();
      return right(null);
    } on Object catch (error) {
      return left(NetworkFailure.from(error));
    } finally {
      _socket = null;
      _subscription = null;
      _stopping = false;
    }
  }
}

class _UdpSession {
  final int port;
  final int count;
  final int size;
  final int probeCount;
  final UdpDropPolicy drop;
  final DelayPolicy delay;
  final Set<int> probes = <int>{};
  final Set<int> received = <int>{};
  final Set<int> dropped = <int>{};
  final Set<int> duplicateSequences = <int>{};
  final Set<int> outOfOrder = <int>{};
  final Set<Timer> timers = <Timer>{};
  int lastActivityUs;
  int highestSequence = -1;
  int duplicates = 0;
  int dropCount = 0;
  int bytesReceived = 0;
  int rejected = 0;
  bool bulkStarted = false;
  bool sealing = false;
  UdpAudit? sealed;

  _UdpSession({
    required this.port,
    required this.count,
    required this.size,
    required this.probeCount,
    required this.drop,
    required this.delay,
    required this.lastActivityUs,
  });
}
