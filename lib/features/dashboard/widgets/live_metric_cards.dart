import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utility/formatters.dart';
import '../../../modals/benchmark_result.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../widgets/metric_card.dart';
import '../controller/benchmark_controller.dart';

class LiveMetricCards extends ConsumerWidget {
  const LiveMetricCards({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(benchmarkControllerProvider);
    Widget card(String name, AggregateMetrics m, Color color) => MetricCard(
      title: '$name received throughput',
      value: m.runs == 0 ? '—' : Formatters.mbps(m.throughputMbps),
      color: color,
      detail: m.runs == 0
          ? 'Awaiting measurement'
          : 'Avg RTT ${m.sampleCount == 0 ? '—' : Formatters.ms(m.avgRttMs)}'
                '  ·  ${Formatters.percent(m.deliveryPercent)} delivered',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.md,
      children: [
        if (state.config.protocol.includesTcp)
          card('TCP', state.tcp, AppColors.tcp),
        if (state.config.protocol.includesUdp)
          card('UDP', state.udp, AppColors.udp),
      ],
    );
  }
}
