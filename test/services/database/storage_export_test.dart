import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:path/path.dart' as p;

import '../../../lib/core/failure.dart';
import '../../../lib/core/utility/csv_exporter.dart';
import '../../../lib/modals/benchmark_config.dart';
import '../../../lib/modals/benchmark_result.dart';
import '../../../lib/modals/experiment_model.dart';
import '../../../lib/modals/packet_record.dart';
import '../../../lib/modals/tcp_result.dart';
import '../../../lib/modals/udp_result.dart';
import '../../../lib/services/benchmark/metrics_service.dart';
import '../../../lib/services/database/database_service.dart';
import '../../../lib/services/experiment_repository.dart';

T value<T>(Either<Failure, T> result) =>
    result.fold((f) => fail(f.message), (v) => v);

ExperimentModel experiment(String id, int day) {
  final time = DateTime.utc(2026, 1, day);
  const tcp = [
    TcpResult(
      runIndex: 1,
      rttSamplesMs: [2.5, 3],
      bytesAcked: 2048,
      bytesSent: 2048,
      transferSeconds: 1,
      completed: true,
    ),
  ];
  const udp = [
    UdpResult(
      runIndex: 1,
      rttSamplesMs: [4],
      packetsSent: 1,
      uniqueReceived: 1,
      bytesReceived: 988,
      transferSeconds: 1,
      packetRecords: [
        PacketRecord(
          sequence: 0,
          status: PacketStatus.delivered,
          sizeBytes: 1024,
        ),
      ],
    ),
  ];
  const metrics = MetricsService();
  return ExperimentModel(
    id: id,
    name: 'Run $day',
    createdAt: time,
    result: BenchmarkResult(
      id: id,
      config: const BenchmarkConfig(),
      completedAt: time,
      totalSeconds: 2,
      tcpRuns: tcp,
      udpRuns: udp,
      tcpAggregate: metrics.tcp(tcp),
      udpAggregate: metrics.udp(udp),
    ),
  );
}

void main() {
  late Directory folder;
  late DatabaseService database;
  late ExperimentRepository repo;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('netscope-storage-');
    database = DatabaseService(path: p.join(folder.path, 'lab.db'));
    repo = ExperimentRepository(database);
  });
  tearDown(() async {
    value(await database.close());
    await folder.delete(recursive: true);
  });

  test('SQLite CRUD, stable selection order, raw runs, restart and cascading delete', () async {
    final first = experiment('a', 1);
    final second = experiment('b', 2);
    await Future.wait([repo.save(first), repo.save(second)])
        .then((r) => r.forEach(value));
    expect(value(await repo.list()).map((e) => e.id), ['b', 'a']);
    expect(value(await repo.loadMultiple(['a', 'b', 'a'])).map((e) => e.id), [
      'a',
      'b',
    ]);
    value(await repo.save(first.copyWith(name: 'Renamed')));
    value(await database.close());
    final restored = value(await repo.get('a'));
    expect(restored.name, 'Renamed');
    expect(restored.result.toMap(), first.result.toMap());
    final db = value(await database.init());
    expect(
      (await db.rawQuery('PRAGMA user_version')).single['user_version'],
      1,
    );
    value(await repo.delete('a'));
    expect((await repo.get('a')).isLeft(), isTrue);
    expect((await repo.loadMultiple(['b', 'a'])).isLeft(), isTrue);
    expect(await db.query('runs'), hasLength(2));
    value(await repo.clear());
    expect(value(await repo.list()), isEmpty);
    expect(await db.query('runs'), isEmpty);
  });

  test('failed multi-run save rolls back the replaced snapshot', () async {
    final original = experiment('same', 1);
    value(await repo.save(original));
    final corrupted = original.result.toMap();
    corrupted['tcpRuns'] = List.filled(
      2,
      original.result.tcpRuns.first.toMap(),
    );
    final invalid = ExperimentModel(
      id: original.id,
      name: 'Broken',
      createdAt: original.createdAt,
      result: BenchmarkResult.fromMap(corrupted),
    );
    expect((await repo.save(invalid)).isLeft(), isTrue);
    expect(value(await repo.get(original.id)).toMap(), original.toMap());
  });

  test(
    'CSV contains config, simulated inputs, measured runs and ordered raw RTTs',
    () async {
      final results = [experiment('a,"b', 1).result, experiment('c', 2).result];
      const exporter = CsvExporter();
      final file = value(await exporter.export(results, directory: folder))!;
      final lines = const LineSplitter().convert(await file.readAsString());
      expect(lines.first, contains('"result_id","section"'));
      expect(
        lines,
        contains('"a,""b","simulated","","","","lossPercent","0.0"'),
      );
      expect(lines, contains('"c","raw RTT","TCP","1","2","RTT (ms)","3.0"'));
      expect(
        lines,
        contains('"c","measured run","UDP","1","","bytesReceived","988"'),
      );
      expect(
        lines.any((l) => l.contains('"config"') && l.contains('"tcpPort"')),
        isTrue,
      );
      expect(
        (await exporter.export(
          results,
          directory: Directory(p.join(folder.path, 'missing')),
        )).isLeft(),
        isTrue,
      );
    },
  );
}
