import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../constants/app_constants.dart';
import '../../core/type_defs.dart';
import '../../core/utility/logger.dart';

class DatabaseService {
  final String? path;
  final AppLogger logger;
  Future<Database>? _opening;

  DatabaseService({this.path, this.logger = const AppLogger()});

  FutureEither<Database> init() =>
      logger.guard('Open experiment database', () async {
        final pending = _opening ??= _open();
        try {
          return await pending;
        } on Object {
          if (identical(_opening, pending)) _opening = null;
          rethrow;
        }
      });

  Future<Database> _open() async {
    sqfliteFfiInit();
    final location =
        path ??
        p.join(
          (await getApplicationSupportDirectory()).path,
          AppConstants.databaseName,
        );
    return databaseFactoryFfi.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: AppConstants.databaseVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: _migrate,
      ),
    );
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    if (from < 1 && to >= 1) {
      await db.execute('''CREATE TABLE experiments (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, created_us INTEGER NOT NULL,
        notes TEXT NOT NULL, config TEXT NOT NULL, result_id TEXT NOT NULL,
        completed_us INTEGER NOT NULL, total_seconds REAL NOT NULL,
        tcp_aggregate TEXT NOT NULL, udp_aggregate TEXT NOT NULL
      )''');
      await db.execute(
        'CREATE INDEX experiments_date ON experiments(created_us DESC)',
      );
      await db.execute('''CREATE TABLE runs (
        experiment_id TEXT NOT NULL REFERENCES experiments(id) ON DELETE CASCADE,
        protocol TEXT NOT NULL CHECK(protocol IN ('tcp', 'udp')),
        run_index INTEGER NOT NULL, measurement TEXT NOT NULL,
        PRIMARY KEY(experiment_id, protocol, run_index)
      )''');
    }
  }

  FutureEitherVoid close() =>
      logger.guard('Close experiment database', () async {
        final pending = _opening;
        if (pending != null) {
          await (await pending).close();
          if (identical(_opening, pending)) _opening = null;
        }
      });
}
