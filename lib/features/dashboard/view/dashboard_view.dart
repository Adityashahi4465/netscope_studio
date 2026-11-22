import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_style.dart';
import '../widgets/action_bar.dart';
import '../widgets/config_form.dart';
import '../widgets/live_metric_cards.dart';
import '../widgets/progress_panel.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const readings = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.md,
      children: [ProgressPanel(), LiveMetricCards()],
    );
    return ListView(
      padding: AppDimensions.pagePadding,
      children: [
        Text('Benchmark cockpit', style: AppTextStyle.display),
        const SizedBox(height: AppDimensions.sm),
        Text(
          'Run TCP and UDP experiments on IPv4 loopback.',
          style: AppTextStyle.body,
        ),
        const SizedBox(height: AppDimensions.xl),
        const ActionBar(),
        const SizedBox(height: AppDimensions.xl),
        LayoutBuilder(
          builder: (_, box) => box.maxWidth >= AppDimensions.breakpointCompact
              ? const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppDimensions.lg,
                  children: [
                    Expanded(flex: 2, child: ConfigForm()),
                    Expanded(child: readings),
                  ],
                )
              : const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppDimensions.lg,
                  children: [readings, ConfigForm()],
                ),
        ),
      ],
    );
  }
}
