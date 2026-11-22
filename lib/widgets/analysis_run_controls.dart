import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/dashboard/controller/benchmark_controller.dart';
import '../features/dashboard/controller/config_field.dart';
import '../features/dashboard/widgets/action_bar.dart';
import '../features/dashboard/widgets/config_form.dart';
import '../features/dashboard/widgets/progress_panel.dart';
import '../modals/benchmark_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_style.dart';
import 'chart_container.dart';

class AnalysisRunControls extends ConsumerWidget {
  final BenchmarkPreset preset;
  final List<ConfigField> fields;
  const AnalysisRunControls({
    required this.preset,
    required this.fields,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(benchmarkControllerProvider);
    return ChartContainer(
      title: 'Run a focused experiment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppDimensions.lg,
        children: [
          Wrap(
            spacing: AppDimensions.md,
            children: [
              OutlinedButton.icon(
                onPressed: state.locked
                    ? null
                    : () => ref
                          .read(benchmarkControllerProvider.notifier)
                          .prepareAnalysis(preset),
                icon: const Icon(Icons.tune),
                label: Text('Load ${preset.label} setup'),
              ),
            ],
          ),
          Text(
            'Current transport: ${state.config.protocol.label}. Setup replaces the cockpit configuration. '
            'Delay and variation affect server RTT echoes; UDP discard affects bulk datagrams.',
            style: AppTextStyle.bodySmall,
          ),
          ConfigFields(fields),
          if (state.validation case final error?)
            Text(
              error,
              style: AppTextStyle.body.copyWith(color: AppColors.error),
            ),
          const ActionBar(),
          const ProgressPanel(),
        ],
      ),
    );
  }
}
