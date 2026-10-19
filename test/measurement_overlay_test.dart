import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/measurement_overlay.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/domain/wall_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final wall = RoomWallSurface(
    ref: RoomSurfaceRef.wall('room', 0),
    start: const MmPoint(0, 0),
    end: const MmPoint(5000, 0),
    heightMm: 3000,
    profile: WallProfile.rectangle(widthMm: 5000, heightMm: 3000),
  );

  test('opening measurements expose clearances and object size', () {
    final opening = ArchitecturalOpening(
      id: 'window',
      hostWall: wall.ref,
      type: ArchitecturalOpeningType.window,
      offsetFromStartMm: 800,
      widthMm: 1400,
      heightMm: 1200,
      sillHeightMm: 900,
    );

    final set = WallMeasurementResolver.forOpening(
      opening: opening,
      wall: wall,
    );
    final byRole = {for (final span in set.spans) span.role: span.valueMm};

    expect(byRole[MeasurementRole.clearanceLeft], 800);
    expect(byRole[MeasurementRole.clearanceRight], 2800);
    expect(byRole[MeasurementRole.clearanceBottom], 900);
    expect(byRole[MeasurementRole.clearanceTop], 900);
    expect(byRole[MeasurementRole.objectWidth], 1400);
    expect(byRole[MeasurementRole.objectHeight], 1200);
  });

  test('beam measurements expose wall offsets width depth and bottom level',
      () {
    final set = WallMeasurementResolver.forTopNotch(
      startMm: 1000,
      widthMm: 1200,
      depthMm: 400,
      wall: wall,
    );
    final byRole = {for (final span in set.spans) span.role: span.valueMm};

    expect(byRole[MeasurementRole.clearanceLeft], 1000);
    expect(byRole[MeasurementRole.clearanceRight], 2800);
    expect(byRole[MeasurementRole.objectWidth], 1200);
    expect(byRole[MeasurementRole.structuralDepth], 400);
    expect(byRole[MeasurementRole.clearanceBottom], 2600);
  });
}
