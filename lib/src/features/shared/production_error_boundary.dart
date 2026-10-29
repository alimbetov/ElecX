import 'package:flutter/foundation.dart';

typedef ProductionDiagnosticSink = void Function(FlutterErrorDetails details);

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

/// User-safe result returned after an internal exception has been captured.
final class ProductionSafeFailure {
  const ProductionSafeFailure({
    required this.code,
    required this.summary,
  });

  final ProductionDiagnosticCode code;
  final String summary;

  String get userMessage => '$summary [${code.value}]';
}

/// Production boundary for handled internal failures.
///
/// The original exception and stack trace are retained in diagnostics, while
/// callers receive only a stable code and an explicitly supplied safe summary.
/// A handled failure is deliberately not sent through [FlutterError.reportError]
/// because that channel represents uncaught framework/application failures.
abstract final class ProductionErrorBoundary {
  static ProductionSafeFailure report({
    required Object error,
    required StackTrace stackTrace,
    required ProductionDiagnosticCode code,
    required String safeSummary,
    required String library,
    required String operation,
    ProductionDiagnosticSink? diagnosticSink,
  }) {
    final details = FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: library,
      context: ErrorDescription('$operation [${code.value}]'),
    );
    (diagnosticSink ?? _dumpDiagnostic)(details);
    return ProductionSafeFailure(code: code, summary: safeSummary);
  }

  static void _dumpDiagnostic(FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details, forceReport: true);
  }
}
