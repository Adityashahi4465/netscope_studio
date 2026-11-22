import 'benchmark_result.dart';

/// A saved experiment: a named [BenchmarkResult] stored in history.
class ExperimentModel {
  final String id;
  final String name;
  final DateTime createdAt;
  final String notes;
  final BenchmarkResult result;

  const ExperimentModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.result,
    this.notes = '',
  });

  ExperimentModel copyWith({String? name, String? notes}) => ExperimentModel(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    notes: notes ?? this.notes,
    result: result,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'notes': notes,
    'result': result.toMap(),
  };

  factory ExperimentModel.fromMap(Map<String, dynamic> map) => ExperimentModel(
    id: map['id'] as String,
    name: map['name'] as String,
    createdAt: DateTime.parse(map['createdAt'] as String),
    notes: map['notes'] as String? ?? '',
    result: BenchmarkResult.fromMap(
      Map<String, dynamic>.from(map['result'] as Map),
    ),
  );
}
