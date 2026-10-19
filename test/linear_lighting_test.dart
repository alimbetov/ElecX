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

  test('distributed load derives power, current and light output from length', () {
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

    expect(result.requiredFeedSections, 3);
    expect(result.withinContinuousLength, isFalse);
  });

  test('requested length snaps to strip cut step', () {
    expect(
      LinearLuminaireEngine.snapLengthToCutStep(
        requestedLengthMm: 1032,
        spec: spec,
      ),
      1050,
    );
  });
}
