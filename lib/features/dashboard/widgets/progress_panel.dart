import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utility/formatters.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_style.dart';
import '../../../widgets/chart_container.dart';
import '../controller/benchmark_controller.dart';

class ProgressPanel extends ConsumerWidget {
  const ProgressPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(benchmarkControllerProvider);
    final p = state.progress;
    return ChartContainer(
      title: 'Run progress',
      icon: Icons.timeline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppDimensions.md,
        children: [
          Row(
            children: [
              Expanded(child: Text(p.phase, style: AppTextStyle.bodyStrong)),
              Text(
                Formatters.percent(p.percent, digits: 0),
                style: AppTextStyle.tabular,
              ),
            ],
          ),
          LinearProgressIndicator(
            value: p.percent / 100,
            borderRadius: AppDimensions.borderRadiusSm,
          ),
          if (p.runIndex > 0)
            Text(
              'Repetition ${p.runIndex} of ${state.config.repetitions}',
              style: AppTextStyle.bodySmall,
            ),
          if (state.completedAt case final at?)
            Text(
              'Completed ${Formatters.dateTime(at.toLocal())}',
              style: AppTextStyle.bodySmall,
            ),
          if (state.error case final error?) SelectableText(error),
        ],
      ),
    );
  }
}
