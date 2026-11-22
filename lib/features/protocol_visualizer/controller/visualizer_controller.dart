import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/protocol_type.dart';
import '../../../modals/benchmark_result.dart';
import '../../../modals/packet_record.dart';
import '../../../modals/udp_result.dart';
import '../../../theme/app_dimensions.dart';
import '../../dashboard/controller/benchmark_controller.dart';

enum VisualOutcome { delivered, discarded, unknown }

class VisualStep {
  final String label;
  final String explanation;
  final bool fromClient;
  final VisualOutcome outcome;
  final int? sequence;
  final int? sentAtUs;
  const VisualStep(
    this.label,
    this.explanation, {
    this.fromClient = true,
    this.outcome = VisualOutcome.delivered,
    this.sequence,
    this.sentAtUs,
  });
}

class VisualizerState {
  final ProtocolType protocol;
  final bool replay;
  final bool playing;
  final double position;
  final double speed;
  final List<VisualStep> steps;
  final List<int> runs;
  final int runIndex;
  final int page;
  final int pages;
  final String? sourceId;
  const VisualizerState({
    this.protocol = ProtocolType.tcp,
    this.replay = false,
    this.playing = false,
    this.position = 0,
    this.speed = 1,
    required this.steps,
    this.runs = const [],
    this.runIndex = 0,
    this.page = 0,
    this.pages = 0,
    this.sourceId,
  });

  bool get canReplay => runs.isNotEmpty;
  int get activeIndex =>
      steps.isEmpty ? 0 : position.floor().clamp(0, steps.length - 1);
  double get fraction =>
      position >= steps.length ? 1 : position - position.floor();
  VisualStep? get activeStep => steps.isEmpty ? null : steps[activeIndex];

  VisualizerState motion({bool? playing, double? position, double? speed}) =>
      VisualizerState(
        protocol: protocol,
        replay: replay,
        playing: playing ?? this.playing,
        position: position ?? this.position,
        speed: speed ?? this.speed,
        steps: steps,
        runs: runs,
        runIndex: runIndex,
        page: page,
        pages: pages,
        sourceId: sourceId,
      );
}

final visualizerControllerProvider = StateNotifierProvider.autoDispose
    .family<VisualizerController, VisualizerState, BenchmarkResult?>(
      (ref, initial) => VisualizerController(
        initial ??
            ref.watch(benchmarkControllerProvider.select((s) => s.result)),
        replayInitially: initial != null,
      ),
    );

class VisualizerController extends StateNotifier<VisualizerState> {
  final BenchmarkResult? _result;
  final Stopwatch _clock = Stopwatch();
  Timer? _timer;
  double _startPosition = 0;
  VisualizerController(this._result, {bool replayInitially = false})
    : super(_state(_result, replay: replayInitially));

  static VisualizerState _state(
    BenchmarkResult? result, {
    ProtocolType protocol = ProtocolType.tcp,
    bool replay = false,
    int runIndex = 0,
    int page = 0,
    double speed = 1,
  }) {
    final runs =
        result?.udpRuns.where((r) => r.packetRecords.isNotEmpty).toList() ??
        <UdpResult>[];
    final run =
        runs.where((r) => r.runIndex == runIndex).firstOrNull ??
        runs.firstOrNull;
    final pages =
        ((run?.packetRecords.length ?? 0) / AppDimensions.replayPageSize)
            .ceil();
    final selectedPage = pages == 0 ? 0 : page.clamp(0, pages - 1);
    final measured = replay && run != null;
    return VisualizerState(
      protocol: measured ? ProtocolType.udp : protocol,
      replay: measured,
      steps: measured
          ? recordedSteps(run, selectedPage)
          : illustration(protocol),
      runs: List<int>.unmodifiable(runs.map((r) => r.runIndex)),
      runIndex: run?.runIndex ?? 0,
      page: selectedPage,
      pages: pages,
      speed: speed,
      sourceId: result?.id,
    );
  }

  static List<VisualStep> illustration(ProtocolType protocol) =>
      protocol == ProtocolType.tcp
      ? const [
          VisualStep('SYN', 'Client requests a TCP connection.'),
          VisualStep(
            'SYN + ACK',
            'Server acknowledges the request and offers its sequence.',
            fromClient: false,
          ),
          VisualStep(
            'ACK · established',
            'Client acknowledges; the three-way handshake completes.',
          ),
          VisualStep(
            'Application data',
            'TCP carries an ordered byte stream; application frames need their own boundaries.',
          ),
          VisualStep(
            'ACK · byte stream',
            'TCP acknowledges stream bytes. This illustration omits retransmission and congestion behavior.',
            fromClient: false,
          ),
          VisualStep(
            'FIN · client',
            'One endpoint finishes sending; the other direction can remain open.',
          ),
          VisualStep(
            'ACK · client FIN',
            'Server acknowledges the client FIN.',
            fromClient: false,
          ),
          VisualStep(
            'FIN · server',
            'Server finishes its sending direction.',
            fromClient: false,
          ),
          VisualStep(
            'ACK · closed',
            'Client acknowledges. TCP close order may differ in real connections.',
          ),
        ]
      : const [
          VisualStep(
            'Datagram 0',
            'UDP sends an independent message without a transport handshake.',
          ),
          VisualStep(
            'Datagram 1 · application discard',
            'This illustration discards a received request in the server application.',
            outcome: VisualOutcome.discarded,
          ),
          VisualStep(
            'Datagram 2',
            'Later messages may arrive independently; UDP provides no ordering or retransmission guarantee.',
          ),
          VisualStep(
            'Optional application echo',
            'Our lab implements RTT echoes. They are application messages, not UDP acknowledgements.',
            fromClient: false,
          ),
        ];

  static List<VisualStep> recordedSteps(UdpResult run, int page) =>
      List<VisualStep>.unmodifiable(
        run.packetRecords
            .skip(page * AppDimensions.replayPageSize)
            .take(AppDimensions.replayPageSize)
            .map((record) {
              final outcome = switch (record.status) {
                PacketStatus.delivered ||
                PacketStatus.duplicate => VisualOutcome.delivered,
                PacketStatus.droppedBySimulation => VisualOutcome.discarded,
                PacketStatus.missing ||
                PacketStatus.timedOut => VisualOutcome.unknown,
              };
              final explanation = switch (outcome) {
                VisualOutcome.delivered => 'Recorded receiver audit: request accepted. Receipt time and path were not logged.',
                VisualOutcome.discarded => 'Recorded receiver audit: request arrived and was discarded by the application simulation.',
                VisualOutcome.unknown => 'Request was not accepted before the audit deadline. Its location and arrival time are unknown.',
              };
              return VisualStep(
                'UDP sequence ${record.sequence}',
                explanation,
                outcome: outcome,
                sequence: record.sequence,
                sentAtUs: record.sentAtUs,
              );
            }),
      );

  void protocol(ProtocolType value) {
    pause();
    state = _state(_result, protocol: value, speed: state.speed);
  }

  void replay(bool value) {
    pause();
    state = _state(
      _result,
      protocol: state.protocol,
      replay: value,
      runIndex: state.runIndex,
      speed: state.speed,
    );
  }

  void run(int index) {
    pause();
    state = _state(_result, replay: true, runIndex: index, speed: state.speed);
  }

  void page(int page) {
    pause();
    state = _state(
      _result,
      replay: state.replay,
      protocol: state.protocol,
      runIndex: state.runIndex,
      page: page,
      speed: state.speed,
    );
  }

  void seek(double position) {
    pause();
    state = state.motion(
      position: position.clamp(0, state.steps.length.toDouble()),
    );
  }

  void speed(double value) {
    if (!const [0.5, 1.0, 2.0, 4.0].contains(value)) return;
    final playing = state.playing;
    pause();
    state = state.motion(speed: value);
    if (playing) play();
  }

  void play() {
    if (state.steps.isEmpty || state.playing) return;
    _startPosition = state.position >= state.steps.length ? 0 : state.position;
    _clock
      ..reset()
      ..start();
    state = state.motion(playing: true, position: _startPosition);
    _timer = Timer.periodic(AppDimensions.visualizerFrameDuration, (_) {
      final position = min(
        state.steps.length.toDouble(),
        _startPosition +
            _clock.elapsedMicroseconds /
                AppDimensions.visualizerStepDuration.inMicroseconds *
                state.speed,
      );
      if (position >= state.steps.length) {
        _timer?.cancel();
        _clock.stop();
      }
      state = state.motion(
        position: position,
        playing: position < state.steps.length,
      );
    });
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    state = state.motion(playing: false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock.stop();
    super.dispose();
  }
}
