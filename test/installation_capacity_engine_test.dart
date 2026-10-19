import 'package:elecx/src/domain/cable_spec.dart';
import 'package:elecx/src/domain/installation_path.dart';
import 'package:elecx/src/domain/route_host.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/engine/installation_capacity_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final powerCable = CableSpec(
    id: 'vvg-3x2.5',
    name: 'VVGng-LS 3x2.5',
    medium: RouteMediumProfile.acPower,
    outerDiameterMm: 10,
    segregationClass: CableSegregationClass.power,
    conductorMaterial: ConductorMaterial.copper,
    conductorCount: 3,
    conductorCrossSectionMm2: 2.5,
    ratedVoltageV: 660,
  );

  final lanCable = CableSpec(
    id: 'cat6a',
    name: 'Cat6A F/UTP',
    medium: RouteMediumProfile.ethernet,
    outerDiameterMm: 7.5,
    segregationClass: CableSegregationClass.data,
    pairCount: 4,
    shielding: CableShielding.foil,
    category: 'Cat6A',
  );

  test(
    'power conductor cross-section stays independent from cable fill area',
    () {
      expect(powerCable.conductorCount, 3);
      expect(powerCable.conductorCrossSectionMm2, 2.5);
      expect(powerCable.occupiedCircularAreaMm2, closeTo(78.54, 0.02));
    },
  );

  test('area-fill channel respects reserve and reports overfill', () {
    final path = InstallationPathSpec(
      id: 'conduit-1',
      name: 'Conduit 1',
      method: InstallationMethod.conduit,
      channels: [
        InstallationChannelSpec(
          id: 'tube-a',
          capacityModel: ChannelCapacityModel.areaFill,
          usableAreaMm2: 500,
          maxFillRatio: 0.40,
          reserveRatio: 0.20,
          allowedSegregationClasses: const {CableSegregationClass.power},
        ),
      ],
    );
    final section = InstallationPathSection(
      id: 'section-1',
      pathSpecId: path.id,
      host: RouteHostRef.outdoor('yard'),
      lengthMm: 10000,
    );

    final two = InstallationCapacityEngine.evaluate(
      InstallationCapacityRequest(
        pathSpecs: [path],
        sections: [section],
        occupancies: [
          RouteOccupancy(
            routeId: 'r1',
            pathSectionId: section.id,
            channelId: 'tube-a',
            cable: powerCable,
            quantity: 2,
          ),
        ],
      ),
    );
    expect(two.hasErrors, isFalse);
    expect(two.channels.single.fillRatio, closeTo(0.31416, 0.0002));
    expect(two.channels.single.effectiveFillLimit, closeTo(0.32, 0.0001));

    final three = InstallationCapacityEngine.evaluate(
      InstallationCapacityRequest(
        pathSpecs: [path],
        sections: [section],
        occupancies: [
          RouteOccupancy(
            routeId: 'r1',
            pathSectionId: section.id,
            channelId: 'tube-a',
            cable: powerCable,
            quantity: 3,
          ),
        ],
      ),
    );
    expect(three.hasErrors, isTrue);
    expect(
      three.defects.any(
        (item) => item.kind == InstallationDefectKind.areaOverfill,
      ),
      isTrue,
    );
  });

  test('segregation rejects LAN cable from power-only channel', () {
    final path = InstallationPathSpec(
      id: 'tray-power',
      name: 'Power tray',
      method: InstallationMethod.cableTray,
      channels: [
        InstallationChannelSpec(
          id: 'power',
          capacityModel: ChannelCapacityModel.cableCount,
          maxCableCount: 20,
          allowedSegregationClasses: const {CableSegregationClass.power},
        ),
      ],
    );
    final section = InstallationPathSection(
      id: 'tray-section',
      pathSpecId: path.id,
      host: RouteHostRef.outdoor('yard'),
      lengthMm: 5000,
    );

    final result = InstallationCapacityEngine.evaluate(
      InstallationCapacityRequest(
        pathSpecs: [path],
        sections: [section],
        occupancies: [
          RouteOccupancy(
            routeId: 'lan-1',
            pathSectionId: section.id,
            channelId: 'power',
            cable: lanCable,
          ),
        ],
      ),
    );

    expect(
      result.defects.any(
        (item) => item.kind == InstallationDefectKind.mediumNotAllowed,
      ),
      isTrue,
    );
  });

  test('dedicated channel rejects multiple cable routes', () {
    final path = InstallationPathSpec(
      id: 'dedicated-duct',
      name: 'Dedicated service duct',
      method: InstallationMethod.undergroundDuct,
      channels: [
        InstallationChannelSpec(
          id: 'duct-1',
          capacityModel: ChannelCapacityModel.dedicated,
        ),
      ],
    );
    final section = InstallationPathSection(
      id: 'duct-section',
      pathSpecId: path.id,
      host: RouteHostRef.outdoor('yard'),
      lengthMm: 8000,
    );

    final result = InstallationCapacityEngine.evaluate(
      InstallationCapacityRequest(
        pathSpecs: [path],
        sections: [section],
        occupancies: [
          RouteOccupancy(
            routeId: 'gate-power',
            pathSectionId: section.id,
            channelId: 'duct-1',
            cable: powerCable,
          ),
          RouteOccupancy(
            routeId: 'yard-light',
            pathSectionId: section.id,
            channelId: 'duct-1',
            cable: powerCable,
          ),
        ],
      ),
    );

    expect(
      result.defects.any(
        (item) => item.kind == InstallationDefectKind.dedicatedChannelConflict,
      ),
      isTrue,
    );
  });
}
