import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_dimensions.dart';
import '../../../widgets/custom_primary_button.dart';
import '../controller/benchmark_controller.dart';

class ActionBar extends ConsumerWidget {
  const ActionBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(benchmarkControllerProvider);
    final actions = ref.read(benchmarkControllerProvider.notifier);
    final canSave = state.result != null && !state.locked;
    return Wrap(
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.sm,
      children: [
        CustomPrimaryButton(
          'Start',
          Icons.play_arrow,
          state.locked || state.validation != null ? null : actions.start,
        ),
        OutlinedButton(
          onPressed: state.status.isActive ? actions.cancel : null,
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: state.locked ? null : actions.reset,
          child: const Text('Reset'),
        ),
        OutlinedButton.icon(
          onPressed: canSave ? actions.save : null,
          icon: const Icon(Icons.bookmark_border),
          label: const Text('Save'),
        ),
        OutlinedButton.icon(
          onPressed: canSave ? actions.export : null,
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Export'),
        ),
      ],
    );
  }
}
