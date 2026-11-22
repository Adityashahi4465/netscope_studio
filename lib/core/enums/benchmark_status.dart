enum BenchmarkStatus {
  idle('Idle'),
  preparing('Preparing'),
  running('Running'),
  completed('Completed'),
  failed('Failed'),
  cancelled('Cancelled');

  const BenchmarkStatus(this.label);

  final String label;

  bool get isActive => this == preparing || this == running;
  bool get isFinished =>
      this == completed || this == failed || this == cancelled;
}
