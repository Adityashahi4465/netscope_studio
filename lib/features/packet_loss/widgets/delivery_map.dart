import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../modals/packet_record.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_style.dart';
import '../../../widgets/chart_container.dart';
import '../../../widgets/status_indicator.dart';
import '../controller/packet_loss_controller.dart';

class DeliveryMap extends ConsumerWidget {
  final PacketLossReport report;
  const DeliveryMap(this.report, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(packetLossControllerProvider.notifier);
    return ChartContainer(
      title: 'Receiver sequence delivery map',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppDimensions.md,
        children: [
          const Wrap(
            spacing: AppDimensions.lg,
            runSpacing: AppDimensions.sm,
            children: [
              StatusIndicator('Delivered', AppColors.success),
              StatusIndicator('Simulated discard', AppColors.warning),
              StatusIndicator('Missing', AppColors.error),
              StatusIndicator('Unrecorded', AppColors.textDisabled),
            ],
          ),
          Text(
            'Zero-based wire sequence numbers. A missing UDP response does not determine request delivery; '
            'these statuses come from the TCP receiver audit. Unrecorded evidence stays unknown.',
            style: AppTextStyle.bodySmall,
          ),
          LayoutBuilder(
            builder: (_, box) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: report.cells.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: (box.maxWidth / AppDimensions.deliveryCellSize)
                    .floor()
                    .clamp(1, 32),
                crossAxisSpacing: AppDimensions.xs,
                mainAxisSpacing: AppDimensions.xs,
              ),
              itemBuilder: (_, index) {
                final cell = report.cells[index];
                final color = switch (cell.status) {
                  PacketStatus.delivered => AppColors.success,
                  PacketStatus.droppedBySimulation => AppColors.warning,
                  PacketStatus.duplicate => AppColors.primaryLight,
                  PacketStatus.missing ||
                  PacketStatus.timedOut => AppColors.error,
                  null => AppColors.textDisabled,
                };
                return Tooltip(
                  message: 'Sequence ${cell.sequence} · ${cell.label}',
                  child: Semantics(
                    label: 'Sequence ${cell.sequence}: ${cell.label}',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: AppDimensions.borderRadiusSm,
                        border: Border.all(color: color),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.xxs),
                          child: FittedBox(
                            child: Text(
                              '${cell.sequence}',
                              style: AppTextStyle.caption.copyWith(
                                color: color,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (report.pages > 0)
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppDimensions.md,
              children: [
                IconButton(
                  tooltip: 'Previous sequence page',
                  onPressed: report.page == 0
                      ? null
                      : () => actions.page(report.page - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  'Page ${report.page + 1} of ${report.pages}',
                  style: AppTextStyle.body,
                ),
                IconButton(
                  tooltip: 'Next sequence page',
                  onPressed: report.page + 1 >= report.pages
                      ? null
                      : () => actions.page(report.page + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
