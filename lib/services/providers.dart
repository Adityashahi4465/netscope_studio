import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utility/csv_exporter.dart';
import '../core/utility/logger.dart';
import 'benchmark/benchmark_service.dart';
import 'benchmark/comparison_service.dart';
import 'benchmark/i_benchmark_service.dart';
import 'benchmark/metrics_service.dart';
import 'database/database_service.dart';
import 'experiment_repository.dart';
import 'networking/i_tcp_client.dart';
import 'networking/i_udp_client.dart';
import 'networking/i_udp_server.dart';
import 'networking/tcp_client.dart';
import 'networking/tcp_server.dart';
import 'networking/udp_client.dart';
import 'networking/udp_server.dart';
import 'simulation/network_simulator.dart';

final loggerProvider = Provider((ref) => const AppLogger());
final simulatorProvider = Provider((ref) => const NetworkSimulator());
final metricsProvider = Provider((ref) => const MetricsService());
final comparisonServiceProvider = Provider((ref) => const ComparisonService());
final tcpClientFactoryProvider = Provider<ITcpClient Function()>(
  (ref) => TcpClient.new,
);
final udpClientFactoryProvider = Provider<IUdpClient Function()>(
  (ref) => UdpClient.new,
);
final udpServerFactoryProvider = Provider<IUdpServer Function()>(
  (ref) => UdpServer.new,
);
final tcpServerFactoryProvider = Provider<TcpServerFactory>(
  (ref) =>
      (delay, udp) => TcpServer(delayPolicy: delay, controlHandler: udp),
);
final benchmarkServiceProvider = Provider<IBenchmarkService>((ref) {
  final service = BenchmarkService(
    simulator: ref.watch(simulatorProvider),
    metrics: ref.watch(metricsProvider),
    tcpClient: ref.watch(tcpClientFactoryProvider),
    udpClient: ref.watch(udpClientFactoryProvider),
    udpServer: ref.watch(udpServerFactoryProvider),
    tcpServer: ref.watch(tcpServerFactoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
final databaseProvider = Provider((ref) {
  final db = DatabaseService(logger: ref.watch(loggerProvider));
  ref.onDispose(() => unawaited(db.close()));
  return db;
});
final experimentRepositoryProvider = Provider<IExperimentRepository>(
  (ref) => ExperimentRepository(ref.watch(databaseProvider)),
);
final csvExporterProvider = Provider(
  (ref) => CsvExporter(logger: ref.watch(loggerProvider)),
);
