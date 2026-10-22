import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/site_orientation.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/daylight_assist_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project north converts plan azimuth to true azimuth', () {
    const north = ProjectNorth(northAzimuthDegrees: 30);

    expect(north.toTrueAzimuth(0), 330);
    expect(north.toTrueAzimuth(90), 60);
    expect(north.toTrueAzimuth(350), 320);
    const eastNorth = ProjectNorth(northAzimuthDegrees: 90);
    expect(eastNorth.toTrueAzimuth(90), 0);
  });

  test(
    'hemisphere-aware orientation weighting requires physical site context',
    () {
      const north = ProjectNorth();
      const site = SolarSiteContext(
        latitudeDegrees: 43.2,
        longitudeDegrees: 76.9,
        timeZoneOffsetMinutes: 300,
      );
      final wall = RoomSurfaceRef.wall('room-1', 0);
      final southWindow = DaylightWindowInput(
        id: 'south',
        wall: wall,
        centerOffsetMm: 1500,
        sillHeightMm: 900,
        widthMm: 1800,
        heightMm: 1500,
        wallPlanAzimuthDegrees: 180,
      );
      final northWindow = DaylightWindowInput(
        id: 'north',
        wall: wall,
        centerOffsetMm: 1500,
        sillHeightMm: 900,
        widthMm: 1800,
        heightMm: 1500,
        wallPlanAzimuthDegrees: 0,
      );

      final south = DaylightAssistEngine.reachForWindow(
        window: southWindow,
        projectNorth: north,
        solarContext: site,
      );
      final northReach = DaylightAssistEngine.reachForWindow(
        window: northWindow,
        projectNorth: north,
        solarContext: site,
      );

      expect(south.effectiveDepthMm, greaterThan(northReach.effectiveDepthMm));
      expect(
        south.centerlineStrength,
        greaterThan(northReach.centerlineStrength),
      );
    },
  );

  test('compass alone does not fabricate facade daylight advantage', () {
    const north = ProjectNorth();
    final wall = RoomSurfaceRef.wall('room-1', 0);
    final southWindow = DaylightWindowInput(
      id: 'south',
      wall: wall,
      centerOffsetMm: 1500,
      sillHeightMm: 900,
      widthMm: 1800,
      heightMm: 1500,
      wallPlanAzimuthDegrees: 180,
    );
    final northWindow = DaylightWindowInput(
      id: 'north',
      wall: wall,
      centerOffsetMm: 1500,
      sillHeightMm: 900,
      widthMm: 1800,
      heightMm: 1500,
      wallPlanAzimuthDegrees: 0,
    );

    final south = DaylightAssistEngine.reachForWindow(
      window: southWindow,
      projectNorth: north,
    );
    final northReach = DaylightAssistEngine.reachForWindow(
      window: northWindow,
      projectNorth: north,
    );

    expect(south.effectiveDepthMm, northReach.effectiveDepthMm);
    expect(south.centerlineStrength, northReach.centerlineStrength);
  });

  test('ceiling hints bias artificial lighting toward deeper room zone', () {
    const zone = DaylightReachZone(
      windowId: 'window-1',
      facadeAzimuthDegrees: 180,
      nominalDepthMm: 2500,
      effectiveDepthMm: 2200,
      centerlineStrength: 0.8,
    );

    final hints = DaylightAssistEngine.ceilingHints(
      roomWidthMm: 4000,
      roomDepthMm: 6000,
      daylight: zone,
      preferredSpacingMm: 1800,
    );

    expect(hints, isNotEmpty);
    expect(hints.every((hint) => hint.position.yMm > 2200), isTrue);
  });

  test(
    'room geometry derives inward vector and facade azimuth from host wall',
    () {
      final room = EngineeringSpace(
        id: 'room-1',
        name: 'Room',
        type: SpaceType.room,
        boundary: MmPolygon.rectangle(
          const MmPoint(0, 0),
          const MmPoint(4000, 3000),
        ),
        referenceFrame: const RoomReferenceFrame(origin: MmPoint(2000, 1500)),
      );
      final window = DaylightWindowInput(
        id: 'east-window',
        wall: RoomSurfaceRef.wall(room.id, 1),
        centerOffsetMm: 1500,
        sillHeightMm: 900,
        widthMm: 1200,
        heightMm: 1400,
        // Deliberately inconsistent imported value. Editor geometry must win.
        wallPlanAzimuthDegrees: 0,
      );

      final frame = DaylightAssistEngine.planFrameForWindow(
        window: window,
        room: room,
      );
      final reach = DaylightAssistEngine.reachForWindowOnRoom(
        window: window,
        room: room,
        projectNorth: const ProjectNorth(),
      );

      expect(frame.windowCenter, const MmPoint(4000, 1500));
      expect(frame.inwardX, closeTo(-1, 0.0001));
      expect(frame.inwardY, closeTo(0, 0.0001));
      expect(frame.facadePlanAzimuthDegrees, closeTo(90, 0.0001));
      expect(reach.facadeAzimuthDegrees, closeTo(90, 0.0001));
      expect(frame.depthMm(const MmPoint(1000, 1500)), closeTo(3000, 0.01));
    },
  );

  test(
    'orientation-aware hints increase artificial-light priority deeper inside',
    () {
      final room = EngineeringSpace(
        id: 'room-1',
        name: 'Room',
        type: SpaceType.room,
        boundary: MmPolygon.rectangle(
          const MmPoint(0, 0),
          const MmPoint(4000, 3000),
        ),
        referenceFrame: const RoomReferenceFrame(origin: MmPoint(2000, 1500)),
      );
      final window = DaylightWindowInput(
        id: 'east-window',
        wall: RoomSurfaceRef.wall(room.id, 1),
        centerOffsetMm: 1500,
        sillHeightMm: 900,
        widthMm: 1600,
        heightMm: 1400,
        wallPlanAzimuthDegrees: 90,
      );
      final reach = DaylightAssistEngine.reachForWindowOnRoom(
        window: window,
        room: room,
        projectNorth: const ProjectNorth(),
      );

      final hints = DaylightAssistEngine.ceilingHintsForRoom(
        room: room,
        window: window,
        daylight: reach,
        preferredSpacingMm: 1000,
      );

      expect(hints, isNotEmpty);
      final nearWindow = hints.reduce(
        (a, b) => a.position.xMm > b.position.xMm ? a : b,
      );
      final deepRoom = hints.reduce(
        (a, b) => a.position.xMm < b.position.xMm ? a : b,
      );
      expect(deepRoom.priority, greaterThan(nearWindow.priority));
      expect(
        deepRoom.daylightInfluence,
        lessThan(nearWindow.daylightInfluence),
      );
    },
  );

  test('room-aware daylight rejects window geometry outside host wall', () {
    final room = EngineeringSpace(
      id: 'room-1',
      name: 'Room',
      type: SpaceType.room,
      boundary: MmPolygon.rectangle(
        const MmPoint(0, 0),
        const MmPoint(2000, 2000),
      ),
      referenceFrame: const RoomReferenceFrame(origin: MmPoint(1000, 1000)),
    );
    final invalid = DaylightWindowInput(
      id: 'too-wide',
      wall: RoomSurfaceRef.wall(room.id, 0),
      centerOffsetMm: 250,
      sillHeightMm: 900,
      widthMm: 1000,
      heightMm: 1000,
      wallPlanAzimuthDegrees: 180,
    );

    expect(
      () =>
          DaylightAssistEngine.planFrameForWindow(window: invalid, room: room),
      throwsArgumentError,
    );
  });

  test(
    'daylight input rejects non-wall surfaces and invalid transmittance',
    () {
      expect(
        () => DaylightWindowInput(
          id: 'invalid-floor-window',
          wall: RoomSurfaceRef.floor('room-1'),
          centerOffsetMm: 1000,
          sillHeightMm: 900,
          widthMm: 1200,
          heightMm: 1400,
          wallPlanAzimuthDegrees: 180,
        ),
        throwsArgumentError,
      );

      expect(
        () => DaylightWindowInput(
          id: 'invalid-vlt',
          wall: RoomSurfaceRef.wall('room-1', 0),
          centerOffsetMm: 1000,
          sillHeightMm: 900,
          widthMm: 1200,
          heightMm: 1400,
          wallPlanAzimuthDegrees: 180,
          visibleLightTransmittance: 1.2,
        ),
        throwsArgumentError,
      );
    },
  );
}
