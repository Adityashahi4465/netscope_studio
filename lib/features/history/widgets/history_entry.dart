import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utility/formatters.dart';
import '../../../routes/route_utils.dart';
import '../../../services/experiment_repository.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_style.dart';
import '../../../widgets/chart_container.dart';
import '../controller/history_controller.dart';

class HistoryEntry extends ConsumerWidget {
  final ExperimentSummary item;
  const HistoryEntry(this.item, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyControllerProvider);
    final actions = ref.read(historyControllerProvider.notifier);
    return ChartContainer(
      title: item.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppDimensions.sm,
        children: [
          Text(
            '${Formatters.dateTime(item.createdAt.toLocal())} · ${item.config.protocol.label} · '
            '${item.config.simulation.type.label}',
            style: AppTextStyle.bodySmall,
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: state.selected.contains(item.id),
                    semanticLabel: 'Select ${item.name}',
                    onChanged: state.busy
                        ? null
                        : (_) => actions.toggle(item.id),
                  ),
                  const Text('Select'),
                ],
              ),
              TextButton.icon(
                onPressed: state.busy || state.openingId == item.id
                    ? null
                    : () => actions.open(item.id),
                icon: const Icon(Icons.open_in_new),
                label: Text(
                  state.openingId == item.id ? 'Loading…' : 'Open details',
                ),
              ),
              IconButton(
                tooltip: 'Export ${item.name}',
                onPressed: state.busy ? null : () => actions.export([item.id]),
                icon: const Icon(Icons.file_download_outlined),
              ),
              IconButton(
                tooltip: 'Delete ${item.name}',
                onPressed: state.busy
                    ? null
                    : () => unawaited(
                        RouteUtils.dialog(
                          context,
                          AlertDialog(
                            title: const Text('Delete saved experiment?'),
                            content: Text(item.name),
                            actions: [
                              TextButton(
                                onPressed: () => RouteUtils.close(context),
                                child: const Text('Keep experiment'),
                              ),
                              TextButton(
                                onPressed: () {
                                  RouteUtils.close(context);
                                  unawaited(actions.delete(item.id));
                                },
                                child: const Text('Delete experiment'),
                              ),
                            ],
                          ),
                        ),
                      ),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
