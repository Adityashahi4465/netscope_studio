import 'dart:async';
import 'dart:math';

import 'package:fpdart/fpdart.dart';

import '../../constants/network_constants.dart';
import '../../core/failure.dart';
import '../../core/type_defs.dart';
import '../../core/utility/validators.dart';
import '../../modals/benchmark_config.dart';
import '../../modals/benchmark_result.dart';
import '../../modals/tcp_result.dart';
import '../../modals/udp_result.dart';
import '../networking/delay_policy.dart';
import '../networking/i_tcp_client.dart';
import '../networking/i_tcp_server.dart';
import '../networking/i_udp_client.dart';
import '../networking/i_udp_server.dart';
import '../networking/tcp_client.dart';
import '../networking/tcp_server.dart';
import '../networking/udp_client.dart';
import '../networking/udp_server.dart';
import '../simulation/network_simulator.dart';
import 'i_benchmark_service.dart';
import 'metrics_service.dart';

typedef TcpServerFactory = ITcpServer Function(
  DelayPolicy delay,
  IUdpServer control,
);

class BenchmarkService implements IBenchmarkService {
  final NetworkSimulator simulator;
  final MetricsService metrics;
  final ITcpClient Function() tcpClient;
  final IUdpClient Function() udpClient;
  final IUdpServer Function() udpServer;
  final TcpServerFactory tcpServer;
  final _events = StreamController<BenchmarkProgress>.broadcast(sync: true);
  bool _busy = false;

  BenchmarkService({
    this.simulator = const NetworkSimulator(),
    this.metrics = const MetricsService(),
    this.tcpClient = TcpClient.new,
    this.udpClient = UdpClient.new,
    this.udpServer = UdpServer.new,
    this.tcpServer = _createTcp,
  });

  static ITcpServer _createTcp(DelayPolicy delay, IUdpServer control) =>
      TcpServer(delayPolicy: delay, controlHandler: control);

  @override
  Stream<BenchmarkProgress> get progress => _events.stream;

  void dispose() => unawaited(_events.close());

  @override
  FutureEither<BenchmarkResult> run(
    BenchmarkConfig config,
    CancelToken token,
  ) async {
    if (_busy) return left(const Failure('A benchmark is already running.'));
    final problem = Validators.validateConfig(config).getLeft().toNullable();
    if (problem != null) return left(problem);
    _busy = true;
    final clock = Stopwatch()..start();
    final udp = udpServer();
    final tcp = tcpServer(simulator.delay(config.simulation), udp);
    final sender = tcpClient();
    final datagrams = udpClient();
    final cancellation = token.onCancel.listen((_) {
      unawaited(sender.cancel());
      unawaited(datagrams.cancel());
    });
    final tcpRuns = <TcpResult>[];
    final udpRuns = <UdpResult>[];
    final protocols = config.protocol;
    final stages =
        (config.repetitions + 1) *
        ((protocols.includesTcp ? 1 : 0) + (protocols.includesUdp ? 1 : 0));
    var finished = 0;
    var tcpMetrics = AggregateMetrics.empty;
    var udpMetrics = AggregateMetrics.empty;
    void report(String phase, int run) {
      if (_events.isClosed) return;
      _events.add(
        BenchmarkProgress(
          phase,
          run,
          100 * finished / stages,
          tcpOnline: tcp.boundPort != null,
          udpOnline: udp.boundPort != null,
          tcp: tcpMetrics,
          udp: udpMetrics,
        ),
      );
    }

    T value<T>(Either<Failure, T> outcome) =>
        outcome.fold((f) => throw f, (v) => v);
    late Either<Failure, BenchmarkResult> outcome;
    try {
      token.check();
      report('Starting listeners', 0);
      if (protocols.includesUdp) {
        value(await udp.start(port: config.udpPort));
        token.check();
      }
      value(await tcp.start(port: config.tcpPort));
      final local = config.copyWith(host: NetworkConstants.defaultHost);
      final warmUp = local.copyWith(
        rttProbes: 1,
        packetCount: 2,
        tcpPayloadBytes: 1024,
      );
      for (var run = 0; run <= config.repetitions; run++) {
        final warming = run == 0;
        final workload = warming ? warmUp : local;
        if (protocols.includesTcp) {
          token.check();
          report(warming ? 'Warming up TCP' : 'Measuring TCP', run);
          token.check();
          final sample = value(
            await sender.run(workload, runIndex: run, experimentId: run + 1),
          );
          if (!warming) {
            tcpRuns.add(sample);
            tcpMetrics = metrics.tcp(tcpRuns);
          }
          finished++;
        }
        if (protocols.includesUdp) {
          token.check();
          report(warming ? 'Warming up UDP' : 'Measuring UDP', run);
          token.check();
          final sample = value(
            await datagrams.run(
              workload,
              runIndex: run,
              experimentId: run + 1,
              collectionWindow: Duration(
                milliseconds: min(100, workload.timeoutMs ~/ 4),
              ),
            ),
          );
          if (!warming) {
            udpRuns.add(sample);
            udpMetrics = metrics.udp(udpRuns);
          }
          finished++;
        }
      }
      token.check();
      report('Finishing', config.repetitions);
      final completed = DateTime.now().toUtc();
      outcome = right(
        BenchmarkResult(
          id: '${completed.microsecondsSinceEpoch}-${Random.secure().nextInt(0x100000000)}',
          completedAt: completed,
          config: local,
          totalSeconds:
              clock.elapsedMicroseconds / Duration.microsecondsPerSecond,
          tcpRuns: List.unmodifiable(tcpRuns),
          udpRuns: List.unmodifiable(udpRuns),
          tcpAggregate: tcpMetrics,
          udpAggregate: udpMetrics,
        ),
      );
    } on Failure catch (failure) {
      outcome = left(failure);
    } on Object catch (error) {
      outcome = left(Failure('Benchmark failed: $error', cause: error));
    } finally {
      await cancellation.cancel();
      try {
        final cleanup = await Future.wait([tcp.stop(), udp.stop()]);
        for (final stopped in cleanup) {
          stopped.fold((failure) => outcome = left(failure), (_) {});
        }
      } on Object catch (error) {
        outcome = left(
          Failure('Listener cleanup failed: $error', cause: error),
        );
      } finally {
        clock.stop();
        _busy = false;
      }
    }
    return token.isCancelled
        ? left(const Failure('Benchmark cancelled.'))
        : outcome;
  }
}
