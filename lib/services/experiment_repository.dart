import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/failure.dart';
import '../core/type_defs.dart';
import '../modals/benchmark_config.dart';
import '../modals/benchmark_result.dart';
import '../modals/experiment_model.dart';
import '../modals/tcp_result.dart';
import '../modals/udp_result.dart';
import 'database/database_service.dart';

class ExperimentSummary {
  final String id;
  final String name;
  final DateTime createdAt;
  final BenchmarkConfig config;
  const ExperimentSummary(this.id, this.name, this.createdAt, this.config);
}

abstract interface class IExperimentRepository {
  FutureEitherVoid save(ExperimentModel experiment);
  FutureEither<List<ExperimentSummary>> list();
  FutureEither<ExperimentModel> get(String id);
  FutureEither<List<ExperimentModel>> loadMultiple(Iterable<String> ids);
  FutureEitherVoid delete(String id);
  FutureEitherVoid clear();
}

class ExperimentRepository implements IExperimentRepository {
  final DatabaseService database;
  const ExperimentRepository(this.database);

  FutureEither<T> _withDb<T>(
    String action,
    Future<T> Function(Database) operation,
  ) => database.logger.guard(action, () async {
    final db = (await database.init()).fold((f) => throw f, (db) => db);
    return operation(db);
  });

  @override
  FutureEitherVoid save(ExperimentModel experiment) => _withDb(
    'Save experiment',
    (db) => db.transaction((tx) async {
      final result = experiment.result;
      if (experiment.name.trim().isEmpty) {
        throw const Failure('Enter an experiment name.');
      }
      await tx.insert('experiments', {
        'id': experiment.id,
        'name': experiment.name.trim(),
        'created_us': experiment.createdAt.microsecondsSinceEpoch,
        'notes': experiment.notes,
        'config': jsonEncode(result.config.toMap()),
        'result_id': result.id,
        'completed_us': result.completedAt.microsecondsSinceEpoch,
        'total_seconds': result.totalSeconds,
        'tcp_aggregate': jsonEncode(result.tcpAggregate.toMap()),
        'udp_aggregate': jsonEncode(result.udpAggregate.toMap()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      // REPLACE cascades old run rows. The entire snapshot commits atomically.
      for (final run in result.tcpRuns) {
        await _saveRun(tx, experiment.id, 'tcp', run.runIndex, run.toMap());
      }
      for (final run in result.udpRuns) {
        await _saveRun(tx, experiment.id, 'udp', run.runIndex, run.toMap());
      }
    }),
  );

  Future<void> _saveRun(
    Transaction tx,
    String id,
    String protocol,
    int index,
    Map<String, Object?> data,
  ) async {
    await tx.insert('runs', {
      'experiment_id': id,
      'protocol': protocol,
      'run_index': index,
      'measurement': jsonEncode(data),
    });
  }

  @override
  FutureEither<List<ExperimentSummary>> list() =>
      _withDb('List experiments', (db) async {
        final rows = await db.query(
          'experiments',
          columns: ['id', 'name', 'created_us', 'config'],
          orderBy: 'created_us DESC, id ASC',
        );
        return List.unmodifiable(
          rows.map(
            (row) => ExperimentSummary(
              row['id']! as String,
              row['name']! as String,
              _date(row['created_us']),
              BenchmarkConfig.fromMap(_map(row['config'])),
            ),
          ),
        );
      });

  static DateTime _date(Object? us) =>
      DateTime.fromMicrosecondsSinceEpoch(us! as int, isUtc: true);
  static Map<String, dynamic> _map(Object? json) =>
      jsonDecode(json! as String) as Map<String, dynamic>;

  Future<ExperimentModel> _load(Transaction tx, String id) async {
    final rows = await tx.query(
      'experiments',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) {
      throw const Failure('The selected experiment no longer exists.');
    }
    final row = rows.single;
    final runs = await tx.query(
      'runs',
      where: 'experiment_id = ?',
      whereArgs: [id],
      orderBy: 'run_index',
    );
    return ExperimentModel(
      id: id,
      name: row['name']! as String,
      createdAt: _date(row['created_us']),
      notes: row['notes']! as String,
      result: BenchmarkResult(
        id: row['result_id']! as String,
        completedAt: _date(row['completed_us']),
        totalSeconds: (row['total_seconds']! as num).toDouble(),
        config: BenchmarkConfig.fromMap(_map(row['config'])),
        tcpAggregate: AggregateMetrics.fromMap(_map(row['tcp_aggregate'])),
        udpAggregate: AggregateMetrics.fromMap(_map(row['udp_aggregate'])),
        tcpRuns: List.unmodifiable([
          for (final run in runs)
            if (run['protocol'] == 'tcp')
              TcpResult.fromMap(_map(run['measurement'])),
        ]),
        udpRuns: List.unmodifiable([
          for (final run in runs)
            if (run['protocol'] == 'udp')
              UdpResult.fromMap(_map(run['measurement'])),
        ]),
      ),
    );
  }

  @override
  FutureEither<ExperimentModel> get(String id) =>
      _withDb('Load experiment', (db) => db.transaction((tx) => _load(tx, id)));

  @override
  FutureEither<List<ExperimentModel>> loadMultiple(Iterable<String> ids) =>
      _withDb(
        'Load comparison',
        (db) => db.transaction((tx) async {
          return List.unmodifiable([
            for (final id in ids.toSet()) await _load(tx, id),
          ]);
        }),
      );

  @override
  FutureEitherVoid delete(String id) =>
      _withDb('Delete experiment', (db) async {
        await db.delete('experiments', where: 'id = ?', whereArgs: [id]);
      });

  @override
  FutureEitherVoid clear() => _withDb('Clear experiments', (db) async {
    await db.delete('experiments');
  });
}
