import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/enums/protocol_type.dart';
import '../../../lib/modals/benchmark_config.dart';
import '../../../lib/modals/simulation_config.dart';
import '../../../lib/services/benchmark/benchmark_service.dart';
import '../../../lib/services/benchmark/i_benchmark_service.dart';
import '../../../lib/services/benchmark/comparison_service.dart';

Future<BenchmarkConfig> localConfig() async {
  final tcp = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final udp = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final config = BenchmarkConfig(
    tcpPort: tcp.port,
    udpPort: udp.port,
    tcpPayloadBytes: 8192,
    packetCount: 12,
    rttProbes: 2,
    repetitions: 2,
    simulation: const SimulationConfig(
      seed: 42,
      lossPercent: 25,
      rateLimitMbps: 1,
    ),
  );
  udp.close();
  await tcp.close();
  return config;
}

void main() {
  test(
    'real repeated loopback excludes warm-up and publishes measured progress',
    () async {
      final service = BenchmarkService();
      addTearDown(service.dispose);
      final events = <BenchmarkProgress>[];
      final subscription = service.progress.listen(events.add);
      addTearDown(subscription.cancel);
      final config = await localConfig();
      final result = (await service.run(
        config,
        CancelToken(),
      )).fold((f) => fail(f.message), (r) => r);
      expect(result.tcpRuns.map((r) => r.runIndex), [1, 2]);
      expect(result.udpRuns.map((r) => r.runIndex), [1, 2]);
      expect(result.tcpRuns.first.bytesAcked, 8192);
      expect(result.tcpAggregate.sampleCount, 4);
      expect(result.tcpAggregate.throughputMbps, inExclusiveRange(0, 1.01));
      expect(
        result.udpRuns.first.bytesReceived,
        result.udpRuns.first.uniqueReceived * (1024 - 36),
      );
      expect(result.udpRuns.first.droppedBySimulation, greaterThan(0));
      expect(events.last.percent, 100);
      expect(
        events.any((p) => p.tcpOnline && p.udpOnline && p.tcp.runs > 0),
        isTrue,
      );
      expect(
        const ComparisonService().insights([result, result]).join(' '),
        contains('Experiment 2'),
      );
      final listener = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        config.tcpPort,
      );
      await listener.close();
    },
  );

  test(
    'UDP-only uses the TCP control listener and recovers from partial startup',
    () async {
      final config = (await localConfig()).copyWith(protocol: ProtocolType.udp);
      final occupied = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        config.tcpPort,
      );
      final service = BenchmarkService();
      addTearDown(service.dispose);
      try {
        expect((await service.run(config, CancelToken())).isLeft(), isTrue);
        final released = await RawDatagramSocket.bind(
          InternetAddress.loopbackIPv4,
          config.udpPort,
        );
        released.close();
      } finally {
        await occupied.close();
      }
      final result = (await service.run(
        config,
        CancelToken(),
      )).fold((f) => fail(f.message), (r) => r);
      expect(result.hasTcp, isFalse);
      expect(result.udpAggregate.runs, config.repetitions);
    },
  );

  test('cancellation, busy guard, invalid input and port reuse', () async {
    final service = BenchmarkService();
    addTearDown(service.dispose);
    final config = (await localConfig()).copyWith(protocol: ProtocolType.tcp);
    final token = CancelToken();
    final sub = service.progress.listen((p) {
      if (p.phase == 'Measuring TCP') token.cancel();
    });
    final pending = service.run(config, token);
    expect((await service.run(config, CancelToken())).isLeft(), isTrue);
    expect(
      (await pending).fold((f) => f.message, (_) => ''),
      contains('cancelled'),
    );
    await sub.cancel();
    expect(
      (await service.run(
        config.copyWith(host: '192.0.2.1'),
        CancelToken(),
      )).isLeft(),
      isTrue,
    );
    expect((await service.run(config, CancelToken())).isRight(), isTrue);
  });
}
