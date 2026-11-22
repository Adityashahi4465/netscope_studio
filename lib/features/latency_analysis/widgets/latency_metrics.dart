import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/metric_card.dart';
import '../../../widgets/metric_grid.dart';
import '../controller/latency_controller.dart';

class LatencyMetrics extends StatelessWidget {
  final LatencyReport report;
  const LatencyMetrics(this.report, {super.key});
  @override
  Widget build(BuildContext context) {
    final data = report.metrics;
    return MetricGrid([
      for (final metric in <(String, double)>[
        ('Minimum RTT', data.minRttMs),
        ('Average RTT', data.avgRttMs),
        ('Maximum RTT', data.maxRttMs),
        ('Median RTT', data.medianRttMs),
        ('p95 RTT', data.p95RttMs),
      ])
        MetricCard(
          title: metric.$1,
          value: data.sampleCount == 0
              ? '—'
              : '${metric.$2.toStringAsFixed(3)} ms',
          detail: '${data.sampleCount} successful probes',
          color: AppColors.forProtocol(report.protocol.name),
        ),
      MetricCard(
        title: 'Mean absolute RTT variation',
        value: data.variationPairs == 0
            ? '—'
            : '${data.meanAbsRttVariationMs.toStringAsFixed(3)} ms',
        detail: '${data.variationPairs} consecutive successful sample pairs',
        color: AppColors.primaryLight,
      ),
      MetricCard(
        title: 'Probe timeouts',
        value: '${data.timeouts}',
        detail: 'RTT responses missing before timeout',
        color: AppColors.warning,
      ),
    ]);
  }
}
