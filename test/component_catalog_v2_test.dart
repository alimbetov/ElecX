import 'package:elecx/src/domain/component_catalog_v2.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/room_environment.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ComponentCatalogV2', () {
    test('socket is wall-only and uses power cable sizing', () {
      final socket = ComponentCatalogV2.require('power.socket.general');

      expect(socket.systemClass, EngineeringSystemClass.powerAc);
      expect(
        socket.calculationKind,
        EngineeringCalculationKind.powerCableSizing,
      );
      expect(socket.mounting.preferredHeightMm, 300);
      expect(socket.canPlaceOn(RoomSurfaceRef.wall('room-1', 0)), isTrue);
      expect(socket.canPlaceOn(RoomSurfaceRef.ceiling('room-1')), isFalse);
    });

    test('PoE camera exposes network port and PoE budget calculation', () {
      final camera = ComponentCatalogV2.require('cctv.camera.poe');

      expect(camera.systemClass, EngineeringSystemClass.cctv);
      expect(camera.calculationKind, EngineeringCalculationKind.poePowerBudget);
      expect(camera.loadDefaults.ratedPowerW, 12);
      expect(camera.loadDefaults.poeClass, 'PoE+');
      expect(
        camera.ports.single.allowedConnections,
        containsAll({
          EngineeringConnectionType.poe,
          EngineeringConnectionType.ethernetCopper,
        }),
      );
    });

    test('smoke detector is ceiling-only and uses fire loop topology', () {
      final detector = ComponentCatalogV2.require('fire.detector.smoke');

      expect(detector.systemClass, EngineeringSystemClass.fireAlarm);
      expect(
        detector.calculationKind,
        EngineeringCalculationKind.fireLoopElectrical,
      );
      expect(detector.canPlaceOn(RoomSurfaceRef.ceiling('room-1')), isTrue);
      expect(detector.canPlaceOn(RoomSurfaceRef.wall('room-1', 0)), isFalse);
      expect(detector.ports, hasLength(2));
      expect(
        detector.ports.every(
          (port) =>
              port.allowedConnections.contains(EngineeringConnectionType.fireLoop),
        ),
        isTrue,
      );
    });

    test('room environment can reject an otherwise valid surface', () {
      final socket = ComponentCatalogV2.require('power.socket.general');
      final wetBathroom = RoomEnvironment(
        roomId: 'bath-1',
        usageType: RoomUsageType.bathroom,
        temperatureRegime: TemperatureRegime.heated,
        designMinC: 18,
        designMaxC: 28,
        designNominalC: 24,
        maxRelativeHumidityPercent: 95,
        wetZone: true,
      );

      final violations = socket.validatePlacement(
        surface: RoomSurfaceRef.wall('bath-1', 0),
        roomEnvironment: wetBathroom,
      );

      expect(
        violations.map((item) => item.kind),
        contains(ComponentPlacementViolationKind.wetZoneNotAllowed),
      );
      expect(
        violations.map((item) => item.kind),
        contains(ComponentPlacementViolationKind.humidityTooHigh),
      );
    });

    test('catalog can be filtered by system and surface', () {
      final fire = ComponentCatalogV2.forSystem(EngineeringSystemClass.fireAlarm);
      expect(fire.map((item) => item.id), contains('fire.detector.smoke'));

      final ceiling = ComponentCatalogV2.forSurface(SurfacePlaneType.ceiling);
      expect(ceiling.map((item) => item.id), contains('data.wifi-ap.poe'));
      expect(ceiling.map((item) => item.id), contains('cctv.camera.poe'));
      expect(ceiling.map((item) => item.id), isNot(contains('power.socket.general')));
    });
  });
}
