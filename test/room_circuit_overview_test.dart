import 'package:elecx/src/domain/cable_spec.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/cable_sizing_engine.dart';
import 'package:elecx/src/features/editor/circuit_sizing_evidence.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/room_circuit_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overview aggregates PASS FAIL and incomplete room circuits', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(() {
      editor.disposeP2State();
      workspace.dispose();
      editor.dispose();
    });
    final surface = RoomSurfaceRef.wall(editor.selectedSpace!.id, 1);
    final board = editor.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: surface,
      position: const SurfacePointMm(200, 2500),
    );
    final loads = <ElectricalComponentPlacement>[];
    for (var index = 0; index < 3; index++) {
      final load = editor.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: surface,
        position: SurfacePointMm(800 + index * 350, 2500),
      );
      loads.add(load);
      expect(
        editor.p2.connectLoadToBoard(
          loadComponentId: load.id,
          boardComponentId: board.id,
          space: editor.selectedSpace,
          cableType: 'cable-3x2.5',
        ),
        isNotNull,
      );
    }

    for (final load in loads.take(2)) {
      expect(
        editor.p2.updateLoadElectricalData(
          componentId: load.id,
          ratedPowerW: 2300,
          voltageV: 230,
        ),
        isTrue,
      );
      expect(
        editor.p2.assignProtectiveDeviceToLoad(
          loadComponentId: load.id,
          designation: 'QF-${load.id}',
          ratedCurrentA: 16,
          poleCount: 1,
        ),
        isTrue,
      );
    }

    CircuitSizingEvidence evidenceFor(
      ElectricalComponentPlacement load, {
      required double ampacity,
    }) {
      final routeId = editor.p2.circuitBundleForLoad(load.id)!.cable.routeId;
      final route = editor.p2.routes.singleWhere((item) => item.id == routeId);
      return CircuitSizingEvidence(
        routeId: route.id,
        routeGeometrySignature: CircuitSizingEvidence.geometrySignature(route),
        cable: const CableSpec(
          id: 'cable-3x2.5',
          name: '3x2.5',
          medium: RouteMediumProfile.acPower,
          outerDiameterMm: 10,
          segregationClass: CableSegregationClass.power,
          conductorMaterial: ConductorMaterial.copper,
          conductorCount: 3,
          conductorCrossSectionMm2: 2.5,
          ratedVoltageV: 230,
        ),
        phaseSystem: CircuitPhaseSystem.singlePhaseAc,
        designCurrentA: 10,
        nominalVoltageV: 230,
        maxVoltageDropRatio: 0.03,
        powerFactor: 1,
        ampacitySections: [
          SectionAmpacityEvidence(
            sectionId: 'whole-route',
            baseAmpacityA: ampacity,
            factors: const [],
          ),
        ],
        impedanceEvidence: const CableImpedanceEvidence(
          resistanceOhmPerKm: 7.5,
        ),
      );
    }

    expect(
      editor.p2.setCircuitSizingEvidenceForLoad(
        loadComponentId: loads[0].id,
        evidence: evidenceFor(loads[0], ampacity: 20),
      ),
      isTrue,
    );
    expect(
      editor.p2.setCircuitSizingEvidenceForLoad(
        loadComponentId: loads[1].id,
        evidence: evidenceFor(loads[1], ampacity: 5),
      ),
      isTrue,
    );

    final model = RoomCircuitOverviewModel.fromSession(
      session: editor.p2,
      spaceId: editor.selectedSpace!.id,
    );
    expect(model.entries, hasLength(3));
    expect(model.passCount, 1);
    expect(model.failCount, 1);
    expect(model.incompleteCount, 1);
    expect(model.indeterminateCount, 0);
    expect(model.entries.first.kind, RoomCircuitOverviewKind.fail);
  });

  testWidgets('overview entry selects load for detailed engineering workflow', (
    tester,
  ) async {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(() {
      editor.disposeP2State();
      workspace.dispose();
      editor.dispose();
    });
    final surface = RoomSurfaceRef.wall(editor.selectedSpace!.id, 1);
    final board = editor.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: surface,
      position: const SurfacePointMm(200, 2500),
    );
    final load = editor.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1200, 2500),
    );
    expect(
      editor.p2.connectLoadToBoard(
        loadComponentId: load.id,
        boardComponentId: board.id,
        space: editor.selectedSpace,
      ),
      isNotNull,
    );
    editor.p2.clearSelection();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RoomCircuitOverviewPanel(controller: editor)),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('room-circuit-overview-expansion')),
    );
    await tester.pumpAndSettle();
    final entryKey = ValueKey('room-circuit-overview-entry-${load.id}');
    expect(find.byKey(entryKey), findsOneWidget);
    await tester.tap(find.byKey(entryKey));
    await tester.pump();
    expect(editor.p2.selectedComponent?.id, load.id);
  });
}
