import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utility/csv_exporter.dart';
import '../../../services/benchmark/comparison_service.dart';
import '../../../services/benchmark/metrics_service.dart';
import '../../../services/experiment_repository.dart';
import '../../../services/providers.dart';
import 'comparison_report.dart';

class ComparisonState {
  final List<ExperimentSummary> available;
  final Set<String> selected;
  final ComparisonReport? report;
  final bool loadingList;
  final bool loadingResults;
  final bool exporting;
  final String? error;
  final String? notice;
  const ComparisonState({
    this.available = const [],
    this.selected = const {},
    this.report,
    this.loadingList = false,
    this.loadingResults = false,
    this.exporting = false,
    this.error,
    this.notice,
  });
}

final comparisonControllerProvider =
    StateNotifierProvider.autoDispose<ComparisonController, ComparisonState>(
      (ref) => ComparisonController(
        ref.watch(experimentRepositoryProvider),
        ref.watch(metricsProvider),
        ref.watch(comparisonServiceProvider),
        ref.watch(csvExporterProvider),
      ),
    );

class ComparisonController extends StateNotifier<ComparisonState> {
  final IExperimentRepository _repo;
  final MetricsService _metrics;
  final ComparisonService _comparison;
  final CsvExporter _exporter;
  int _request = 0;
  ComparisonController(
    this._repo,
    this._metrics,
    this._comparison,
    this._exporter,
  ) : super(const ComparisonState(loadingList: true)) {
    unawaited(refresh());
  }

  Future<void> refresh() async {
    final request = ++_request;
    state = ComparisonState(
      available: state.available,
      selected: state.selected,
      loadingList: true,
    );
    final response = await _repo.list();
    if (!mounted || request != _request) return;
    await response.fold(
      (failure) async {
        state = ComparisonState(error: failure.message);
      },
      (items) async {
        final selected = state.selected.intersection(
          items.map((e) => e.id).toSet(),
        );
        state = ComparisonState(available: items);
        if (selected.isNotEmpty) await _load(selected);
      },
    );
  }

  Future<void> toggle(String id) async {
    if (state.loadingList || state.exporting) return;
    final ids = {...state.selected};
    if (!ids.remove(id)) ids.add(id);
    await _load(ids);
  }

  Future<void> _load(Set<String> ids) async {
    final request = ++_request;
    final selected = Set<String>.unmodifiable(ids);
    state = ComparisonState(
      available: state.available,
      selected: selected,
      loadingResults: ids.isNotEmpty,
    );
    if (ids.isEmpty) return;
    final response = await _repo.loadMultiple(selected);
    if (!mounted || request != _request) return;
    response.fold(
      (f) => state = ComparisonState(
        available: state.available,
        selected: selected,
        error: f.message,
      ),
      (items) => state = ComparisonState(
        available: state.available,
        selected: selected,
        report: ComparisonReport.from(items, _metrics, _comparison),
      ),
    );
  }

  Future<void> export() async {
    final report = state.report;
    if (report == null || state.exporting) return;
    final request = _request;
    state = ComparisonState(
      available: state.available,
      selected: state.selected,
      report: report,
      exporting: true,
    );
    final outcome = await _exporter.export(
      report.experiments.map((e) => e.result).toList(),
    );
    if (!mounted || request != _request) return;
    outcome.fold(
      (f) => state = ComparisonState(
        available: state.available,
        selected: state.selected,
        report: report,
        error: f.message,
      ),
      (file) => state = ComparisonState(
        available: state.available,
        selected: state.selected,
        report: report,
        notice: file == null ? null : 'Exported to ${file.path}',
      ),
    );
  }
}
