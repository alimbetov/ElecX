import 'package:elecx/src/data/component_catalog_repository.dart';
import 'package:elecx/src/domain/component_catalog_v2.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/component_catalog_session.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/engineering_placement_cursor_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('editor catalog can be replaced by repository data', () async {
    final controller = EditorController.demo();
    addTearDown(controller.dispose);

    final externalEntry = ComponentCatalogEntryV2(
      id: 'external.sensor.temperature',
      code: 'TEMP-SENSOR',
      name: 'Датчик температуры',
      discipline: EngineeringDiscipline.automation,
      systemClass: EngineeringSystemClass.automationBus,
      calculationKind: EngineeringCalculationKind.busTopology,
      mounting: ComponentMountingPolicy(
        allowedSurfaces: const {SurfacePlaneType.wall},
        preferredHeightMm: 1500,
      ),
      environment: const ComponentEnvironmentConstraints(),
      ports: [
        EngineeringPortSpec(
          id: 'bus',
          direction: EngineeringPortDirection.bidirectional,
          allowedConnections: const {EngineeringConnectionType.rs485},
        ),
      ],
      routePreferenceId: 'automation.bus',
    );

    controller.attachComponentCatalogRepository(
      InMemoryComponentCatalogRepository([externalEntry]),
    );
    await controller.componentCatalog.load();

    expect(controller.componentCatalog.entries, hasLength(1));
    expect(
      controller.componentCatalog.require(externalEntry.id).name,
      'Датчик температуры',
    );

    controller.showWall(0);
    controller.placementCursor.beginCatalogPlacement(externalEntry.id);
    final cursor = controller.placementCursor.ensure();
    expect(cursor, isNotNull);
    expect(cursor!.componentTypeId, externalEntry.id);
    expect(cursor.position.yMm, 1500);
  });
}
