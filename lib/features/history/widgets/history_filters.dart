import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/simulation_type.dart';
import '../../../theme/app_dimensions.dart';
import '../../../widgets/custom_dropdown.dart';
import '../controller/history_controller.dart';

class HistoryFilters extends ConsumerWidget {
  const HistoryFilters({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyControllerProvider);
    final actions = ref.read(historyControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.md,
      children: [
        TextFormField(
          initialValue: state.query,
          decoration: const InputDecoration(
            labelText: 'Search saved experiments',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: actions.search,
        ),
        CustomDropdown(
          label: 'Saved transport',
          value: state.transport,
          items: HistoryTransport.values,
          title: (value) => switch (value) {
            HistoryTransport.all => 'All transports',
            HistoryTransport.tcp => 'Includes TCP',
            HistoryTransport.udp => 'Includes UDP',
            HistoryTransport.both => 'TCP + UDP',
          },
          onChanged: actions.transport,
        ),
        // A non-null sentinel keeps DropdownButton's selection semantics clear.
        CustomDropdown(
          label: 'Simulated condition',
          value: state.simulation?.name ?? 'all',
          items: ['all', ...SimulationType.values.map((s) => s.name)],
          title: (value) => value == 'all'
              ? 'All simulated conditions'
              : SimulationType.fromName(value).label,
          onChanged: (value) => actions.simulation(
            value == 'all' ? null : SimulationType.fromName(value),
          ),
        ),
      ],
    );
  }
}
