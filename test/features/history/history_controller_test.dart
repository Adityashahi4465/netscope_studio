import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/enums/protocol_type.dart';
import '../../../lib/core/utility/csv_exporter.dart';
import '../../../lib/features/history/controller/history_controller.dart';
import '../../../lib/modals/benchmark_config.dart';
import '../../../lib/services/database/database_service.dart';
import '../../../lib/services/experiment_repository.dart';
import '../../support/experiment_fixture.dart';

void main() {
  test('history searches names/IDs and filters transports independently of selection', () {
    final time = DateTime.utc(2026, 11, 22);
    final items = [
      ExperimentSummary(
        'a',
        'Latency Alpha',
        time,
        const BenchmarkConfig(protocol: ProtocolType.tcp),
      ),
      ExperimentSummary(
        'b',
        'UDP Beta',
        time,
        const BenchmarkConfig(protocol: ProtocolType.udp),
      ),
      ExperimentSummary('c', 'Combined', time, const BenchmarkConfig()),
    ];
    expect(HistoryState(items: items, query: 'ALPHA').visible.single.id, 'a');
    expect(
      HistoryState(
        items: items,
        transport: HistoryTransport.tcp,
      ).visible.map((i) => i.id),
      ['a', 'c'],
    );
    expect(
      HistoryState(
        items: items,
        transport: HistoryTransport.udp,
      ).visible.map((i) => i.id),
      ['b', 'c'],
    );
    expect(
      HistoryState(
        items: items,
        transport: HistoryTransport.both,
      ).visible.single.id,
      'c',
    );
  });

  test('history loads, opens, deletes, clears and handles missing details through repository', () async {
    final folder = await Directory.systemTemp.createTemp('netscope-history-');
    final database = DatabaseService(path: '${folder.path}/test.db');
    final repository = ExperimentRepository(database);
    final first = experimentFixture(id: 'first');
    final second = experimentFixture(id: 'second');
    (await repository.save(first)).fold((f) => fail(f.message), (_) {});
    (await repository.save(second)).fold((f) => fail(f.message), (_) {});
    final controller = HistoryController(repository, const CsvExporter());
    addTearDown(() async {
      controller.dispose();
      await database.close();
      await folder.delete(recursive: true);
    });
    await controller.refresh();
    expect(controller.state.items, hasLength(2));
    controller.toggle('first');
    expect(controller.state.selected, {'first'});
    await controller.open('first');
    expect(
      controller.state.detail!.result.udpRuns.single.packetRecords,
      hasLength(300),
    );
    await controller.open('absent');
    expect(controller.state.error, isNotNull);
    await controller.delete('first');
    expect(controller.state.items.single.id, 'second');
    expect(controller.state.selected, isEmpty);
    expect(controller.state.busy, isFalse);
    await controller.clear();
    expect(controller.state.items, isEmpty);
    expect(controller.state.notice, 'History cleared.');
  });
}
