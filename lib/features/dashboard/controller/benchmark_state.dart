import '../../../core/enums/benchmark_status.dart';
import '../../../core/utility/validators.dart';
import '../../../modals/benchmark_config.dart';
import '../../../modals/benchmark_result.dart';
import '../../../services/benchmark/i_benchmark_service.dart';
import 'config_field.dart';

class BenchmarkState {
  final BenchmarkConfig config;
  final BenchmarkPreset preset;
  final Map<ConfigField, String> drafts;
  final int formRevision;
  final BenchmarkStatus status;
  final BenchmarkProgress progress;
  final BenchmarkResult? result;
  final String? error;
  final String? notice;
  final bool saving;

  const BenchmarkState({
    this.config = const BenchmarkConfig(),
    this.preset = BenchmarkPreset.quick,
    this.drafts = const {},
    this.formRevision = 0,
    this.status = BenchmarkStatus.idle,
    this.progress = const BenchmarkProgress('Ready', 0, 0),
    this.result,
    this.error,
    this.notice,
    this.saving = false,
  });

  bool get locked => status.isActive || saving;
  DateTime? get completedAt => result?.completedAt;
  AggregateMetrics get tcp => result?.tcpAggregate ?? progress.tcp;
  AggregateMetrics get udp => result?.udpAggregate ?? progress.udp;
  String? get validation {
    for (final field in drafts.entries) {
      if (field.key.apply(config, field.value) == null) {
        return 'Enter a valid number for ${field.key.label}.';
      }
    }
    return Validators.validateConfig(config)
        .fold((f) => f.message, (_) => null);
  }

  BenchmarkState update({
    BenchmarkStatus? status,
    BenchmarkProgress? progress,
    BenchmarkResult? result,
    String? error,
    String? notice,
    bool? saving,
  }) => BenchmarkState(
    config: config,
    preset: preset,
    drafts: drafts,
    formRevision: formRevision,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    result: result ?? this.result,
    error: error,
    notice: notice,
    saving: saving ?? this.saving,
  );
}
