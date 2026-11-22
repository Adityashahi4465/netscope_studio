import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/protocol_type.dart';
import '../../../core/enums/simulation_type.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_style.dart';
import '../../../widgets/chart_container.dart';
import '../../../widgets/custom_dropdown.dart';
import '../../../widgets/custom_text_field.dart';
import '../controller/benchmark_controller.dart';
import '../controller/config_field.dart';
import 'preset_selector.dart';

class ConfigFields extends ConsumerWidget {
  final List<ConfigField> fields;
  const ConfigFields(this.fields, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(benchmarkControllerProvider);
    final actions = ref.read(benchmarkControllerProvider.notifier);
    return LayoutBuilder(
      builder: (context, box) {
        final columns = (box.maxWidth / AppDimensions.metricCardMinWidth)
            .floor()
            .clamp(1, 3);
        final width =
            (box.maxWidth - (columns - 1) * AppDimensions.md) / columns;
        return Wrap(
          spacing: AppDimensions.md,
          runSpacing: AppDimensions.lg,
          children: [
            for (final field in fields)
              SizedBox(
                width: width,
                child: CustomTextField(
                  key: ValueKey((field, state.formRevision)),
                  label: field.label,
                  initial: state.drafts[field] ?? field.text(state.config),
                  enabled: !state.locked,
                  error:
                      state.drafts.containsKey(field) &&
                          field.apply(state.config, state.drafts[field]!) ==
                              null
                      ? 'Enter a valid number'
                      : null,
                  onChanged: (raw) => actions.edit(field, raw),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ConfigForm extends ConsumerWidget {
  const ConfigForm({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(benchmarkControllerProvider);
    final actions = ref.read(benchmarkControllerProvider.notifier);
    return ChartContainer(
      title: 'Experiment configuration',
      icon: Icons.tune,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppDimensions.lg,
        children: [
          const PresetSelector(),
          CustomDropdown(
            label: 'Transport protocol',
            value: state.config.protocol,
            items: ProtocolType.values,
            title: (p) => p.label,
            onChanged: state.locked ? null : actions.protocol,
          ),
          const ConfigFields([
            ConfigField.tcpPayload,
            ConfigField.datagram,
            ConfigField.packets,
            ConfigField.repetitions,
            ConfigField.probes,
          ]),
          const Divider(),
          Text('Simulated conditions', style: AppTextStyle.h3),
          CustomDropdown(
            label: 'Simulation preset',
            value: state.config.simulation.type,
            items: SimulationType.values,
            title: (t) => t.label,
            onChanged: state.locked ? null : actions.simulation,
          ),
          const ConfigFields([
            ConfigField.loss,
            ConfigField.delay,
            ConfigField.jitter,
            ConfigField.rate,
          ]),
          Text(
            'Delay applies to server RTT echoes. UDP discard applies to bulk datagrams. '
            'The send-rate cap limits application sends (0 = unlimited).',
            style: AppTextStyle.bodySmall,
          ),
          if (state.validation case final problem?)
            Text(
              problem,
              style: AppTextStyle.body.copyWith(color: AppColors.error),
            ),
        ],
      ),
    );
  }
}
