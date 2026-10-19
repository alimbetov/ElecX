enum AnalysisSeverityWeight { info, warning, error }

/// Policy object for drawing simulation and optimization.
///
/// The engine remains deterministic and profile-driven: project/normative
/// layers may provide stricter thresholds without hard-coding country or
/// discipline rules into geometry/routing code.
final class EngineeringAnalysisProfile {
  const EngineeringAnalysisProfile({
    this.routeImprovementThreshold = 0.10,
    this.maxSurfaceTransitions = 3,
    this.maxRouteBends = 6,
    this.componentClearanceMm = 100,
    this.errorPenalty = 20,
    this.warningPenalty = 7,
    this.infoPenalty = 2,
  }) : assert(routeImprovementThreshold >= 0),
       assert(maxSurfaceTransitions >= 0),
       assert(maxRouteBends >= 0),
       assert(componentClearanceMm >= 0),
       assert(errorPenalty >= 0),
       assert(warningPenalty >= 0),
       assert(infoPenalty >= 0);

  final double routeImprovementThreshold;
  final int maxSurfaceTransitions;
  final int maxRouteBends;

  /// Minimum center-to-center distance used by the generic placement audit.
  /// Component-specific envelopes can replace this in catalog V3.
  final int componentClearanceMm;

  final int errorPenalty;
  final int warningPenalty;
  final int infoPenalty;

  int penaltyFor(AnalysisSeverityWeight severity) => switch (severity) {
    AnalysisSeverityWeight.error => errorPenalty,
    AnalysisSeverityWeight.warning => warningPenalty,
    AnalysisSeverityWeight.info => infoPenalty,
  };

  static const standard = EngineeringAnalysisProfile();
}
