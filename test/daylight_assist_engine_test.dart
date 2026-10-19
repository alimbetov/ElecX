import 'package:elecx/src/domain/site_orientation.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/daylight_assist_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project north converts plan azimuth to true azimuth', () {
    const north = ProjectNorth(northAzimuthDegrees: 30);

    expect(north.toTrueAzimuth(0), 30);
    expect(north.toTrueAzimuth(90), 120);
    expect(north.toTrueAzimuth(350), 20);
  });

  test('south-facing window receives stronger daylight assist than north-facing', () {
    const north = ProjectNorth();
    final wall = RoomSurfaceRef.wall('room-1', 0);
    final common = DaylightWindowInput(
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
      window: common,
      projectNorth: north,
    );
    final northReach = DaylightAssistEngine.reachForWindow(
      window: northWindow,
      projectNorth: north,
    );

    expect(south.effectiveDepthMm, greaterThan(northReach.effectiveDepthMm));
    expect(south.centerlineStrength, greaterThan(northReach.centerlineStrength));
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
}
