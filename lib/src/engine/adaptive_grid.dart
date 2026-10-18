import 'dart:math' as math;

final class AdaptiveGridSpec {
  const AdaptiveGridSpec({
    required this.minorStepMm,
    required this.majorStepMm,
    required this.showMinor,
  });

  final int minorStepMm;
  final int majorStepMm;
  final bool showMinor;
}

/// Chooses grid spacing from camera scale so line density remains bounded.
abstract final class AdaptiveGridPolicy {
  static const List<int> _stepsMm = <int>[
    10,
    20,
    50,
    100,
    200,
    500,
    1000,
    2000,
    5000,
    10000,
    20000,
    50000,
    100000,
  ];

  static AdaptiveGridSpec forScale(
    double mmPerPixel, {
    double targetMinorSpacingPx = 28,
    int majorEvery = 5,
  }) {
    if (mmPerPixel <= 0) {
      throw ArgumentError.value(mmPerPixel, 'mmPerPixel', 'Must be positive.');
    }
    final targetMm = math.max(1.0, mmPerPixel * targetMinorSpacingPx);
    var step = _stepsMm.last;
    for (final candidate in _stepsMm) {
      if (candidate >= targetMm) {
        step = candidate;
        break;
      }
    }
    final spacingPx = step / mmPerPixel;
    return AdaptiveGridSpec(
      minorStepMm: step,
      majorStepMm: step * majorEvery,
      showMinor: spacingPx >= 18,
    );
  }
}
