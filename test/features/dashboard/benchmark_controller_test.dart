import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../lib/core/enums/benchmark_status.dart';
import '../../../lib/features/dashboard/controller/benchmark_controller.dart';
import '../../../lib/features/dashboard/controller/config_field.dart';
import '../../../lib/services/database/database_service.dart';
import '../../../lib/services/providers.dart';

void main() {
  test(
    'cockpit runs real sockets, saves the measured result and resets',
    () async {
      final dir = await Directory.systemTemp.createTemp('netscope-cockpit-');
      final db = DatabaseService(path: p.join(dir.path, 'test.db'));
      final scope = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        scope.dispose();
        await db.close();
        await dir.delete(recursive: true);
      });
      final controller = scope.read(benchmarkControllerProvider.notifier);
      final port = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final udp = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      controller.edit(ConfigField.tcpPort, port.port.toString());
      controller.edit(ConfigField.udpPort, udp.port.toString());
      udp.close();
      await port.close();
      controller.edit(ConfigField.packets, '10');
      controller.edit(ConfigField.probes, '1');
      await controller.start();
      final done = scope.read(benchmarkControllerProvider);
      expect(done.status, BenchmarkStatus.completed, reason: done.error);
      expect(done.tcp.runs, 1);
      expect(done.udp.runs, 1);
      expect(done.completedAt, isNotNull);
      await controller.save();
      final stored = await scope
          .read(experimentRepositoryProvider)
          .get(done.result!.id);
      expect(
        stored.fold((f) => fail(f.message), (e) => e.result.toMap()),
        done.result!.toMap(),
      );
      controller.reset();
      expect(scope.read(benchmarkControllerProvider).result, isNull);
      expect(
        scope.read(benchmarkControllerProvider).status,
        BenchmarkStatus.idle,
      );
    },
  );
}
