import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/protocol_type.dart';
import '../../../modals/benchmark_config.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_style.dart';
import '../../../widgets/analysis_run_controls.dart';
import '../../../widgets/custom_dropdown.dart';
import '../../dashboard/controller/config_field.dart';
import '../controller/latency_controller.dart';
import '../widgets/latency_charts.dart';
import '../widgets/latency_metrics.dart';

class LatencyAnalysisView extends ConsumerWidget {
  const LatencyAnalysisView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(latencyReportProvider);
    final actions = ref.read(latencyControllerProvider.notifier);
    return ListView(
      padding: AppDimensions.pagePadding,
      children: [
        Text('Latency analysis', style: AppTextStyle.display),
        const SizedBox(height: AppDimensions.sm),
        Text(
          'Inspect successful RTT probes, their distribution, and response timeouts.',
          style: AppTextStyle.body,
        ),
        const SizedBox(height: AppDimensions.xl),
        const AnalysisRunControls(
          preset: BenchmarkPreset.latencyJitter,
          fields: [
            ConfigField.probes,
            ConfigField.repetitions,
            ConfigField.delay,
            ConfigField.jitter,
            ConfigField.timeout,
            ConfigField.seed,
          ],
        ),
        const SizedBox(height: AppDimensions.xl),
        CustomDropdown(
          label: 'RTT transport',
          value: report.protocol,
          items: const [ProtocolType.tcp, ProtocolType.udp],
          title: (p) => p.label,
          onChanged: actions.protocol,
        ),
        const SizedBox(height: AppDimensions.lg),
        if (report.runs.isEmpty)
          Text(
            'No measured ${report.protocol.label} run available. Load a setup and select Start above.',
            style: AppTextStyle.body,
          )
        else ...[
          CustomDropdown(
            label: 'Measured repetition',
            value: report.runIndex,
            items: report.runs,
            title: (i) => 'Repetition ${report.runs.indexOf(i) + 1}',
            onChanged: actions.run,
          ),
          const SizedBox(height: AppDimensions.lg),
          LatencyMetrics(report),
          const SizedBox(height: AppDimensions.xl),
          if (report.samples.isEmpty)
            Text(
              'No successful RTT samples. Timeouts are shown above; no latency values are fabricated.',
              style: AppTextStyle.body,
            )
          else
            LatencyCharts(report),
        ],
      ],
    );
  }
}
