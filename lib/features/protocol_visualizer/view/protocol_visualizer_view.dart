import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/protocol_type.dart';
import '../../../modals/benchmark_result.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_style.dart';
import '../../../widgets/custom_dropdown.dart';
import '../controller/visualizer_controller.dart';
import '../widgets/protocol_timeline.dart';

class ProtocolVisualizerView extends ConsumerWidget {
  final BenchmarkResult? initialResult;
  const ProtocolVisualizerView({this.initialResult, super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = visualizerControllerProvider(initialResult);
    final state = ref.watch(provider);
    final actions = ref.read(provider.notifier);
    return ListView.builder(
      padding: AppDimensions.pagePadding,
      itemCount: state.steps.length + 1,
      itemBuilder: (_, index) {
        if (index > 0) {
          final step = state.steps[index - 1];
          return Padding(
            padding: const EdgeInsets.only(top: AppDimensions.sm),
            child: ListTile(
              selected: state.activeIndex == index - 1,
              selectedTileColor: AppColors.primarySoft,
              leading: Icon(
                step.fromClient ? Icons.arrow_forward : Icons.arrow_back,
                color: state.replay
                    ? AppColors.udp
                    : AppColors.forProtocol(state.protocol.name),
              ),
              title: Text(
                '${index + state.page * AppDimensions.replayPageSize}. ${step.label}',
              ),
              subtitle: Text(step.explanation),
              onTap: () => actions.seek(index - 1.0),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppDimensions.lg,
          children: [
            Text('Protocol visualizer', style: AppTextStyle.display),
            Text(
              'Illustration explains protocol behavior. It is not a packet capture or a benchmark measurement.',
              style: AppTextStyle.body,
            ),
            Wrap(
              spacing: AppDimensions.sm,
              children: [
                for (final protocol in [ProtocolType.tcp, ProtocolType.udp])
                  ChoiceChip(
                    label: Text('${protocol.label} illustration'),
                    selected: !state.replay && state.protocol == protocol,
                    onSelected: (_) => actions.protocol(protocol),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Replay recorded UDP requests'),
              subtitle: Text(
                state.canReplay
                    ? 'From ${state.sourceId}. Actual send timestamps and TCP-audited outcomes; motion is illustrative.'
                    : 'Run a UDP benchmark first or open a saved packet log from history. No TCP packet log is recorded.',
              ),
              value: state.replay,
              onChanged: state.canReplay ? actions.replay : null,
            ),
            if (state.replay) ...[
              const Text(
                'Arrival times, wire order, ACKs, and retransmissions were not logged. Missing means not accepted '
                'at the audit deadline; its location is unknown.',
              ),
              CustomDropdown(
                label: 'Recorded UDP repetition',
                value: state.runIndex,
                items: state.runs,
                title: (i) => 'Repetition ${state.runs.indexOf(i) + 1}',
                onChanged: actions.run,
              ),
            ],
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: [
                ElevatedButton.icon(
                  onPressed: state.steps.isEmpty
                      ? null
                      : state.playing
                      ? actions.pause
                      : actions.play,
                  icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
                  label: Text(
                    state.playing ? 'Pause timeline' : 'Play timeline',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => actions.seek(0),
                  child: const Text('Restart timeline'),
                ),
                for (final speed in [0.5, 1.0, 2.0, 4.0])
                  ChoiceChip(
                    label: Text('$speed×'),
                    selected: state.speed == speed,
                    onSelected: (_) => actions.speed(speed),
                  ),
              ],
            ),
            Slider(
              value: state.position,
              min: 0,
              max: state.steps.isEmpty ? 1 : state.steps.length.toDouble(),
              label: 'Step ${state.activeIndex + 1}',
              onChanged: state.steps.isEmpty ? null : actions.seek,
            ),
            ProtocolTimeline(state),
            if (state.replay && state.pages > 1)
              Wrap(
                spacing: AppDimensions.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Previous recorded page',
                    onPressed: state.page == 0
                        ? null
                        : () => actions.page(state.page - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    'Recorded page ${state.page + 1} / ${state.pages}',
                    style: AppTextStyle.body,
                  ),
                  IconButton(
                    tooltip: 'Next recorded page',
                    onPressed: state.page + 1 == state.pages
                        ? null
                        : () => actions.page(state.page + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            Text(
              state.replay ? 'Recorded request log' : 'Illustrative steps',
              style: AppTextStyle.h2,
            ),
          ],
        );
      },
    );
  }
}
