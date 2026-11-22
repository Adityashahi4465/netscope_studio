import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/app_loader.dart';
import '../../../common/custom_snackbar.dart';
import '../../../routes/route_utils.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_style.dart';
import '../../../widgets/chart_container.dart';
import '../controller/comparison_controller.dart';
import '../controller/comparison_report.dart';
import '../widgets/comparison_chart.dart';
import '../widgets/comparison_metrics.dart';
import '../widgets/experiment_picker.dart';

class ComparisonView extends ConsumerWidget {
  const ComparisonView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(comparisonControllerProvider);
    final actions = ref.read(comparisonControllerProvider.notifier);
    ref.listen(comparisonControllerProvider.select((s) => s.notice), (
      _,
      message,
    ) {
      if (message != null) CustomSnackbar.show(context, message);
    });
    if (state.loadingList) return const AppLoader('Loading saved experiments…');
    return ListView(
      padding: AppDimensions.pagePadding,
      children: [
        Text('TCP vs UDP comparison', style: AppTextStyle.display),
        const SizedBox(height: AppDimensions.md),
        Wrap(
          spacing: AppDimensions.sm,
          runSpacing: AppDimensions.sm,
          children: [
            OutlinedButton.icon(
              onPressed: state.exporting ? null : actions.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            OutlinedButton.icon(
              onPressed: state.report == null || state.exporting
                  ? null
                  : actions.export,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export CSV'),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.xl),
        if (state.error case final error?) SelectableText(error),
        if (state.available.isEmpty && state.error == null)
          ChartContainer(
            title: 'No saved experiments',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppDimensions.md,
              children: [
                const Text(
                  'Run a benchmark and save it to compare its measurements here.',
                ),
                TextButton(
                  onPressed: () => RouteUtils.go(context, LabRoute.dashboard),
                  child: const Text('Open benchmark cockpit'),
                ),
              ],
            ),
          )
        else if (state.available.isNotEmpty)
          ExperimentPicker(
            state.available,
            state.selected,
            state.exporting ? null : actions.toggle,
          ),
        const SizedBox(height: AppDimensions.xl),
        if (state.loadingResults)
          const AppLoader('Loading measurements…')
        else if (state.report case final report?) ...[
          ComparisonMetrics(report),
          const SizedBox(height: AppDimensions.xl),
          for (final metric in ComparisonMetric.values) ...[
            ComparisonChart(
              title: metric.label,
              unit: metric.unit,
              points: report.measurements[metric]!,
              footnotes: metric == ComparisonMetric.delivery
                  ? const [
                      'TCP uses acknowledged payload bytes. UDP uses uniquely received datagrams.',
                    ]
                  : const [],
            ),
            const SizedBox(height: AppDimensions.lg),
          ],
          ComparisonChart(
            title: 'Throughput per repetition',
            unit: 'Mbps',
            points: report.repetitions,
          ),
          const SizedBox(height: AppDimensions.lg),
          ComparisonChart(
            title: 'Throughput across simulated conditions',
            unit: 'Mbps',
            points: report.conditions,
            footnotes: report.conditionLabels,
          ),
          const SizedBox(height: AppDimensions.lg),
          ChartContainer(
            title: 'Measured insights',
            icon: Icons.insights,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppDimensions.sm,
              children: [
                for (final note in report.insights)
                  Text(note, style: AppTextStyle.body),
              ],
            ),
          ),
        ] else if (state.available.isNotEmpty && state.error == null)
          Text(
            'Select experiments to compare their measured results.',
            style: AppTextStyle.body,
          ),
      ],
    );
  }
}
