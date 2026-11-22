import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/simulation_type.dart';
import '../../../core/utility/csv_exporter.dart';
import '../../../modals/experiment_model.dart';
import '../../../services/experiment_repository.dart';
import '../../../services/providers.dart';

enum HistoryTransport { all, tcp, udp, both }

class HistoryState {
  final List<ExperimentSummary> items;
  final Set<String> selected;
  final String query;
  final HistoryTransport transport;
  final SimulationType? simulation;
  final bool loading;
  final bool busy;
  final String? openingId;
  final ExperimentModel? detail;
  final String? error;
  final String? notice;
  const HistoryState({
    this.items = const [],
    this.selected = const {},
    this.query = '',
    this.transport = HistoryTransport.all,
    this.simulation,
    this.loading = false,
    this.busy = false,
    this.openingId,
    this.detail,
    this.error,
    this.notice,
  });

  List<ExperimentSummary> get visible => List.unmodifiable(
    items.where((item) {
      final protocol = item.config.protocol;
      final matches = switch (transport) {
        HistoryTransport.all => true,
        HistoryTransport.tcp => protocol.includesTcp,
        HistoryTransport.udp => protocol.includesUdp,
        HistoryTransport.both => protocol.includesTcp && protocol.includesUdp,
      };
      final text =
          '${item.name} ${item.id} ${item.createdAt.toLocal()} ${protocol.label} ${item.config.simulation.type.label}'
              .toLowerCase();
      return matches &&
          (simulation == null || item.config.simulation.type == simulation) &&
          text.contains(query.trim().toLowerCase());
    }),
  );

  HistoryState copy({
    List<ExperimentSummary>? items,
    Set<String>? selected,
    String? query,
    HistoryTransport? transport,
    SimulationType? simulation,
    bool clearSimulation = false,
    bool? loading,
    bool? busy,
    String? openingId,
    ExperimentModel? detail,
    bool clearDetail = false,
    String? error,
    String? notice,
  }) => HistoryState(
    items: items ?? this.items,
    selected: selected ?? this.selected,
    query: query ?? this.query,
    transport: transport ?? this.transport,
    simulation: clearSimulation ? null : simulation ?? this.simulation,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    openingId: openingId,
    detail: clearDetail ? null : detail ?? this.detail,
    error: error,
    notice: notice,
  );
}

final historyControllerProvider =
    StateNotifierProvider.autoDispose<HistoryController, HistoryState>(
      (ref) => HistoryController(
        ref.watch(experimentRepositoryProvider),
        ref.watch(csvExporterProvider),
      ),
    );

class HistoryController extends StateNotifier<HistoryState> {
  final IExperimentRepository _repository;
  final CsvExporter _exporter;
  int _listRequest = 0;
  int _detailRequest = 0;
  HistoryController(this._repository, this._exporter)
    : super(const HistoryState(loading: true)) {
    unawaited(refresh());
  }

  Future<void> refresh() async {
    final request = ++_listRequest;
    state = state.copy(loading: true);
    final result = await _repository.list();
    if (!mounted || request != _listRequest) return;
    result.fold(
      (failure) => state = state.copy(loading: false, error: failure.message),
      (items) {
        state = state.copy(
          loading: false,
          items: List.unmodifiable(items),
          selected: Set.unmodifiable(
            state.selected.intersection(items.map((i) => i.id).toSet()),
          ),
        );
      },
    );
  }

  void search(String value) => state = state.copy(query: value);
  void transport(HistoryTransport value) =>
      state = state.copy(transport: value);
  void simulation(SimulationType? value) =>
      state = state.copy(simulation: value, clearSimulation: value == null);
  void toggle(String id) {
    if (state.busy || !state.items.any((item) => item.id == id)) return;
    final ids = {...state.selected};
    if (!ids.remove(id)) ids.add(id);
    state = state.copy(selected: Set.unmodifiable(ids));
  }

  Future<void> open(String id) async {
    if (state.busy) return;
    final request = ++_detailRequest;
    state = state.copy(openingId: id, clearDetail: true);
    final result = await _repository.get(id);
    if (!mounted || request != _detailRequest) return;
    result.fold(
      (failure) => state = state.copy(error: failure.message),
      (item) => state = state.copy(detail: item),
    );
  }

  Future<void> delete(String id) async {
    if (state.busy) return;
    _detailRequest++;
    state = state.copy(busy: true, clearDetail: true);
    final result = await _repository.delete(id);
    if (!mounted) return;
    await result.fold(
      (failure) async =>
          state = state.copy(busy: false, error: failure.message),
      (_) async {
        await refresh();
        if (mounted) {
          state = state.copy(busy: false, notice: 'Experiment deleted.');
        }
      },
    );
  }

  Future<void> clear() async {
    if (state.busy) return;
    _detailRequest++;
    state = state.copy(busy: true, clearDetail: true);
    final result = await _repository.clear();
    if (!mounted) return;
    await result.fold(
      (failure) async =>
          state = state.copy(busy: false, error: failure.message),
      (_) async {
        await refresh();
        if (mounted) {
          state = state.copy(
            busy: false,
            selected: const {},
            notice: 'History cleared.',
          );
        }
      },
    );
  }

  Future<void> export(Iterable<String> ids) async {
    if (state.busy || ids.isEmpty) return;
    state = state.copy(busy: true);
    final loaded = await _repository.loadMultiple(ids);
    if (!mounted) return;
    await loaded.fold(
      (failure) async =>
          state = state.copy(busy: false, error: failure.message),
      (items) async {
        final outcome = await _exporter.export(
          items.map((e) => e.result).toList(),
        );
        if (!mounted) return;
        outcome.fold(
          (failure) => state = state.copy(busy: false, error: failure.message),
          (file) => state = state.copy(
            busy: false,
            notice: file == null ? null : 'Exported to ${file.path}',
          ),
        );
      },
    );
  }
}
