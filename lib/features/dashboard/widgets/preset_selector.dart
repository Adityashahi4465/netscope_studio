import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../modals/benchmark_config.dart';
import '../../../widgets/custom_dropdown.dart';
import '../controller/benchmark_controller.dart';

class PresetSelector extends ConsumerWidget {
  const PresetSelector({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(benchmarkControllerProvider);
    return CustomDropdown(
      label: 'Benchmark preset',
      value: state.preset,
      items: BenchmarkPreset.values,
      title: (p) => p.label,
      onChanged: state.locked
          ? null
          : ref.read(benchmarkControllerProvider.notifier).selectPreset,
    );
  }
}
