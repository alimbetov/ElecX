enum P9FailureSeverity { info, warning, blocker }

enum P9FailureStage {
  parameters,
  catalog,
  grammar,
  area,
  semantics,
  geometry,
  scoring,
  rendering,
  provider,
  preview,
  materialization,
  provenance,
  qualification,
}

/// Typed non-mutating correction hint attached to a P9 failure.
final class P9Suggestion {
  const P9Suggestion({
    required this.field,
    required this.reasonCode,
    this.currentValue,
    this.suggestedValue,
  });

  final String field;
  final String reasonCode;
  final Object? currentValue;
  final Object? suggestedValue;
}

/// Locale-independent failure envelope shared by the P9 application pipeline.
///
/// Presentation maps [code] + [facts] to RU/EN text. Domain/application code
/// never persists localized error strings as failure identity.
final class P9Failure {
  P9Failure({
    required this.code,
    required this.stage,
    required this.severity,
    Map<String, Object?> facts = const {},
    Iterable<P9Suggestion> suggestions = const [],
  })  : facts = Map.unmodifiable(facts),
        suggestions = List.unmodifiable(suggestions) {
    if (code.trim().isEmpty) {
      throw ArgumentError.value(
          code, 'code', 'Failure code must be non-empty.');
    }
  }

  final String code;
  final P9FailureStage stage;
  final P9FailureSeverity severity;
  final Map<String, Object?> facts;
  final List<P9Suggestion> suggestions;

  bool get isBlocker => severity == P9FailureSeverity.blocker;
}
