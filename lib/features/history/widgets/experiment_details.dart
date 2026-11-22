import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utility/formatters.dart';
import '../../../modals/experiment_model.dart';
import '../../../routes/route_utils.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_style.dart';
import '../../../widgets/metric_card.dart';
import '../../../widgets/metric_grid.dart';
import '../controller/history_controller.dart';

class ExperimentDetails extends ConsumerWidget {
  final ExperimentModel experiment;
  const ExperimentDetails(this.experiment, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = experiment.result;
    final simulation = result.config.simulation;
    return Dialog(
      child: SizedBox(
        width: AppDimensions.breakpointCompact,
        child: SingleChildScrollView(
          padding: AppDimensions.cardPaddingLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppDimensions.lg,
            children: [
              Text(experiment.name, style: AppTextStyle.h2),
              SelectableText(
                'ID: ${experiment.id}\nSaved ${Formatters.dateTime(experiment.createdAt.toLocal())}\n'
                '${result.config.protocol.label} · ${result.config.repetitions} repetitions · ${result.totalSeconds.toStringAsFixed(3)} s',
              ),
              if (experiment.notes.isNotEmpty)
                Text(experiment.notes, style: AppTextStyle.body),
              Text('Simulated settings', style: AppTextStyle.h3),
              Text(
                'Application UDP discard: ${simulation.lossPercent}% · RTT echo delay: ${simulation.delayMs} ms '
                '± ${simulation.jitterMs} ms · application send cap: ${simulation.rateLimitMbps} Mbps '
                '(0 = unlimited) · seed: ${simulation.seed ?? 'unseeded'}',
                style: AppTextStyle.body,
              ),
              MetricGrid([
                if (result.hasTcp)
                  MetricCard(
                    title: 'TCP measured throughput',
                    value:
                        '${result.tcpAggregate.throughputMbps.toStringAsFixed(3)} Mbps',
                    detail: 'Acknowledged application payload',
                    color: AppColors.tcp,
                  ),
                if (result.hasUdp)
                  MetricCard(
                    title: 'UDP measured goodput',
                    value:
                        '${result.udpAggregate.throughputMbps.toStringAsFixed(3)} Mbps',
                    detail: 'Unique accepted application payload',
                    color: AppColors.udp,
                  ),
              ]),
              Text('Measured repetitions', style: AppTextStyle.h3),
              for (final (index, run) in result.tcpRuns.indexed)
                Text(
                  'TCP ${index + 1}: ${run.bytesAcked}/${run.bytesSent} bytes acknowledged · '
                  '${run.rttSamplesMs.length} RTT samples · ${run.probeTimeouts} probe timeouts',
                  style: AppTextStyle.body,
                ),
              for (final (index, run) in result.udpRuns.indexed)
                Text(
                  'UDP ${index + 1}: ${run.uniqueReceived}/${run.packetsSent} unique received · '
                  '${run.droppedBySimulation} simulated drops · ${run.unexplainedLoss} unexplained missing · '
                  '${run.duplicates} duplicates · ${run.probeTimeouts} probe timeouts',
                  style: AppTextStyle.body,
                ),
              const Text(
                'Application-level simulated loss; not comparable to TCP loss recovery.',
              ),
              Wrap(
                spacing: AppDimensions.sm,
                runSpacing: AppDimensions.sm,
                children: [
                  OutlinedButton(
                    onPressed: ref.watch(historyControllerProvider).busy
                        ? null
                        : () => ref
                              .read(historyControllerProvider.notifier)
                              .export([experiment.id]),
                    child: const Text('Export detail CSV'),
                  ),
                  OutlinedButton(
                    onPressed:
                        result.udpRuns.any((r) => r.packetRecords.isNotEmpty)
                        ? () {
                            RouteUtils.close(context);
                            RouteUtils.replay(context, result);
                          }
                        : null,
                    child: const Text('Replay recorded UDP requests'),
                  ),
                  TextButton(
                    onPressed: () => RouteUtils.close(context),
                    child: const Text('Close details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
