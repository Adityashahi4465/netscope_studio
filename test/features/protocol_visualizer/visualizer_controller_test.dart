import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/enums/protocol_type.dart';
import '../../../lib/features/protocol_visualizer/controller/visualizer_controller.dart';
import '../../support/experiment_fixture.dart';

void main() {
  test('TCP illustration contains handshake and both FIN directions', () {
    final controller = VisualizerController(null);
    addTearDown(controller.dispose);
    expect(controller.state.replay, isFalse);
    expect(controller.state.canReplay, isFalse);
    expect(controller.state.steps.take(3).map((s) => s.label), [
      'SYN',
      'SYN + ACK',
      'ACK · established',
    ]);
    expect(
      controller.state.steps.where((s) => s.label.startsWith('FIN')),
      hasLength(2),
    );
    controller.protocol(ProtocolType.udp);
    expect(controller.state.steps.any((s) => s.label.contains('SYN')), isFalse);
    expect(
      controller.state.steps.any((s) => s.outcome == VisualOutcome.discarded),
      isTrue,
    );
  });

  test('recorded replay preserves send timestamps and unknown outcomes', () {
    final controller = VisualizerController(experimentFixture().result);
    addTearDown(controller.dispose);
    controller.replay(true);
    expect(controller.state.replay, isTrue);
    expect(controller.state.protocol, ProtocolType.udp);
    expect(controller.state.steps, hasLength(256));
    expect(controller.state.steps[0].outcome, VisualOutcome.discarded);
    expect(controller.state.steps[1].outcome, VisualOutcome.unknown);
    expect(controller.state.steps[1].sentAtUs, 1000);
    expect(controller.state.steps[2].outcome, VisualOutcome.delivered);
    controller.page(1);
    expect(controller.state.steps.first.sequence, 256);
    expect(controller.state.steps.last.sequence, 299);
    controller.seek(9999);
    expect(controller.state.position, controller.state.steps.length);
    expect(controller.state.fraction, 1);
  });

  testWidgets('timeline plays, pauses, changes speed and cancels its timer', (
    tester,
  ) async {
    final controller = VisualizerController(null);
    controller.play();
    await tester.pump(const Duration(milliseconds: 350));
    // Widget tests fake timers; Stopwatch is real. Assert motion lifecycle,
    // not a fabricated relationship between fake time and the real clock.
    expect(controller.state.playing, isTrue);
    controller.pause();
    final stopped = controller.state.position;
    await tester.pump(const Duration(seconds: 1));
    expect(controller.state.position, stopped);
    controller.speed(4);
    expect(controller.state.speed, 4);
    controller.speed(-1);
    expect(controller.state.speed, 4);
    controller.play();
    controller.dispose();
    await tester.pump(const Duration(seconds: 1));
  });
}
