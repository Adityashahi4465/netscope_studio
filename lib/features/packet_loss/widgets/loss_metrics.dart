import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/metric_card.dart';
import '../../../widgets/metric_grid.dart';
import '../controller/packet_loss_controller.dart';

class LossMetrics extends StatelessWidget {
  final PacketLossReport report;
  const LossMetrics(this.report, {super.key});
  @override
  Widget build(BuildContext context) {
    final run = report.run!;
    return MetricGrid([
      MetricCard(
        title: 'Configured loss · simulated',
        value: '${report.configuredLoss.toStringAsFixed(1)}%',
        detail: 'Application discard probability',
        color: AppColors.warning,
      ),
      MetricCard(
        title: 'Observed UDP loss · measured',
        value: '${report.observedLoss.toStringAsFixed(1)}%',
        detail: 'Sent minus unique requests accepted by receiver',
        color: AppColors.udp,
      ),
      for (final metric in <(String, int, String)>[
        ('Sent', run.packetsSent, 'Numbered UDP datagrams'),
        (
          'Unique received',
          run.uniqueReceived,
          'Accepted requests from TCP audit',
        ),
        (
          'Dropped by simulation',
          run.droppedBySimulation,
          'Unique requests discarded in application',
        ),
        (
          'Unexplained loss',
          run.unexplainedLoss,
          'Missing requests not explained by simulation',
        ),
        (
          'Probe timeouts',
          run.probeTimeouts,
          'RTT echoes only; separate from bulk request loss',
        ),
        (
          'Duplicates',
          run.duplicates,
          'Extra accepted arrivals, not extra payload',
        ),
        (
          'Out of order',
          run.outOfOrder,
          'Unique arrivals below highest seen sequence',
        ),
      ])
        MetricCard(
          title: metric.$1,
          value: '${metric.$2}',
          detail: metric.$3,
          color: AppColors.udp,
        ),
    ]);
  }
}
