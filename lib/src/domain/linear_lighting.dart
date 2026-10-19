import 'dart:math' as math;

import 'surfaces.dart';

/// Technology-independent linear luminaire specification. LED strip is the
/// first implementation, but the geometry can also represent linear profiles
/// and continuous luminaires later.
final class LinearLuminaireSpec {
  LinearLuminaireSpec({
    required this.id,
    required this.name,
    required this.nominalVoltageV,
    required this.powerPerMeterW,
    required this.luminousFluxPerMeterLm,
    required this.maxContinuousLengthMm,
    this.cutStepMm = 50,
    this.feedFromBothEndsAllowed = true,
    this.profileWidthMm = 12,
  }) {
    if (id.isEmpty || name.isEmpty) {
      throw ArgumentError('Linear luminaire identity must be non-empty.');
    }
    if (nominalVoltageV <= 0 ||
        powerPerMeterW <= 0 ||
        luminousFluxPerMeterLm <= 0 ||
        maxContinuousLengthMm <= 0 ||
        cutStepMm <= 0 ||
        profileWidthMm <= 0) {
      throw ArgumentError(
        'Linear luminaire electrical/geometry values must be positive.',
      );
    }
  }

  final String id;
  final String name;
  final double nominalVoltageV;
  final double powerPerMeterW;
  final double luminousFluxPerMeterLm;
  final int maxContinuousLengthMm;
  final int cutStepMm;
  final bool feedFromBothEndsAllowed;
  final int profileWidthMm;
}

enum LinearLuminaireFeedMode { start, end, bothEnds, center }

final class LinearLuminaireRun {
  LinearLuminaireRun({
    required this.id,
    required this.specId,
    required this.surface,
    required List<SurfacePointMm> points,
    required this.feedMode,
    this.driverComponentId,
  }) : points = List.unmodifiable(points) {
    if (id.isEmpty || specId.isEmpty) {
      throw ArgumentError('Linear luminaire run identity must be non-empty.');
    }
    if (points.length < 2) {
      throw ArgumentError('Linear luminaire run needs at least two points.');
    }
    if (_lengthOf(points) <= 0) {
      throw ArgumentError('Linear luminaire run must have positive length.');
    }
  }

  final String id;
  final String specId;
  final RoomSurfaceRef surface;
  final List<SurfacePointMm> points;
  final LinearLuminaireFeedMode feedMode;

  /// Optional reference to a 12/24/48 V LED driver or other supply component.
  final String? driverComponentId;

  double get geometricLengthMm => _lengthOf(points);

  LinearLuminaireRun copyWith({
    List<SurfacePointMm>? points,
    LinearLuminaireFeedMode? feedMode,
    String? driverComponentId,
    bool clearDriver = false,
  }) =>
      LinearLuminaireRun(
        id: id,
        specId: specId,
        surface: surface,
        points: points ?? this.points,
        feedMode: feedMode ?? this.feedMode,
        driverComponentId:
            clearDriver ? null : driverComponentId ?? this.driverComponentId,
      );

  static double _lengthOf(List<SurfacePointMm> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final dx = (b.xMm - a.xMm).toDouble();
      final dy = (b.yMm - a.yMm).toDouble();
      total += math.sqrt(dx * dx + dy * dy);
    }
    return total;
  }
}

final class LinearLuminaireElectricalSummary {
  const LinearLuminaireElectricalSummary({
    required this.lengthMm,
    required this.powerW,
    required this.luminousFluxLm,
    required this.currentA,
    required this.requiredFeedSections,
    required this.withinContinuousLength,
  });

  final int lengthMm;
  final double powerW;
  final double luminousFluxLm;
  final double currentA;
  final int requiredFeedSections;
  final bool withinContinuousLength;
}

abstract final class LinearLuminaireEngine {
  static LinearLuminaireElectricalSummary summarize({
    required LinearLuminaireRun run,
    required LinearLuminaireSpec spec,
  }) {
    if (run.specId != spec.id) {
      throw ArgumentError('Run specId does not match luminaire specification.');
    }
    if (run.feedMode == LinearLuminaireFeedMode.bothEnds &&
        !spec.feedFromBothEndsAllowed) {
      throw ArgumentError(
        'The selected linear luminaire does not allow feed from both ends.',
      );
    }

    final lengthMm = run.geometricLengthMm.round();
    final lengthM = lengthMm / 1000.0;
    final powerW = lengthM * spec.powerPerMeterW;
    final currentA = powerW / spec.nominalVoltageV;
    final fluxLm = lengthM * spec.luminousFluxPerMeterLm;
    final sections = math.max(
      1,
      (lengthMm / spec.maxContinuousLengthMm).ceil(),
    );
    return LinearLuminaireElectricalSummary(
      lengthMm: lengthMm,
      powerW: powerW,
      luminousFluxLm: fluxLm,
      currentA: currentA,
      requiredFeedSections: sections,
      withinContinuousLength: lengthMm <= spec.maxContinuousLengthMm,
    );
  }

  static int snapLengthToCutStep({
    required int requestedLengthMm,
    required LinearLuminaireSpec spec,
  }) {
    if (requestedLengthMm < 0) {
      throw ArgumentError.value(requestedLengthMm, 'requestedLengthMm');
    }
    if (requestedLengthMm == 0) return 0;
    final snapped =
        (requestedLengthMm / spec.cutStepMm).round() * spec.cutStepMm;
    return math.max(spec.cutStepMm, snapped);
  }
}
