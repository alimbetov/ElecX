import 'package:elecx/src/domain/wall_profile.dart';
import 'package:elecx/src/engine/wall_profile_plan_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rectangular wall projects as a flat upper contour', () {
    final profile = WallProfile.rectangle(widthMm: 4000, heightMm: 3000);

    final contour = WallProfilePlanProjection.topContour(profile);

    expect(contour.length, 2);
    expect(contour.first.xMm, 0);
    expect(contour.last.xMm, 4000);
    expect(contour.every((point) => point.depthFromTopMm == 0), isTrue);
    expect(WallProfilePlanProjection.hasVerticalVariation(profile), isFalse);
  });

  test('beam notch projects as a stepped upper contour', () {
    final profile = WallProfile.rectangle(
      widthMm: 4000,
      heightMm: 3000,
    ).withTopNotch(startMm: 1200, widthMm: 800, depthMm: 450);

    final contour = WallProfilePlanProjection.topContour(profile);

    expect(contour.map((point) => point.xMm), [
      0,
      1200,
      1200,
      2000,
      2000,
      4000,
    ]);
    expect(contour.map((point) => point.depthFromTopMm), [
      0,
      0,
      450,
      450,
      0,
      0,
    ]);
    expect(WallProfilePlanProjection.hasVerticalVariation(profile), isTrue);
  });

  test('sloped top keeps ordered plan projection', () {
    final profile = WallProfile.rectangle(widthMm: 3000, heightMm: 3000)
        .withTopPolyline(const [
      WallProfilePoint(0, 3000),
      WallProfilePoint(1500, 2700),
      WallProfilePoint(3000, 2400),
    ]);

    final contour = WallProfilePlanProjection.topContour(profile);

    expect(contour.map((point) => point.xMm), [0, 1500, 3000]);
    expect(contour.map((point) => point.depthFromTopMm), [0, 300, 600]);
  });
}
