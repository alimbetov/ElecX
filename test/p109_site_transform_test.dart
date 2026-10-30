import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/project_site_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'all canonical quarter turns have exact reversible integer-mm frame transforms',
      () {
    const local = BoundaryPointMm(xMm: 1237, yMm: 4561);
    const expected = [
      (1237, 4561),
      (4561, -1237),
      (-1237, -4561),
      (-4561, 1237)
    ];
    for (var turn = 0; turn < 4; turn++) {
      final placement = ProjectBuildingSitePlacement(
          xMm: 100000,
          yMm: -200000,
          orientation: ProjectEngineeringNorth.fromDegrees(turn * 90.0),
          widthMm: 10000,
          depthMm: 20000);
      final point = placement.toSite(local);
      expect(
          point,
          BoundaryPointMm(
              xMm: 100000 + expected[turn].$1,
              yMm: -200000 + expected[turn].$2));
      expect(placement.toBuilding(point), local);
      expect(placement.siteFootprint.areaMm2, 200000000);
    }
  });
  test(
      'equivalent normalized compass values produce the same canonical placement',
      () {
    ProjectBuildingSitePlacement placement(double angle) =>
        ProjectBuildingSitePlacement(
            xMm: 0,
            yMm: 0,
            orientation: ProjectEngineeringNorth.fromDegrees(angle),
            widthMm: 10000,
            depthMm: 20000);
    expect(placement(-90).sameAs(placement(270)), isTrue);
    expect(placement(360).sameAs(placement(0)), isTrue);
    expect(placement(450).sameAs(placement(90)), isTrue);
  });
  test(
      'small footprints retain exact area at the positive and negative Site coordinate limits',
      () {
    for (final origin in [-999999980, 999999980]) {
      for (var turns = 0; turns < 4; turns++) {
        final placement = ProjectBuildingSitePlacement(
            xMm: origin,
            yMm: origin,
            orientation: ProjectEngineeringNorth.fromDegrees(turns * 90.0),
            widthMm: 10,
            depthMm: 10);
        expect(placement.siteFootprint.areaMm2, 100);
        expect(placement.siteFootprint.vertices.length, 4);
      }
    }
  });
}
