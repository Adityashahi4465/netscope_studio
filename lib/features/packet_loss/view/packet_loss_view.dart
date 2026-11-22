import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../modals/benchmark_config.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_style.dart';
import '../../../widgets/analysis_run_controls.dart';
import '../../../widgets/custom_dropdown.dart';
import '../../dashboard/controller/config_field.dart';
import '../controller/packet_loss_controller.dart';
import '../widgets/delivery_map.dart';
import '../widgets/loss_metrics.dart';

class PacketLossView extends ConsumerWidget {
  const PacketLossView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(packetLossReportProvider);
    return ListView(
      padding: AppDimensions.pagePadding,
      children: [
        Text('UDP packet loss', style: AppTextStyle.display),
        const SizedBox(height: AppDimensions.sm),
        Text(
          'Application-level simulated loss; not comparable to TCP loss recovery.',
          style: AppTextStyle.bodyStrong,
        ),
        const SizedBox(height: AppDimensions.xl),
        const AnalysisRunControls(
          preset: BenchmarkPreset.udpLoss,
          fields: [
            ConfigField.loss,
            ConfigField.packets,
            ConfigField.datagram,
            ConfigField.repetitions,
            ConfigField.probes,
            ConfigField.seed,
          ],
        ),
        const SizedBox(height: AppDimensions.xl),
        if (report.run == null)
          Text(
            'No measured UDP run available. Load the UDP loss setup and select Start.',
            style: AppTextStyle.body,
          )
        else ...[
          CustomDropdown(
            label: 'Audited UDP repetition',
            value: report.run!.runIndex,
            items: report.runs,
            title: (i) => 'Repetition ${report.runs.indexOf(i) + 1}',
            onChanged: ref.read(packetLossControllerProvider.notifier).run,
          ),
          const SizedBox(height: AppDimensions.lg),
          LossMetrics(report),
          const SizedBox(height: AppDimensions.xl),
          DeliveryMap(report),
        ],
      ],
    );
  }
}
