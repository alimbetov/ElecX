import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/site_outdoor_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('yard zone uses project millimetre geometry', () {
    final yard = OutdoorZone(
      id: 'yard-main',
      name: 'Дворовая зона',
      kind: OutdoorZoneKind.yard,
      boundary: MmPolygon.rectangle(
        const MmPoint(-20000, -15000),
        const MmPoint(60000, 50000),
      ),
    );

    expect(yard.boundary.bounds.width, 80000);
    expect(yard.boundary.bounds.height, 65000);
    expect(yard.grid.minorStepMm, 500);
  });

  test('site connection may bridge yard cable entry to basement level', () {
    const basement = BuildingLevel(
      id: 'b1',
      name: 'Подвал 1',
      elevationMm: -3300,
      spaces: [],
    );
    const building = Building(
      id: 'tower-a',
      name: 'Башня A',
      levels: [basement],
    );
    const site = ProjectSite(
      id: 'site-1',
      name: 'Участок',
      buildings: [building],
    );
    final yard = OutdoorZone(
      id: 'yard-main',
      name: 'Двор',
      kind: OutdoorZoneKind.yard,
      boundary: MmPolygon.rectangle(
        const MmPoint(0, 0),
        const MmPoint(50000, 50000),
      ),
    );
    final entry = SiteBuildingConnection(
      id: 'entry-1',
      kind: SiteConnectionKind.electricalServiceEntry,
      outdoorZoneId: yard.id,
      buildingId: building.id,
      levelNumber: -1,
      sitePoint: const MmPoint(24000, 12000),
      levelPoint: const MmPoint(1200, 900),
      targetSpaceId: 'electrical-room',
    );

    final composed = ComposedProjectSite(
      site: site,
      outdoorZones: [yard],
      connections: [entry],
    );

    expect(composed.connections.single.levelNumber, -1);
    expect(
      composed.connections.single.kind,
      SiteConnectionKind.electricalServiceEntry,
    );
  });

  test('site connection rejects unknown outdoor zone', () {
    const building = Building(id: 'tower-a', name: 'Башня A', levels: []);
    const site = ProjectSite(
      id: 'site-1',
      name: 'Участок',
      buildings: [building],
    );

    expect(
      () => ComposedProjectSite(
        site: site,
        connections: [
          SiteBuildingConnection(
            id: 'entry-1',
            kind: SiteConnectionKind.cableEntry,
            outdoorZoneId: 'missing-yard',
            buildingId: building.id,
            levelNumber: -1,
            sitePoint: const MmPoint(0, 0),
            levelPoint: const MmPoint(0, 0),
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
