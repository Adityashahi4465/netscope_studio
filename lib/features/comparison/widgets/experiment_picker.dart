import 'package:flutter/material.dart';

import '../../../core/utility/formatters.dart';
import '../../../services/experiment_repository.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_style.dart';
import '../../../widgets/chart_container.dart';

class ExperimentPicker extends StatelessWidget {
  final List<ExperimentSummary> items;
  final Set<String> selected;
  final ValueChanged<String>? toggle;
  const ExperimentPicker(this.items, this.selected, this.toggle, {super.key});
  @override
  Widget build(BuildContext context) => ChartContainer(
    title: 'Saved experiments',
    icon: Icons.inventory_2_outlined,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: AppDimensions.chartHeight),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (_, i) {
          final e = items[i];
          final number = selected.toList().indexOf(e.id) + 1;
          return CheckboxListTile(
            key: ValueKey(e.id),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              '${number == 0 ? '' : 'E$number · '}${e.name}',
              style: AppTextStyle.bodyStrong,
            ),
            subtitle: Text(
              '${e.config.protocol.label} · ${e.config.simulation.type.label} · ${Formatters.dateTime(e.createdAt.toLocal())}',
            ),
            value: selected.contains(e.id),
            onChanged: toggle == null ? null : (_) => toggle!(e.id),
          );
        },
      ),
    ),
  );
}
