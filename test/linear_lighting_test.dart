import 'package:elecx/src/domain/linear_lighting.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final surface = RoomSurfaceRef.wall('room-1', 0);

  final spec = LinearLuminaireSpec(
    id: 'led-24v-14w',
    name: 'LED strip 24 V',
    nominalVoltageV: 24,
    powerPerMeterW: 14.4,
    luminousFluxPerMeterLm: 1200,
    maxContinuousLengthMm: 5000,
    cutStepMm: 50,
  );

  test('distributed load derives power, current and light output from length',
      () {
    final run = LinearLuminaireRun(
      id: 'strip-1',
      specId: spec.id,
      surface: surface,
      points: const [SurfacePointMm(0, 2000), SurfacePointMm(4000, 2000)],
      feedMode: LinearLuminaireFeedMode.start,
    );

    final result = LinearLuminaireEngine.summarize(run: run, spec: spec);

    expect(result.lengthMm, 4000);
    expect(result.powerW, closeTo(57.6, 0.001));
    expect(result.currentA, closeTo(2.4, 0.001));
    expect(result.luminousFluxLm, closeTo(4800, 0.001));
    expect(result.requiredFeedSections, 1);
    expect(result.withinContinuousLength, isTrue);
    expect(result.cutStepAligned, isTrue);
  });

  test('long run requests additional feed sections', () {
    final run = LinearLuminaireRun(
      id: 'strip-2',
      specId: spec.id,
      surface: surface,
      points: const [SurfacePointMm(0, 2000), SurfacePointMm(12000, 2000)],
      feedMode: LinearLuminaireFeedMode.bothEnds,
    );

    final result = LinearLuminaireEngine.summarize(run: run, spec: spec);
    final validation = LinearLuminaireEngine.validate(run: run, spec: spec);

    expect(result.requiredFeedSections, 3);
    expect(result.withinContinuousLength, isFalse);
    expect(validation.isValid, isTrue);
    expect(
      validation.issues.any(
        (issue) =>
            issue.code ==
            LinearLuminaireValidationCode.continuousLengthExceeded,
      ),
      isTrue,
    );
  });

  test('requested length snaps to strip cut step without collapsing to zero',
      () {
    expect(
      LinearLuminaireEngine.snapLengthToCutStep(
        requestedLengthMm: 1032,
        spec: spec,
      ),
      1050,
    );
    expect(
      LinearLuminaireEngine.snapLengthToCutStep(
        requestedLengthMm: 1,
        spec: spec,
      ),
      50,
    );
    expect(
      LinearLuminaireEngine.snapLengthToCutStep(
        requestedLengthMm: 0,
        spec: spec,
      ),
      0,
    );
  });

  test('actual run that misses a cut mark is non-committable', () {
    final run = LinearLuminaireRun(
      id: 'strip-cut-error',
      specId: spec.id,
      surface: surface,
      points: const [SurfacePointMm(0, 0), SurfacePointMm(1032, 0)],
      feedMode: LinearLuminaireFeedMode.start,
    );

    final validation = LinearLuminaireEngine.validate(run: run, spec: spec);

    expect(validation.summary.cutStepAligned, isFalse);
    expect(validation.isValid, isFalse);
    expect(
      validation.issues.any(
        (issue) =>
            issue.code == LinearLuminaireValidationCode.cutStepMismatch &&
            issue.severity == LinearLuminaireValidationSeverity.error,
      ),
      isTrue,
    );
  });

  test('matching driver validates voltage and design power headroom', () {
    final run = LinearLuminaireRun(
      id: 'strip-driver-ok',
      specId: spec.id,
      surface: surface,
      points: const [SurfacePointMm(0, 0), SurfacePointMm(4000, 0)],
      feedMode: LinearLuminaireFeedMode.start,
      driverComponentId: 'driver-1',
    );
    final driver = LinearLuminaireDriverEvidence(
      componentId: 'driver-1',
      outputVoltageV: 24,
      ratedPowerW: 100,
      designLoadFraction: 0.8,
    );

    final validation = LinearLuminaireEngine.validate(
      run: run,
      spec: spec,
      driver: driver,
    );

    expect(validation.isValid, isTrue);
    expect(validation.hasWarnings, isFalse);
  });

  test('driver voltage mismatch and insufficient usable power are errors', () {
    final run = LinearLuminaireRun(
      id: 'strip-driver-bad',
      specId: spec.id,
      surface: surface,
      points: const [SurfacePointMm(0, 0), SurfacePointMm(4000, 0)],
      feedMode: LinearLuminaireFeedMode.start,
      driverComponentId: 'driver-1',
    );
    final driver = LinearLuminaireDriverEvidence(
      componentId: 'driver-1',
      outputVoltageV: 12,
      ratedPowerW: 60,
      designLoadFraction: 0.8,
    );

    final validation = LinearLuminaireEngine.validate(
      run: run,
      spec: spec,
      driver: driver,
    );

    expect(validation.isValid, isFalse);
    expect(
      validation.issues.map((issue) => issue.code),
      containsAll([
        LinearLuminaireValidationCode.driverVoltageMismatch,
        LinearLuminaireValidationCode.driverPowerInsufficient,
      ]),
    );
  });

  test('assigned driver without evidence remains explicitly indeterminate', () {
    final run = LinearLuminaireRun(
      id: 'strip-driver-unknown',
      specId: spec.id,
      surface: surface,
      points: const [SurfacePointMm(0, 0), SurfacePointMm(2000, 0)],
      feedMode: LinearLuminaireFeedMode.start,
      driverComponentId: 'driver-unknown',
    );

    final validation = LinearLuminaireEngine.validate(run: run, spec: spec);

    expect(validation.isValid, isTrue);
    expect(validation.hasWarnings, isTrue);
    expect(
      validation.issues.any(
        (issue) =>
            issue.code == LinearLuminaireValidationCode.driverEvidenceMissing,
      ),
      isTrue,
    );
  });

  test('run rejects zero-length geometry', () {
    expect(
      () => LinearLuminaireRun(
        id: 'strip-zero',
        specId: spec.id,
        surface: surface,
        points: const [SurfacePointMm(100, 100), SurfacePointMm(100, 100)],
        feedMode: LinearLuminaireFeedMode.start,
      ),
      throwsArgumentError,
    );
  });

  test('both-end feed is rejected when the product forbids it', () {
    final oneEndOnly = LinearLuminaireSpec(
      id: 'one-end-only',
      name: 'One-end LED strip',
      nominalVoltageV: 24,
      powerPerMeterW: 10,
      luminousFluxPerMeterLm: 900,
      maxContinuousLengthMm: 5000,
      feedFromBothEndsAllowed: false,
    );
    final run = LinearLuminaireRun(
      id: 'strip-both-ends',
      specId: oneEndOnly.id,
      surface: surface,
      points: const [SurfacePointMm(0, 0), SurfacePointMm(3000, 0)],
      feedMode: LinearLuminaireFeedMode.bothEnds,
    );

    expect(
      () => LinearLuminaireEngine.summarize(run: run, spec: oneEndOnly),
      throwsArgumentError,
    );
    final validation = LinearLuminaireEngine.validate(
      run: run,
      spec: oneEndOnly,
    );
    expect(validation.isValid, isFalse);
    expect(
      validation.issues.any(
        (issue) =>
            issue.code == LinearLuminaireValidationCode.unsupportedFeedMode,
      ),
      isTrue,
    );
  });

  test('run geometry is immutable after construction', () {
    final mutable = <SurfacePointMm>[
      const SurfacePointMm(0, 0),
      const SurfacePointMm(1000, 0),
    ];
    final run = LinearLuminaireRun(
      id: 'strip-immutable',
      specId: spec.id,
      surface: surface,
      points: mutable,
      feedMode: LinearLuminaireFeedMode.start,
    );

    mutable[1] = const SurfacePointMm(5000, 0);

    expect(run.geometricLengthMm, 1000);
    expect(
      () => run.points.add(const SurfacePointMm(2000, 0)),
      throwsUnsupportedError,
    );
  });
}
