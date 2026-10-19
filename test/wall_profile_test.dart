import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/domain/wall_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('beam notch reduces usable wall area', () {
    final profile = WallProfile.rectangle(
      widthMm: 4000,
      heightMm: 3000,
    ).withTopNotch(startMm: 1000, widthMm: 1200, depthMm: 500);

    expect(profile.containsPoint(500, 2900), isTrue);
    expect(profile.containsPoint(1500, 2900), isFalse);
    expect(profile.containsPoint(1500, 2400), isTrue);
  });

  test(
    'sloped top profile accepts points below slope and rejects above it',
    () {
      final profile = WallProfile.rectangle(widthMm: 4000, heightMm: 3000)
          .withTopPolyline(const [
            WallProfilePoint(0, 3000),
            WallProfilePoint(2000, 2600),
            WallProfilePoint(4000, 2200),
          ]);

      expect(profile.containsPoint(3500, 2000), isTrue);
      expect(profile.containsPoint(3500, 2500), isFalse);
    },
  );

  test('opening validation respects custom wall profile', () {
    final boundary = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
    final profile = WallProfile.rectangle(
      widthMm: 4000,
      heightMm: 3000,
    ).withTopNotch(startMm: 1000, widthMm: 1200, depthMm: 700);
    final room = EngineeringSpace(
      id: 'room-a',
      name: 'Room A',
      type: SpaceType.room,
      boundary: boundary,
      referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
      wallProfiles: {0: profile},
    );
    final wall = RoomSurfaceResolver.wall(room, 0);

    final lowDoor = ArchitecturalOpening(
      id: 'door-ok',
      hostWall: wall.ref,
      type: ArchitecturalOpeningType.door,
      offsetFromStartMm: 1200,
      widthMm: 900,
      heightMm: 2100,
      sillHeightMm: 0,
    );
    final tallOpening = ArchitecturalOpening(
      id: 'opening-bad',
      hostWall: wall.ref,
      type: ArchitecturalOpeningType.window,
      offsetFromStartMm: 1200,
      widthMm: 900,
      heightMm: 800,
      sillHeightMm: 1900,
    );

    expect(
      RoomSurfaceResolver.openingFitsWall(opening: lowDoor, wall: wall),
      isTrue,
    );
    expect(
      RoomSurfaceResolver.openingFitsWall(opening: tallOpening, wall: wall),
      isFalse,
    );
  });
}
