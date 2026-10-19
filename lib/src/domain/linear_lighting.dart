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

/// Electrical evidence for the driver actually assigned to a run.
///
/// [designLoadFraction] is project/product policy, not a hidden normative
/// constant. 0.8 means the editor intentionally uses at most 80% of the
/// driver's nameplate power for this design check.
final class LinearLuminaireDriverEvidence {
  LinearLuminaireDriverEvidence({
    required this.componentId,
    required this.outputVoltageV,
    required this.ratedPowerW,
    this.designLoadFraction = 0.8,
  }) {
    if (componentId.isEmpty) {
      throw ArgumentError('Driver component id must be non-empty.');
    }
    if (outputVoltageV <= 0 || ratedPowerW <= 0) {
      throw ArgumentError('Driver voltage and power must be positive.');
    }
    if (designLoadFraction <= 0 || designLoadFraction > 1) {
      throw ArgumentError.value(
        designLoadFraction,
        'designLoadFraction',
        'Must be in (0, 1].',
      );
    }
  }

  final String componentId;
  final double outputVoltageV;
  final double ratedPowerW;
  final double designLoadFraction;

  double get usablePowerW => ratedPowerW * designLoadFraction;
}

final class LinearLuminaireElectricalSummary {
  const LinearLuminaireElectricalSummary({
    required this.lengthMm,
    required this.powerW,
    required this.luminousFluxLm,
    required this.currentA,
    required this.requiredFeedSections,
    required this.withinContinuousLength,
    required this.cutStepAligned,
  });

  final int lengthMm;
  final double powerW;
  final double luminousFluxLm;
  final double currentA;
  final int requiredFeedSections;
  final bool withinContinuousLength;
  final bool cutStepAligned;
}

enum LinearLuminaireValidationSeverity { warning, error }

enum LinearLuminaireValidationCode {
  cutStepMismatch,
  continuousLengthExceeded,
  unsupportedFeedMode,
  driverNotAssigned,
  driverEvidenceMissing,
  driverReferenceMismatch,
  driverVoltageMismatch,
  driverPowerInsufficient,
}

final class LinearLuminaireValidationIssue {
  const LinearLuminaireValidationIssue({
    required this.code,
    required this.severity,
    required this.message,
  });

  final LinearLuminaireValidationCode code;
  final LinearLuminaireValidationSeverity severity;
  final String message;
}

final class LinearLuminaireValidationResult {
  const LinearLuminaireValidationResult({
    required this.summary,
    required this.issues,
  });

  final LinearLuminaireElectricalSummary summary;
  final List<LinearLuminaireValidationIssue> issues;

  bool get isValid => issues.every(
        (issue) => issue.severity != LinearLuminaireValidationSeverity.error,
      );
  bool get hasWarnings => issues.any(
        (issue) => issue.severity == LinearLuminaireValidationSeverity.warning,
      );
}

abstract final class LinearLuminaireEngine {
  static LinearLuminaireElectricalSummary summarize({
    required LinearLuminaireRun run,
    required LinearLuminaireSpec spec,
  }) {
    _checkSpecIdentity(run, spec);
    if (run.feedMode == LinearLuminaireFeedMode.bothEnds &&
        !spec.feedFromBothEndsAllowed) {
      throw ArgumentError(
        'The selected linear luminaire does not allow feed from both ends.',
      );
    }
    return _summarizeUnchecked(run: run, spec: spec);
  }

  /// Validates what is actually evidenced today. Voltage-drop and thermal
  /// behaviour of long low-voltage feeds intentionally remain outside this
  /// result until their inputs/calculation engine exist.
  static LinearLuminaireValidationResult validate({
    required LinearLuminaireRun run,
    required LinearLuminaireSpec spec,
    LinearLuminaireDriverEvidence? driver,
  }) {
    _checkSpecIdentity(run, spec);
    final summary = _summarizeUnchecked(run: run, spec: spec);
    final issues = <LinearLuminaireValidationIssue>[];

    if (!summary.cutStepAligned) {
      issues.add(
        LinearLuminaireValidationIssue(
          code: LinearLuminaireValidationCode.cutStepMismatch,
          severity: LinearLuminaireValidationSeverity.error,
          message:
              'Длина ${summary.lengthMm} мм не кратна шагу резки ${spec.cutStepMm} мм.',
        ),
      );
    }

    if (!summary.withinContinuousLength) {
      issues.add(
        LinearLuminaireValidationIssue(
          code: LinearLuminaireValidationCode.continuousLengthExceeded,
          severity: LinearLuminaireValidationSeverity.warning,
          message:
              'Нужно минимум ${summary.requiredFeedSections} секции питания; одна непрерывная секция превышает ${spec.maxContinuousLengthMm} мм.',
        ),
      );
    }

    if (run.feedMode == LinearLuminaireFeedMode.bothEnds &&
        !spec.feedFromBothEndsAllowed) {
      issues.add(
        const LinearLuminaireValidationIssue(
          code: LinearLuminaireValidationCode.unsupportedFeedMode,
          severity: LinearLuminaireValidationSeverity.error,
          message: 'Эта лента не допускает питание с двух концов.',
        ),
      );
    }

    final driverId = run.driverComponentId;
    if (driverId == null) {
      issues.add(
        const LinearLuminaireValidationIssue(
          code: LinearLuminaireValidationCode.driverNotAssigned,
          severity: LinearLuminaireValidationSeverity.warning,
          message: 'Драйвер не назначен; проверка питания неполна.',
        ),
      );
    } else if (driver == null) {
      issues.add(
        const LinearLuminaireValidationIssue(
          code: LinearLuminaireValidationCode.driverEvidenceMissing,
          severity: LinearLuminaireValidationSeverity.warning,
          message:
              'Для назначенного драйвера отсутствуют электрические параметры.',
        ),
      );
    } else {
      if (driver.componentId != driverId) {
        issues.add(
          const LinearLuminaireValidationIssue(
            code: LinearLuminaireValidationCode.driverReferenceMismatch,
            severity: LinearLuminaireValidationSeverity.error,
            message:
                'Проверяемый драйвер не совпадает с назначенным компонентом.',
          ),
        );
      }
      if ((driver.outputVoltageV - spec.nominalVoltageV).abs() > 0.01) {
        issues.add(
          LinearLuminaireValidationIssue(
            code: LinearLuminaireValidationCode.driverVoltageMismatch,
            severity: LinearLuminaireValidationSeverity.error,
            message:
                'Выход драйвера ${driver.outputVoltageV} V не соответствует ленте ${spec.nominalVoltageV} V.',
          ),
        );
      }
      if (summary.powerW > driver.usablePowerW + 0.001) {
        issues.add(
          LinearLuminaireValidationIssue(
            code: LinearLuminaireValidationCode.driverPowerInsufficient,
            severity: LinearLuminaireValidationSeverity.error,
            message:
                'Нагрузка ${summary.powerW.toStringAsFixed(1)} W превышает проектно допустимые ${driver.usablePowerW.toStringAsFixed(1)} W драйвера.',
          ),
        );
      }
    }

    return LinearLuminaireValidationResult(
      summary: summary,
      issues: List.unmodifiable(issues),
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

  static LinearLuminaireElectricalSummary _summarizeUnchecked({
    required LinearLuminaireRun run,
    required LinearLuminaireSpec spec,
  }) {
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
      cutStepAligned: lengthMm % spec.cutStepMm == 0,
    );
  }

  static void _checkSpecIdentity(
    LinearLuminaireRun run,
    LinearLuminaireSpec spec,
  ) {
    if (run.specId != spec.id) {
      throw ArgumentError('Run specId does not match luminaire specification.');
    }
  }
}
