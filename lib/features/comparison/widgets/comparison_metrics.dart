import 'package:flutter/material.dart';

import '../../../core/utility/formatters.dart';
import '../../../modals/benchmark_result.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_style.dart';
import '../../../widgets/metric_card.dart';
import '../controller/comparison_report.dart';

class ComparisonMetrics extends StatelessWidget {
  final ComparisonReport report;
  const ComparisonMetrics(this.report, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppDimensions.md,
    children: [
      for (var i = 0; i < report.experiments.length; i++) ...[
        Text(
          'E${i + 1} · ${report.experiments[i].name}',
          style: AppTextStyle.h3,
        ),
        Wrap(
          spacing: AppDimensions.md,
          runSpacing: AppDimensions.md,
          children: [
            if (report.experiments[i].result.hasTcp)
              _card(
                'TCP',
                report.experiments[i].result.tcpAggregate,
                AppColors.tcp,
              ),
            if (report.experiments[i].result.hasUdp)
              _card(
                'UDP',
                report.experiments[i].result.udpAggregate,
                AppColors.udp,
              ),
          ],
        ),
      ],
    ],
  );

  Widget _card(String name, AggregateMetrics m, Color color) => MetricCard(
    title: '$name received throughput',
    value: Formatters.mbps(m.throughputMbps),
    color: color,
    detail:
        'Avg RTT ${m.sampleCount == 0 ? '—' : Formatters.ms(m.avgRttMs)}\n'
        'Mean absolute RTT variation ${m.variationPairs == 0 ? '—' : Formatters.ms(m.meanAbsRttVariationMs)}\n'
        'Delivered ${Formatters.percent(m.deliveryPercent)} · ${m.timeouts} probe timeouts',
  );
}
