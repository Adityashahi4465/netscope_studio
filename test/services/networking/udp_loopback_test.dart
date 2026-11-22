import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../lib/core/failure.dart';
import '../../../lib/modals/benchmark_config.dart';
import '../../../lib/modals/packet_record.dart';
import '../../../lib/modals/simulation_config.dart';
import '../../../lib/services/networking/delay_policy.dart';
import '../../../lib/services/networking/network_failure.dart';
import '../../../lib/services/networking/packet_protocol.dart';
import '../../../lib/services/networking/tcp_client.dart';
import '../../../lib/services/networking/tcp_server.dart';
import '../../../lib/services/networking/udp_audit.dart';
import '../../../lib/services/networking/udp_client.dart';
import '../../../lib/services/networking/udp_control_channel.dart';
import '../../../lib/services/networking/udp_drop_policy.dart';
import '../../../lib/services/networking/udp_server.dart';

T value<T>(Either<Failure, T> result) =>
    result.fold((failure) => throw TestFailure('$failure'), (value) => value);

NetworkFailureCode code<T>(Either<Failure, T> result) => result.fold(
  (failure) => (failure as NetworkFailure).code,
  (_) => throw TestFailure('Expected a failure.'),
);

class _Lab {
  final UdpServer udp;
  late final TcpServer tcp = TcpServer(controlHandler: udp);
  late int udpPort;
  late int tcpPort;

  _Lab({DelayPolicy? delay}) : udp = UdpServer(delayPolicy: delay);

  Future<void> start() async {
    udpPort = value(await udp.start(port: 0));
    tcpPort = value(await tcp.start(port: 0));
  }

  Future<void> stop() async {
    value(await udp.stop());
    value(await tcp.stop());
  }

  BenchmarkConfig config({
    int count = 32,
    int probes = 2,
    int timeoutMs = 2000,
    SimulationConfig simulation = SimulationConfig.none,
  }) => BenchmarkConfig(
    udpPort: udpPort,
    tcpPort: tcpPort,
    packetCount: count,
    rttProbes: probes,
    timeoutMs: timeoutMs,
    simulation: simulation,
  );

  Future<void> begin(
    RawDatagramSocket socket, {
    int experiment = 1,
    int count = 5,
    int size = 128,
    int seed = 5,
    double loss = 0,
  }) async {
    value(
      await UdpControlChannel().request(
        port: tcpPort,
        experimentId: experiment,
        body: <String, Object?>{
          'operation': 'begin',
          'clientPort': socket.port,
          'packetCount': count,
          'datagramSize': size,
          'rttProbes': 0,
          'seed': seed,
          'lossPercent': loss,
          'delayMs': 0,
          'jitterMs': 0,
        },
      ),
    );
  }

  void send(
    RawDatagramSocket socket,
    int sequence, {
    int experiment = 1,
    int count = 5,
    int size = 128,
  }) {
    final bytes = value(
      const PacketProtocol().encode(
        Packet(
          type: MessageType.dataChunk,
          experimentId: experiment,
          sequence: sequence,
          total: count,
          payload: Uint8List(size - PacketProtocol.headerSize),
        ),
      ),
    );
    expect(
      socket.send(bytes, InternetAddress.loopbackIPv4, udpPort),
      bytes.length,
    );
  }

  Future<UdpAudit> audit({int experiment = 1}) async => value(
    UdpAudit.fromMap(
      value(
        await UdpControlChannel().request(
          port: tcpPort,
          experimentId: experiment,
          body: <String, Object?>{
            'operation': 'audit',
            'collectionWindowMs': 30,
          },
        ),
      ),
    ),
  );
}

void main() {
  test(
    'real UDP loopback uses receiver audit, paced sends, and separate RTT',
    () async {
      final lab = _Lab();
      await lab.start();
      addTearDown(lab.stop);
      const simulation = SimulationConfig(
        lossPercent: 30,
        seed: 109,
        delayMs: 2,
        jitterMs: 1,
      );
      final result = value(
        await UdpClient().run(
          lab.config(count: 48, probes: 3, simulation: simulation),
          runIndex: 2,
          collectionWindow: const Duration(milliseconds: 30),
        ),
      );
      const drop = UdpDropPolicy(probability: 0.3, seed: 109);
      final expectedDrops = <int>{
        for (var i = 0; i < 48; i++)
          if (drop.shouldDrop(i)) i,
      };
      expect(result.runIndex, 2);
      expect(result.rttSamplesMs, hasLength(3));
      expect(result.probeTimeouts, 0);
      expect(result.packetsSent, 48);
      expect(result.droppedBySimulation, expectedDrops.length);
      expect(result.uniqueReceived, 48 - expectedDrops.length);
      expect(result.unexplainedLoss, 0);
      expect(result.bytesReceived, result.uniqueReceived * (1024 - 36));
      expect(result.packetRecords, hasLength(48));
      for (final record in result.packetRecords) {
        expect(
          record.status,
          expectedDrops.contains(record.sequence)
              ? PacketStatus.droppedBySimulation
              : PacketStatus.delivered,
        );
        expect(record.sizeBytes, 1024);
      }
      expect(
        result.goodputMbps,
        closeTo(
          result.bytesReceived * 8 / result.transferSeconds / 1000000,
          0.000001,
        ),
      );
      expect(() => result.packetRecords.clear(), throwsUnsupportedError);
    },
  );

  test(
    'malformed datagrams, oversized packets and wrong endpoints are rejected',
    () async {
      final lab = _Lab();
      await lab.start();
      addTearDown(lab.stop);
      final socket = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final stranger = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(socket.close);
      addTearDown(stranger.close);
      await lab.begin(socket);
      socket.send(<int>[1, 2], InternetAddress.loopbackIPv4, lab.udpPort);
      socket.send(Uint8List(36), InternetAddress.loopbackIPv4, lab.udpPort);
      lab.send(socket, 0, size: 1401);
      lab.send(socket, 5);
      lab.send(socket, 0, size: 129);
      lab.send(socket, 0, count: 6);
      lab.send(socket, 0, experiment: 2);
      lab.send(stranger, 0);
      lab.send(socket, 0);
      final audit = await lab.audit();
      expect(audit.receivedSequences, <int>{0});
      expect(audit.bytesReceived, 128 - 36);
      expect(lab.udp.rejectedDatagrams, 8);
      expect(audit.rejectedDatagrams, 2);
    },
  );

  test(
    'audit detects missing, duplicate and out-of-order sequence numbers',
    () async {
      final lab = _Lab();
      await lab.start();
      addTearDown(lab.stop);
      final socket = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(socket.close);
      await lab.begin(socket);
      for (final sequence in <int>[2, 0, 2, 1]) {
        lab.send(socket, sequence);
      }
      final audit = await lab.audit();
      expect(audit.receivedSequences, <int>{0, 1, 2});
      expect(audit.duplicateSequences, <int>{2});
      expect(audit.duplicates, 1);
      expect(audit.outOfOrderSequences, <int>{0, 1});
      expect(audit.bytesReceived, 3 * (128 - 36));
      lab.send(socket, 3); // Audit evidence stays frozen after the deadline.
      final again = value(await lab.udp.audit(1));
      expect(again.receivedSequences, <int>{0, 1, 2});
    },
  );

  test('real seeded drops reproduce when arrival order changes', () async {
    final lab = _Lab();
    await lab.start();
    addTearDown(lab.stop);
    final socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(socket.close);
    final audits = <UdpAudit>[];
    for (final experiment in <int>[1, 2]) {
      await lab.begin(
        socket,
        experiment: experiment,
        count: 64,
        seed: 88,
        loss: 40,
      );
      for (var index = 0; index < 64; index++) {
        final sequence = experiment == 1 ? index : 63 - index;
        lab.send(socket, sequence, experiment: experiment, count: 64);
        await Future<void>.delayed(Duration.zero);
      }
      audits.add(await lab.audit(experiment: experiment));
    }
    expect(audits[0].droppedSequences, isNotEmpty);
    expect(audits[0].receivedSequences, isNotEmpty);
    expect(audits[0].droppedSequences, audits[1].droppedSequences);
    expect(audits[0].receivedSequences, audits[1].receivedSequences);
    expect(
      audits[0].receivedSequences.length + audits[0].droppedSequences.length,
      64,
    );
  });

  test('drop attempts are separate from unique discarded requests', () async {
    final lab = _Lab();
    await lab.start();
    addTearDown(lab.stop);
    final socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(socket.close);
    await lab.begin(socket, loss: 100);
    for (final sequence in <int>[0, 0, 1, 2]) {
      lab.send(socket, sequence);
    }
    final audit = await lab.audit();
    expect(audit.simulationDropCount, 4);
    expect(audit.droppedSequences, <int>{0, 1, 2});
    expect(audit.receivedSequences, isEmpty);
    expect(audit.duplicates, 0);
    expect(audit.bytesReceived, 0);
    expect(audit.validDatagramArrivals, 4);
  });

  test(
    'largest workload audit is reassembled over the real TCP listener',
    () async {
      final lab = _Lab();
      await lab.start();
      addTearDown(lab.stop);
      final socket = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(socket.close);
      await lab.begin(socket, count: 100000);
      lab.send(socket, 99999, count: 100000);
      final audit = await lab.audit();
      expect(audit.packetCount, 100000);
      expect(audit.receivedSequences, <int>{99999});
      expect(audit.bytesReceived, 128 - 36);
    },
  );

  test(
    'conflicting registration cannot delete the existing experiment',
    () async {
      final lab = _Lab();
      await lab.start();
      addTearDown(lab.stop);
      final socket = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(socket.close);
      await lab.begin(socket);
      expect(
        code(await UdpClient().run(lab.config())),
        NetworkFailureCode.busy,
      );
      lab.send(socket, 0);
      expect((await lab.audit()).receivedSequences, <int>{0});
    },
  );

  test('cancellation interrupts a paced bulk transfer', () async {
    final lab = _Lab();
    await lab.start();
    addTearDown(lab.stop);
    final client = UdpClient();
    final run = client.run(
      lab.config(count: 100000, probes: 0),
      packetInterval: const Duration(milliseconds: 100),
    );
    // Allow registration and the first send; the long paced workload remains
    // active until cancellation, even if registration takes longer than usual.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    value(await client.cancel());
    expect(
      code(await run.timeout(const Duration(seconds: 1))),
      NetworkFailureCode.cancelled,
    );
    expect(
      value(
        await client.run(
          lab.config(count: 2, probes: 0),
          collectionWindow: const Duration(milliseconds: 10),
        ),
      ).uniqueReceived,
      2,
    );
  });

  test(
    'timed-out and late UDP echoes do not count as lost bulk requests',
    () async {
      final lab = _Lab(delay: const _LateEcho());
      await lab.start();
      addTearDown(lab.stop);
      final result = value(
        await UdpClient().run(
          lab.config(count: 10, probes: 3, timeoutMs: 100),
          collectionWindow: const Duration(milliseconds: 20),
        ),
      );
      expect(result.probeTimeouts, 3);
      expect(result.rttSamplesMs, isEmpty);
      expect(result.uniqueReceived, 10);
      expect(result.lostPackets, 0);
      expect(result.droppedBySimulation, 0);
    },
  );

  test('all simulated bulk drops still produce a reliable TCP audit', () async {
    final lab = _Lab();
    await lab.start();
    addTearDown(lab.stop);
    final result = value(
      await UdpClient().run(
        lab.config(
          count: 10,
          simulation: const SimulationConfig(lossPercent: 100, seed: 1),
        ),
        collectionWindow: const Duration(milliseconds: 20),
      ),
    );
    expect(result.uniqueReceived, 0);
    expect(result.lostPackets, 10);
    expect(result.droppedBySimulation, 10);
    expect(result.unexplainedLoss, 0);
    expect(result.bytesReceived, 0);
    expect(result.goodputMbps, 0);
  });

  test(
    'UDP and TCP benchmarks share a listener and run concurrently',
    () async {
      final lab = _Lab();
      await lab.start();
      addTearDown(lab.stop);
      final udpRun = UdpClient().run(lab.config(), experimentId: 11);
      final tcpRun = TcpClient().run(
        BenchmarkConfig(
          tcpPort: lab.tcpPort,
          tcpPayloadBytes: 70001,
          rttProbes: 2,
        ),
      );
      final otherUdp = UdpClient().run(lab.config(), experimentId: 12);
      expect(value(await udpRun).uniqueReceived, 32);
      expect(value(await tcpRun).bytesAcked, 70001);
      expect(value(await otherUdp).uniqueReceived, 32);
    },
  );

  test(
    'client rejects invalid sizes and unavailable reliable control',
    () async {
      final client = UdpClient();
      for (final size in <int>[0, 63, 1401, 65536]) {
        expect(
          code(await client.run(BenchmarkConfig(udpDatagramSize: size))),
          NetworkFailureCode.invalidInput,
        );
      }
      final lab = _Lab();
      await lab.start();
      final config = lab.config();
      await lab.stop();
      expect(code(await client.run(config)), NetworkFailureCode.refused);
    },
  );

  test(
    'cancel interrupts RTT promptly, releases session and permits reuse',
    () async {
      final entered = Completer<void>();
      final lab = _Lab(delay: _NotifyingDelay(entered));
      await lab.start();
      addTearDown(lab.stop);
      final client = UdpClient();
      final run = client.run(
        lab.config(count: 1000, probes: 1),
        packetInterval: const Duration(milliseconds: 100),
      );
      await entered.future;
      expect(code(await client.run(lab.config())), NetworkFailureCode.busy);
      value(await client.cancel());
      expect(
        code(await run.timeout(const Duration(seconds: 1))),
        NetworkFailureCode.cancelled,
      );
      expect(
        value(
          await client.run(
            lab.config(count: 4, probes: 0),
            collectionWindow: const Duration(milliseconds: 20),
          ),
        ).uniqueReceived,
        4,
      );
    },
  );

  test('server stop cancels delayed echoes and an in-flight audit', () async {
    final lab = _Lab(delay: const _LateEcho());
    await lab.start();
    addTearDown(lab.stop);
    final socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(socket.close);
    await lab.begin(socket);
    final audit = lab.udp.audit(
      1,
      collectionWindow: const Duration(seconds: 1),
    );
    value(await lab.udp.stop());
    expect(
      code(await audit.timeout(const Duration(seconds: 1))),
      NetworkFailureCode.disconnected,
    );
    expect(lab.udp.boundPort, isNull);
  });
}

class _LateEcho implements DelayPolicy {
  const _LateEcho();

  @override
  Duration delayForProbe(int sequence) => const Duration(milliseconds: 150);
}

class _NotifyingDelay implements DelayPolicy {
  final Completer<void> entered;

  const _NotifyingDelay(this.entered);

  @override
  Duration delayForProbe(int sequence) {
    if (!entered.isCompleted) entered.complete();
    return const Duration(seconds: 1);
  }
}
