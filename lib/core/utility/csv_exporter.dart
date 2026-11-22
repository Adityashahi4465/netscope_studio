import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../modals/benchmark_result.dart';
import '../failure.dart';
import '../type_defs.dart';
import 'logger.dart';

class CsvExporter {
  final AppLogger logger;
  const CsvExporter({this.logger = const AppLogger()});

  /// A null success means the user dismissed the directory chooser.
  FutureEither<File?> export(
    List<BenchmarkResult> results, {
    Directory? directory,
  }) => logger.guard('Export CSV', () async {
    if (results.isEmpty) {
      throw const Failure('Select a measured result to export.');
    }
    if (directory == null) {
      final uri = await FilePicker.pickDirectory(
        dialogTitle: 'Export benchmark CSV',
        initialDirectory: (await getApplicationDocumentsDirectory()).path,
      );
      if (uri == null) return null;
      directory = Directory.fromUri(uri);
    }
    final prefix = results.length == 1 ? 'benchmark' : 'comparison';
    final suffix =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x100000000)}';
    final file = File(p.join(directory!.path, 'netscope-$prefix-$suffix.csv'));
    final temporary = File('${file.path}.part');
    await temporary.create(exclusive: true);
    try {
      final sink = temporary.openWrite();
      try {
        void row(List<Object?> data) =>
            sink.write('${data.map(_escape).join(',')}\r\n');
        row([
          'result_id',
          'section',
          'protocol',
          'repetition',
          'sample',
          'metric',
          'value',
        ]);
        for (final result in results) {
          void metric(
            String section,
            String key,
            Object? value, {
            String protocol = '',
            Object run = '',
            Object sample = '',
          }) => row([result.id, section, protocol, run, sample, key, value]);
          metric(
            'measured',
            'completedAt',
            result.completedAt.toUtc().toIso8601String(),
          );
          metric('measured', 'totalSeconds', result.totalSeconds);
          for (final e in result.config.toMap().entries) {
            if (e.key != 'simulation') metric('config', e.key, e.value);
          }
          for (final e in result.config.simulation.toMap().entries) {
            metric('simulated', e.key, e.value);
          }
          void aggregate(String protocol, AggregateMetrics data) {
            for (final e in data.toMap().entries) {
              final key = e.key == 'meanAbsRttVariationMs'
                  ? 'mean absolute RTT variation (ms)'
                  : e.key;
              final missing =
                  (e.key.endsWith('RttMs') && data.sampleCount == 0) ||
                  (e.key == 'meanAbsRttVariationMs' &&
                      data.variationPairs == 0);
              metric(
                'measured aggregate',
                key,
                missing ? null : e.value,
                protocol: protocol,
              );
            }
          }

          if (result.hasTcp) aggregate('TCP', result.tcpAggregate);
          if (result.hasUdp) aggregate('UDP', result.udpAggregate);
          void run(
            String protocol,
            int index,
            Map<String, Object?> data,
            List<double> samples,
          ) {
            for (final e in data.entries) {
              if (e.key != 'runIndex' &&
                  e.key != 'rttSamplesMs' &&
                  e.key != 'packetRecords') {
                metric(
                  'measured run',
                  e.key,
                  e.value,
                  protocol: protocol,
                  run: index,
                );
              }
            }
            for (var i = 0; i < samples.length; i++) {
              metric(
                'raw RTT',
                'RTT (ms)',
                samples[i],
                protocol: protocol,
                run: index,
                sample: i + 1,
              );
            }
          }

          for (final r in result.tcpRuns) {
            run('TCP', r.runIndex, r.toMap(), r.rttSamplesMs);
          }
          for (final r in result.udpRuns) {
            run('UDP', r.runIndex, r.toMap(), r.rttSamplesMs);
          }
          await sink.flush();
        }
      } finally {
        await sink.close();
      }
      return await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  });

  static String _escape(Object? value) =>
      '"${(value?.toString() ?? '').replaceAll('"', '""')}"';
}
