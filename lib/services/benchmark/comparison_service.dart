import '../../constants/app_constants.dart';
import '../../core/utility/formatters.dart';
import '../../modals/benchmark_result.dart';

class ComparisonService {
  const ComparisonService();

  List<String> insights(List<BenchmarkResult> results) {
    if (results.isEmpty) return const [];
    final notes = <String>[];
    for (final protocol in ['TCP', 'UDP']) {
      final points = [
        for (var index = 0; index < results.length; index++)
          if (protocol == 'TCP' ? results[index].hasTcp : results[index].hasUdp)
            (
              index + 1,
              protocol == 'TCP'
                  ? results[index].tcpAggregate
                  : results[index].udpAggregate,
            ),
      ];
      if (points.isEmpty) continue;
      final best = points.reduce(
        (a, b) => a.$2.throughputMbps >= b.$2.throughputMbps ? a : b,
      );
      notes.add(
        'Experiment ${best.$1} measured ${Formatters.mbps(best.$2.throughputMbps)}'
        ' of $protocol received payload throughput${points.length > 1 ? ', the highest among the selected $protocol results' : ''}.',
      );
    }
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      if (result.hasTcp && result.hasUdp) {
        final difference =
            result.tcpAggregate.throughputMbps -
            result.udpAggregate.throughputMbps;
        notes.add(
          difference == 0
              ? 'Experiment ${i + 1} measured equal TCP and UDP received throughput.'
              : 'Experiment ${i + 1} measured ${Formatters.mbps(difference.abs())} higher received throughput for ${difference > 0 ? 'TCP' : 'UDP'}.',
        );
      }
      if (result.hasUdp) {
        notes.add(
          'Experiment ${i + 1} received ${Formatters.percent(result.udpAggregate.deliveryPercent)}'
          ' of UDP datagrams uniquely with ${Formatters.percent(result.config.simulation.lossPercent)} simulated discard configured.',
        );
      }
    }
    return [
      ...notes,
      AppConstants.loopbackDisclaimer,
      'Delay affects server RTT echoes. Simulated UDP discard models application loss only. TCP delivery measures acknowledged payload bytes. Send-rate caps apply at the sender.',
    ];
  }
}
