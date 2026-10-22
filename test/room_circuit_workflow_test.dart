import 'package:elecx/src/domain/cable_spec.dart';
import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/engine/cable_sizing_engine.dart';
import 'package:elecx/src/features/editor/circuit_sizing_evidence.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/room_circuit_panel.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selected load connects to board as one engineering transaction', () {
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
      position: const SurfacePointMm(300, 2200),
    );
    final load = editor.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1400, 2200),
    );
    final depthBefore = editor.p2.history.undoDepth;

    final bundle = editor.p2.connectLoadToBoard(
      loadComponentId: load.id,
      boardComponentId: board.id,
      space: editor.selectedSpace,
    );

    expect(bundle, isNotNull);
    expect(editor.p2.routes, hasLength(1));
    expect(editor.p2.state.circuitBundles, hasLength(1));
    expect(bundle!.circuit.boardId, board.id);
    expect(bundle.cable.endB.componentId, load.id);
    expect(bundle.protectiveDevice, isNull);
    expect(editor.p2.history.undoDepth, depthBefore + 1);

    editor.p2.undo();
    expect(editor.p2.routes, isEmpty);
    expect(editor.p2.state.circuitBundles, isEmpty);
    editor.p2.redo();
    expect(editor.p2.routes, hasLength(1));
    expect(editor.p2.state.circuitBundles, hasLength(1));
  });

  test('circuit bundle survives canonical save and reopen', () {
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
      position: const SurfacePointMm(300, 2200),
    );
    final load = editor.p2.placeComponent(
      type: ElectricalComponentType.lightingPoint,
      surface: surface,
      position: const SurfacePointMm(1400, 2200),
    );
    expect(
      editor.p2.connectLoadToBoard(
        loadComponentId: load.id,
        boardComponentId: board.id,
        space: editor.selectedSpace,
      ),
      isNotNull,
    );

    final encoded = EditorProjectDocument.capture(workspace).toJson();
    final decoded = EditorProjectDocument.fromJson(encoded);
    final restored = decoded.restore();
    addTearDown(() {
      restored.editor.disposeP2State();
      restored.workspace.dispose();
      restored.editor.dispose();
    });
    expect(restored.editor.p2.routes, hasLength(1));
    expect(restored.editor.p2.state.circuitBundles, hasLength(1));
    expect(restored.editor.p2.circuitBundleForLoad(load.id), isNotNull);
  });

  test('deleting a connected load removes route and circuit atomically', () {
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
      position: const SurfacePointMm(300, 2200),
    );
    final load = editor.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1400, 2200),
    );
    expect(
      editor.p2.connectLoadToBoard(
        loadComponentId: load.id,
        boardComponentId: board.id,
        space: editor.selectedSpace,
      ),
      isNotNull,
    );
    editor.p2.select(load.id, mode: SelectionMode.replace);
    expect(editor.p2.deleteSelection(), isTrue);
    expect(editor.p2.routes, isEmpty);
    expect(editor.p2.state.circuitBundles, isEmpty);
    expect(editor.p2.components.any((item) => item.id == load.id), isFalse);

    editor.p2.undo();
    expect(editor.p2.routes, hasLength(1));
    expect(editor.p2.state.circuitBundles, hasLength(1));
    expect(editor.p2.components.any((item) => item.id == load.id), isTrue);
  });

  test('schema v2 migrates with empty circuit bundle list', () {
    final editor = EditorController.demo();
    final workspace = EditorBuildingWorkspace.demo(editor);
    addTearDown(() {
      editor.disposeP2State();
      workspace.dispose();
      editor.dispose();
    });
    final current = EditorProjectDocument.capture(workspace).toJson();
    final legacyP2 = Map<String, Object?>.from(current['p2']! as Map)
      ..remove('circuitBundles');
    final legacy = Map<String, Object?>.from(current)
      ..['schemaVersion'] = 2
      ..['p2'] = legacyP2;

    final decoded = EditorProjectDocument.fromJson(legacy);
    expect(decoded.schemaVersion, EditorProjectDocument.currentSchemaVersion);
    expect(decoded.p2State.circuitBundles, isEmpty);
  });

  testWidgets(
    'circuit panel connects selected load and exposes incomplete protection',
    (tester) async {
      final editor = EditorController.demo();
      addTearDown(() {
        editor.disposeP2State();
        editor.dispose();
      });
      final surface = RoomSurfaceRef.wall(editor.selectedSpace!.id, 1);
      final board = editor.p2.placeComponent(
        type: ElectricalComponentType.distributionBoard,
        surface: surface,
        position: const SurfacePointMm(300, 2200),
      );
      final load = editor.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: surface,
        position: const SurfacePointMm(1400, 2200),
      );
      editor.p2.select(load.id);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RoomCircuitPanel(controller: editor)),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(ValueKey('connect-load-to-board-${board.id}')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(ValueKey('connect-load-to-board-${board.id}')),
      );
      await tester.pump();
      expect(editor.p2.state.circuitBundles, hasLength(1));
      expect(find.textContaining('Защита не назначена'), findsOneWidget);
    },
  );

  test(
    'manual protective device assignment is undoable engineering evidence',
    () {
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
        position: const SurfacePointMm(300, 2200),
      );
      final load = editor.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: surface,
        position: const SurfacePointMm(1400, 2200),
      );
      expect(
        editor.p2.connectLoadToBoard(
          loadComponentId: load.id,
          boardComponentId: board.id,
          space: editor.selectedSpace,
        ),
        isNotNull,
      );
      final depthBefore = editor.p2.history.undoDepth;

      expect(
        editor.p2.assignProtectiveDeviceToLoad(
          loadComponentId: load.id,
          designation: 'QF-1',
          ratedCurrentA: 16,
          poleCount: 1,
        ),
        isTrue,
      );
      final protected = editor.p2.circuitBundleForLoad(load.id)!;
      expect(
        protected.circuit.protectiveDeviceId,
        protected.protectiveDevice!.id,
      );
      expect(protected.protectiveDevice!.designation, 'QF-1');
      expect(protected.protectiveDevice!.ratedCurrentA, 16);
      expect(editor.p2.history.undoDepth, depthBefore + 1);

      editor.p2.undo();
      expect(editor.p2.circuitBundleForLoad(load.id)!.protectiveDevice, isNull);
      editor.p2.redo();
      expect(
        editor.p2.circuitBundleForLoad(load.id)!.protectiveDevice,
        isNotNull,
      );
    },
  );

  test(
    'load data and cable specification edits are undoable and persisted',
    () {
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
        position: const SurfacePointMm(300, 2200),
      );
      final load = editor.p2.placeComponent(
        type: ElectricalComponentType.socketOutlet,
        surface: surface,
        position: const SurfacePointMm(1400, 2200),
      );
      expect(
        editor.p2.connectLoadToBoard(
          loadComponentId: load.id,
          boardComponentId: board.id,
          space: editor.selectedSpace,
        ),
        isNotNull,
      );
      expect(
        editor.p2.updateLoadElectricalData(
          componentId: load.id,
          ratedPowerW: 2300,
          voltageV: 230,
        ),
        isTrue,
      );
      expect(
        editor.p2.assignCableSpecificationToLoad(
          loadComponentId: load.id,
          cableSpecId: 'VVGng-LS-3x2.5',
        ),
        isTrue,
      );
      final currentLoad = editor.p2.components.singleWhere(
        (item) => item.id == load.id,
      );
      expect(currentLoad.ratedPowerW, 2300);
      expect(
        editor.p2.circuitBundleForLoad(load.id)!.cable.cableSpecId,
        'VVGng-LS-3x2.5',
      );
      expect(editor.p2.routes.single.cableType, 'VVGng-LS-3x2.5');

      final restored = EditorProjectDocument.fromJson(
        EditorProjectDocument.capture(workspace).toJson(),
      ).restore();
      addTearDown(() {
        restored.editor.disposeP2State();
        restored.workspace.dispose();
        restored.editor.dispose();
      });
      final restoredLoad = restored.editor.p2.components.singleWhere(
        (item) => item.id == load.id,
      );
      expect(restoredLoad.ratedPowerW, 2300);
      expect(
        restored.editor.p2.circuitBundleForLoad(load.id)!.cable.cableSpecId,
        'VVGng-LS-3x2.5',
      );
    },
  );

  test('sizing evidence is undoable and survives project reopen', () {
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
      position: const SurfacePointMm(300, 2200),
    );
    final load = editor.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1400, 2200),
    );
    expect(
      editor.p2.connectLoadToBoard(
        loadComponentId: load.id,
        boardComponentId: board.id,
        space: editor.selectedSpace,
        cableType: 'cable-3x2.5',
      ),
      isNotNull,
    );
    final route = editor.p2.routes.single;
    final evidence = CircuitSizingEvidence(
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
      ampacitySections: const [],
    );
    final depth = editor.p2.history.undoDepth;
    expect(
      editor.p2.setCircuitSizingEvidenceForLoad(
        loadComponentId: load.id,
        evidence: evidence,
      ),
      isTrue,
    );
    expect(editor.p2.history.undoDepth, depth + 1);
    editor.p2.undo();
    expect(editor.p2.sizingEvidenceForLoad(load.id), isNull);
    editor.p2.redo();
    expect(editor.p2.sizingEvidenceForLoad(load.id), isNotNull);

    final restored = EditorProjectDocument.fromJson(
      EditorProjectDocument.capture(workspace).toJson(),
    ).restore();
    addTearDown(() {
      restored.editor.disposeP2State();
      restored.workspace.dispose();
      restored.editor.dispose();
    });
    expect(restored.editor.p2.sizingEvidenceForLoad(load.id), isNotNull);
  });
}
