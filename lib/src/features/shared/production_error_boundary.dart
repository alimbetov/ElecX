import 'package:flutter/foundation.dart';

/// Stable production diagnostic identifiers exposed to support without
/// exposing internal exception details to the user interface.
enum ProductionDiagnosticCode {
  projectHubLoad('PX-HUB-001'),
  projectCreate('PX-HUB-002'),
  projectWizardApply('PX-HUB-003'),
  canonicalProjectOpen('PX-HUB-004'),
  canonicalProjection('PX-HUB-005'),
  recoveryDiscard('PX-HUB-006'),
  projectSave('PX-EDITOR-001'),
  savedProjectOpen('PX-EDITOR-002'),
  projectNorthMutation('PX-EDITOR-003'),
  projectNorthPersistence('PX-EDITOR-004');

  const ProductionDiagnosticCode(this.value);

  final String value;
}

/// User-safe result returned after an internal exception has been reported.
final class ProductionSafeFailure {
  const ProductionSafeFailure({
    required this.code,
    required this.summary,
  });

  final ProductionDiagnosticCode code;
  final String summary;

  String get userMessage => '$summary [${code.value}]';
}

/// Production boundary for unexpected internal failures.
///
/// The original exception and stack trace are retained in Flutter diagnostics,
/// while callers receive only a stable code and an explicitly supplied safe
/// summary. Internal exception text must never be interpolated into UI copy.
abstract final class ProductionErrorBoundary {
  static ProductionSafeFailure report({
    required Object error,
    required StackTrace stackTrace,
    required ProductionDiagnosticCode code,
    required String safeSummary,
    required String library,
    required String operation,
  }) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: library,
        context: ErrorDescription('$operation [${code.value}]'),
      ),
    );
    return ProductionSafeFailure(code: code, summary: safeSummary);
  }
}
