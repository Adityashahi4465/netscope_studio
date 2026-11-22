import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/app_loader.dart';
import '../../../common/custom_snackbar.dart';
import '../../../routes/route_utils.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_style.dart';
import '../controller/history_controller.dart';
import '../widgets/experiment_details.dart';
import '../widgets/history_entry.dart';
import '../widgets/history_filters.dart';

class HistoryView extends ConsumerWidget {
  const HistoryView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyControllerProvider);
    final actions = ref.read(historyControllerProvider.notifier);
    ref.listen(historyControllerProvider, (before, next) {
      final message = next.notice ?? next.error;
      if (message != null && message != (before?.notice ?? before?.error)) {
        CustomSnackbar.show(context, message);
      }
      if (next.detail != null && !identical(next.detail, before?.detail)) {
        unawaited(RouteUtils.dialog(context, ExperimentDetails(next.detail!)));
      }
    });
    final visible = state.visible;
    return ListView.builder(
      padding: AppDimensions.pagePadding,
      itemCount: visible.length + 1,
      itemBuilder: (_, index) {
        if (index > 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.md),
            child: HistoryEntry(visible[index - 1]),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppDimensions.lg,
          children: [
            Text('Experiment history', style: AppTextStyle.display),
            Text(
              'Saved measurements stay on this device. Search names, IDs, dates, and conditions.',
              style: AppTextStyle.body,
            ),
            const HistoryFilters(),
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: state.busy || state.loading
                      ? null
                      : actions.refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh history'),
                ),
                OutlinedButton(
                  onPressed: state.selected.isEmpty || state.busy
                      ? null
                      : () => RouteUtils.compare(context, state.selected),
                  child: Text('Compare selected (${state.selected.length})'),
                ),
                OutlinedButton(
                  onPressed: state.selected.isEmpty || state.busy
                      ? null
                      : () => actions.export(state.selected),
                  child: const Text('Export selected CSV'),
                ),
                OutlinedButton(
                  onPressed: state.items.isEmpty || state.busy
                      ? null
                      : () => unawaited(
                          RouteUtils.dialog(
                            context,
                            AlertDialog(
                              title: const Text('Clear all saved experiments?'),
                              content: const Text(
                                'This removes every saved experiment and its raw samples from this device.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => RouteUtils.close(context),
                                  child: const Text('Keep history'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    RouteUtils.close(context);
                                    unawaited(actions.clear());
                                  },
                                  child: const Text('Clear all experiments'),
                                ),
                              ],
                            ),
                          ),
                        ),
                  child: const Text('Clear history'),
                ),
              ],
            ),
            if (state.loading) const AppLoader('Loading history…'),
            if (state.error case final error?) SelectableText(error),
            if (!state.loading && state.error == null && visible.isEmpty)
              Text(
                state.items.isEmpty
                    ? 'No saved experiments. Run a benchmark and select Save in the cockpit.'
                    : 'No experiments match these filters.',
                style: AppTextStyle.body,
              ),
            if (state.busy) const LinearProgressIndicator(),
            Text(
              '${visible.length} shown · ${state.items.length} saved · ${state.selected.length} selected',
              style: AppTextStyle.caption,
            ),
            const SizedBox(height: AppDimensions.sm),
          ],
        );
      },
    );
  }
}
