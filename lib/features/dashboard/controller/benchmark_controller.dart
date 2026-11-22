import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/benchmark_status.dart';
import '../../../core/enums/protocol_type.dart';
import '../../../core/enums/simulation_type.dart';
import '../../../core/utility/csv_exporter.dart';
import '../../../core/utility/formatters.dart';
import '../../../modals/benchmark_config.dart';
import '../../../modals/experiment_model.dart';
import '../../../services/benchmark/i_benchmark_service.dart';
import '../../../services/experiment_repository.dart';
import '../../../services/providers.dart';
import '../../../services/simulation/network_simulator.dart';
import 'benchmark_state.dart';
import 'config_field.dart';

final benchmarkControllerProvider =
    StateNotifierProvider<BenchmarkController, BenchmarkState>(
      (ref) => BenchmarkController(
        ref.watch(benchmarkServiceProvider),
        ref.watch(experimentRepositoryProvider),
        ref.watch(csvExporterProvider),
        ref.watch(simulatorProvider),
      ),
    );

class BenchmarkController extends StateNotifier<BenchmarkState> {
  final IBenchmarkService _service;
  final IExperimentRepository _repository;
  final CsvExporter _exporter;
  final NetworkSimulator _simulator;
  late final StreamSubscription<BenchmarkProgress> _events;
  CancelToken? _token;

  BenchmarkController(
    this._service,
    this._repository,
    this._exporter,
    this._simulator,
  ) : super(const BenchmarkState()) {
    _events = _service.progress.listen((event) {
      if (state.status.isActive) {
        state = state.update(status: BenchmarkStatus.running, progress: event);
      }
    });
  }

  void selectPreset(BenchmarkPreset preset) {
    if (state.locked) return;
    state = BenchmarkState(
      preset: preset,
      config: preset == BenchmarkPreset.custom
          ? state.config
          : BenchmarkConfig.fromPreset(preset),
      formRevision: state.formRevision + 1,
    );
  }

  void reset() => selectPreset(BenchmarkPreset.quick);

  void edit(ConfigField field, String raw) {
    if (state.locked) return;
    state = BenchmarkState(
      config: field.apply(state.config, raw) ?? state.config,
      preset: BenchmarkPreset.custom,
      drafts: Map.unmodifiable({...state.drafts, field: raw}),
      formRevision: state.formRevision,
    );
  }

  void protocol(ProtocolType type) {
    if (state.locked) return;
    state = BenchmarkState(
      config: state.config.copyWith(protocol: type),
      preset: BenchmarkPreset.custom,
      drafts: state.drafts,
      formRevision: state.formRevision,
    );
  }

  void simulation(SimulationType type) {
    if (state.locked) return;
    final drafts = Map.of(state.drafts)
      ..removeWhere(
        (field, _) => const {
          ConfigField.loss,
          ConfigField.delay,
          ConfigField.jitter,
          ConfigField.rate,
          ConfigField.seed,
        }.contains(field),
      );
    state = BenchmarkState(
      config: state.config.copyWith(simulation: _simulator.preset(type)),
      preset: BenchmarkPreset.custom,
      drafts: Map.unmodifiable(drafts),
      formRevision: state.formRevision + 1,
    );
  }

  Future<void> start() async {
    if (state.locked || state.validation != null) return;
    final token = _token = CancelToken();
    state = BenchmarkState(
      config: state.config,
      preset: state.preset,
      drafts: state.drafts,
      formRevision: state.formRevision,
      status: BenchmarkStatus.preparing,
    );
    final outcome = await _service.run(state.config, token);
    if (!mounted) return;
    _token = null;
    outcome.fold(
      (f) {
        state = state.update(
          status: token.isCancelled
              ? BenchmarkStatus.cancelled
              : BenchmarkStatus.failed,
          progress: BenchmarkProgress(
            token.isCancelled ? 'Cancelled' : 'Failed',
            state.progress.runIndex,
            state.progress.percent,
          ),
          error: token.isCancelled ? null : f.message,
        );
      },
      (r) {
        state = state.update(
          status: BenchmarkStatus.completed,
          result: r,
          progress: BenchmarkProgress('Completed', r.config.repetitions, 100),
          notice: 'Benchmark completed.',
        );
      },
    );
  }

  void cancel() => _token?.cancel();

  Future<void> save() async {
    final result = state.result;
    if (state.locked || result == null) return;
    state = state.update(saving: true);
    final response = await _repository.save(
      ExperimentModel(
        id: result.id,
        name:
            '${state.preset.label} · ${Formatters.dateTime(result.completedAt.toLocal())}',
        createdAt: result.completedAt,
        result: result,
      ),
    );
    if (!mounted) return;
    response.fold(
      (f) => state = state.update(saving: false, error: f.message),
      (_) => state = state.update(saving: false, notice: 'Experiment saved.'),
    );
  }

  Future<void> export() async {
    final result = state.result;
    if (state.locked || result == null) return;
    state = state.update(saving: true);
    final response = await _exporter.export([result]);
    if (!mounted) return;
    response.fold(
      (f) => state = state.update(saving: false, error: f.message),
      (file) => state = state.update(
        saving: false,
        notice: file == null ? null : 'Exported to ${file.path}',
      ),
    );
  }

  @override
  void dispose() {
    _token?.cancel();
    unawaited(_events.cancel());
    super.dispose();
  }
}
