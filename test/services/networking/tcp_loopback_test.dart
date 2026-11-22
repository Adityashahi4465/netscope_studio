import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../lib/core/failure.dart';
import '../../../lib/modals/benchmark_config.dart';
import '../../../lib/services/networking/delay_policy.dart';
import '../../../lib/services/networking/frame_buffer.dart';
import '../../../lib/services/networking/network_failure.dart';
import '../../../lib/services/networking/packet_protocol.dart';
import '../../../lib/services/networking/tcp_client.dart';
import '../../../lib/services/networking/tcp_server.dart';

T value<T>(Either<Failure, T> result) => result.fold(
  (failure) => throw TestFailure(failure.toString()),
  (value) => value,
);

NetworkFailureCode code<T>(Either<Failure, T> result) => result.fold(
  (failure) => (failure as NetworkFailure).code,
  (_) => throw TestFailure('Expected a failure.'),
);

Future<void> withPeer(
  Future<void> Function(Socket) serve,
  Future<void> Function(int) check,
) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final clients = <Socket>[];
  final tasks = <Future<void>>[];
  final subscription = server.listen((socket) {
    clients.add(socket);
    tasks.add(serve(socket));
  });
  try {
    await check(server.port);
  } finally {
    for (final socket in clients) {
      socket.destroy();
    }
    await subscription.cancel();
    await server.close();
    await Future.wait(tasks);
  }
}

void main() {
  test(
    'real loopback RTT and bulk with concurrent clients and simulated delay',
    () async {
      final server = TcpServer(
        delayPolicy: JitterDelayPolicy(
          delay: const Duration(milliseconds: 2),
          jitter: const Duration(milliseconds: 1),
          seed: 7,
        ),
      );
      final port = value(await server.start(port: 0));
      addTearDown(() async => value(await server.stop()));
      expect(server.boundPort, port);
      final results = await Future.wait(
        List.generate(
          3,
          (index) => TcpClient().run(
            BenchmarkConfig(
              tcpPort: port,
              tcpPayloadBytes: 1024 * 1024 + index + 1,
              rttProbes: 4,
              timeoutMs: 5000,
            ),
            experimentId: index + 1,
            runIndex: index,
          ),
        ),
      );
      for (var index = 0; index < results.length; index++) {
        final result = value(results[index]);
        expect(result.completed, isTrue);
        expect(result.runIndex, index);
        expect(result.bytesSent, 1024 * 1024 + index + 1);
        expect(result.bytesAcked, result.bytesSent);
        expect(result.rttSamplesMs, hasLength(4));
        expect(result.rttSamplesMs.every((sample) => sample >= 0), isTrue);
        expect(result.transferSeconds, greaterThan(0));
        expect(
          result.throughputMbps,
          closeTo(
            result.bytesAcked * 8 / result.transferSeconds / 1000000,
            0.000001,
          ),
        );
      }
    },
  );

  test('port conflict, refused connection, restart and invalid host', () async {
    final server = TcpServer();
    final other = TcpServer();
    final port = value(await server.start(port: 0));
    addTearDown(() async {
      value(await other.stop());
      value(await server.stop());
    });
    final conflict = await other.start(port: port);
    expect(code(conflict), NetworkFailureCode.portInUse, reason: '$conflict');
    value(await server.stop());
    final refused = await TcpClient().run(
      BenchmarkConfig(tcpPort: port, timeoutMs: 8000),
    );
    expect(code(refused), NetworkFailureCode.refused, reason: '$refused');
    value(await server.start(port: port));
    expect(
      code(await TcpClient().run(const BenchmarkConfig(host: 'example.com'))),
      NetworkFailureCode.invalidInput,
    );
  });

  test('silent peer times out and abrupt close is detected', () async {
    await withPeer(
      (socket) async {
        await socket.drain<void>();
      },
      (port) async {
        expect(
          code(
            await TcpClient().run(
              BenchmarkConfig(tcpPort: port, timeoutMs: 100),
            ),
          ),
          NetworkFailureCode.timeout,
        );
      },
    );
    await withPeer(
      (socket) async {
        socket.destroy();
      },
      (port) async {
        expect(
          code(await TcpClient().run(BenchmarkConfig(tcpPort: port))),
          NetworkFailureCode.disconnected,
        );
      },
    );
  });

  test('client rejects wrong measured acknowledgement count', () async {
    const protocol = PacketProtocol();
    await withPeer(
      (socket) async {
        final buffer = FrameBuffer();
        await for (final bytes in socket) {
          for (final packet in value(buffer.add(bytes))) {
            if (packet.type == MessageType.handshake ||
                packet.type == MessageType.dataChunk) {
              socket.add(
                value(
                  protocol.encode(
                    Packet(
                      type: MessageType.ack,
                      experimentId: packet.experimentId,
                      sequence: packet.type == MessageType.handshake ? 0 : 1,
                      total: packet.type == MessageType.handshake
                          ? 0
                          : packet.total - 1,
                    ),
                  ),
                ),
              );
              await socket.flush();
            }
          }
        }
      },
      (port) async {
        expect(
          code(
            await TcpClient().run(
              BenchmarkConfig(
                tcpPort: port,
                tcpPayloadBytes: 1024,
                rttProbes: 0,
              ),
            ),
          ),
          NetworkFailureCode.byteCountMismatch,
        );
      },
    );
  });

  test(
    'cancellation interrupts a pending response and client can be reused',
    () async {
      final ready = Completer<void>();
      final client = TcpClient();
      await withPeer(
        (socket) async {
          ready.complete();
          await socket.drain<void>();
        },
        (port) async {
          final run = client.run(BenchmarkConfig(tcpPort: port));
          await ready.future;
          expect(
            code(await client.run(BenchmarkConfig(tcpPort: port))),
            NetworkFailureCode.busy,
          );
          value(await client.cancel());
          expect(code(await run), NetworkFailureCode.cancelled);
        },
      );
      final server = TcpServer();
      final port = value(await server.start(port: 0));
      try {
        expect(
          value(
            await client.run(
              BenchmarkConfig(
                tcpPort: port,
                tcpPayloadBytes: 1024,
                rttProbes: 0,
              ),
            ),
          ).completed,
          isTrue,
        );
      } finally {
        value(await server.stop());
      }
    },
  );

  test('abrupt and malformed clients do not affect later clients', () async {
    final server = TcpServer();
    final port = value(await server.start(port: 0));
    try {
      final broken = await Socket.connect(InternetAddress.loopbackIPv4, port);
      broken.add(Uint8List(PacketProtocol.headerSize));
      await broken.flush();
      broken.destroy();
      final partial = await Socket.connect(InternetAddress.loopbackIPv4, port);
      partial.add(<int>[0x4e]);
      await partial.flush();
      partial.destroy();
      expect(
        value(
          await TcpClient().run(
            BenchmarkConfig(
              tcpPort: port,
              tcpPayloadBytes: 70001,
              rttProbes: 1,
            ),
          ),
        ).completed,
        isTrue,
      );
    } finally {
      value(await server.stop());
    }
  });

  test(
    'stop interrupts connected clients, including pending simulated delay',
    () async {
      final entered = Completer<void>();
      final server = TcpServer(delayPolicy: _SignallingDelay(entered));
      final port = value(await server.start(port: 0));
      final run = TcpClient().run(
        BenchmarkConfig(tcpPort: port, timeoutMs: 5000),
      );
      await entered.future;
      value(await server.stop().timeout(const Duration(seconds: 1)));
      expect(code(await run), NetworkFailureCode.disconnected);
      expect(server.boundPort, isNull);
      value(await server.stop());
    },
  );
}

class _SignallingDelay implements DelayPolicy {
  final Completer<void> entered;

  const _SignallingDelay(this.entered);

  @override
  Duration delayForProbe(int sequence) {
    if (!entered.isCompleted) entered.complete();
    return const Duration(seconds: 10);
  }
}
