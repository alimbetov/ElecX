from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, found {count}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1))


Path('lib/src/features/editor/room_circuit_overview.dart').write_text(r'''import 'package:flutter/material.dart';

import '../../domain/electrical_placement.dart';
import 'circuit_engineering_status.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

enum RoomCircuitOverviewKind {
  pass,
  fail,
  indeterminate,
  incomplete,
  stale,
}

final class RoomCircuitOverviewEntry {
  const RoomCircuitOverviewEntry({
    required this.loadComponentId,
    required this.circuitName,
    required this.loadLabel,
    required this.boardLabel,
    required this.cableLabel,
    required this.lengthM,
    required this.kind,
    required this.headline,
  });

  final String loadComponentId;
  final String circuitName;
  final String loadLabel;
  final String boardLabel;
  final String cableLabel;
  final double lengthM;
  final RoomCircuitOverviewKind kind;
  final String headline;
}

final class RoomCircuitOverviewModel {
  const RoomCircuitOverviewModel(this.entries);

  final List<RoomCircuitOverviewEntry> entries;

  int count(RoomCircuitOverviewKind kind) =>
      entries.where((entry) => entry.kind == kind).length;

  int get passCount => count(RoomCircuitOverviewKind.pass);
  int get failCount => count(RoomCircuitOverviewKind.fail);
  int get indeterminateCount => count(RoomCircuitOverviewKind.indeterminate);
  int get incompleteCount => count(RoomCircuitOverviewKind.incomplete);
  int get staleCount => count(RoomCircuitOverviewKind.stale);

  static RoomCircuitOverviewModel fromSession({
    required EditorP2Session session,
    required String spaceId,
  }) {
    final entries = <RoomCircuitOverviewEntry>[];
    for (final bundle in session.state.circuitBundles) {
      final load = session.components
          .where((component) => component.id == bundle.cable.endB.componentId)
          .firstOrNull;
      if (load == null || load.surface.spaceId != spaceId) continue;
      final board = session.components
          .where((component) => component.id == bundle.circuit.boardId)
          .firstOrNull;
      final route = session.routes
          .where((route) => route.id == bundle.cable.routeId)
          .firstOrNull;
      if (route == null) {
        entries.add(
          RoomCircuitOverviewEntry(
            loadComponentId: load.id,
            circuitName: bundle.circuit.name,
            loadLabel: load.label,
            boardLabel: board?.label ?? bundle.circuit.boardId ?? '—',
            cableLabel: bundle.cable.designation,
            lengthM: 0,
            kind: RoomCircuitOverviewKind.fail,
            headline: 'Трасса группы отсутствует',
          ),
        );
        continue;
      }
      final status = CircuitEngineeringStatus.evaluate(
        load: load,
        route: route,
        bundle: bundle,
        sizingEvidence: session.sizingEvidenceForLoad(load.id),
      );
      entries.add(
        RoomCircuitOverviewEntry(
          loadComponentId: load.id,
          circuitName: bundle.circuit.name,
          loadLabel: load.label,
          boardLabel: board?.label ?? bundle.circuit.boardId ?? '—',
          cableLabel: bundle.cable.cableSpecId ?? bundle.cable.designation,
          lengthM: status.installationLengthM,
          kind: _kind(status.readiness),
          headline: status.headline,
        ),
      );
    }
    entries.sort((a, b) {
      final severity = _severity(a.kind).compareTo(_severity(b.kind));
      if (severity != 0) return severity;
      return a.circuitName.compareTo(b.circuitName);
    });
    return RoomCircuitOverviewModel(List.unmodifiable(entries));
  }

  static RoomCircuitOverviewKind _kind(CircuitEngineeringReadiness readiness) =>
      switch (readiness) {
        CircuitEngineeringReadiness.sizingPassed => RoomCircuitOverviewKind.pass,
        CircuitEngineeringReadiness.sizingFailed => RoomCircuitOverviewKind.fail,
        CircuitEngineeringReadiness.sizingIndeterminate =>
          RoomCircuitOverviewKind.indeterminate,
        CircuitEngineeringReadiness.sizingEvidenceStale =>
          RoomCircuitOverviewKind.stale,
        CircuitEngineeringReadiness.missingLoadPower ||
        CircuitEngineeringReadiness.missingProtection ||
        CircuitEngineeringReadiness.missingCableSpecification ||
        CircuitEngineeringReadiness.sizingEvidenceRequired =>
          RoomCircuitOverviewKind.incomplete,
      };

  static int _severity(RoomCircuitOverviewKind kind) => switch (kind) {
        RoomCircuitOverviewKind.fail => 0,
        RoomCircuitOverviewKind.stale => 1,
        RoomCircuitOverviewKind.incomplete => 2,
        RoomCircuitOverviewKind.indeterminate => 3,
        RoomCircuitOverviewKind.pass => 4,
      };
}

class RoomCircuitOverviewPanel extends StatelessWidget {
  const RoomCircuitOverviewPanel({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final p2 = controller.p2;
    return AnimatedBuilder(
      animation: Listenable.merge([controller, p2]),
      builder: (context, _) {
        final space = controller.selectedSpace;
        if (space == null) return const SizedBox.shrink();
        final model = RoomCircuitOverviewModel.fromSession(
          session: p2,
          spaceId: space.id,
        );
        return Card(
          key: const ValueKey('room-circuit-overview'),
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: ExpansionTile(
            key: const ValueKey('room-circuit-overview-expansion'),
            initiallyExpanded: false,
            title: Text('Группы комнаты · ${model.entries.length}'),
            subtitle: model.entries.isEmpty
                ? const Text('Подключённых групп пока нет')
                : Text(_summary(model)),
            children: [
              if (model.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Выберите нагрузку и подключите её к щиту.',
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: model.entries.length,
                    itemBuilder: (context, index) {
                      final entry = model.entries[index];
                      return ListTile(
                        key: ValueKey(
                          'room-circuit-overview-entry-${entry.loadComponentId}',
                        ),
                        dense: true,
                        leading: Tooltip(
                          message: _kindLabel(entry.kind),
                          child: Icon(_kindIcon(entry.kind), size: 20),
                        ),
                        title: Text('${entry.circuitName} · ${entry.loadLabel}'),
                        subtitle: Text(
                          '${_kindLabel(entry.kind)} · ${entry.headline}\n'
                          '${entry.boardLabel} · ${entry.cableLabel} · '
                          '${entry.lengthM.toStringAsFixed(2)} м',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => p2.select(entry.loadComponentId),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _summary(RoomCircuitOverviewModel model) => [
        if (model.failCount > 0) 'FAIL ${model.failCount}',
        if (model.staleCount > 0) 'STALE ${model.staleCount}',
        if (model.incompleteCount > 0) 'ДАННЫЕ ${model.incompleteCount}',
        if (model.indeterminateCount > 0) '? ${model.indeterminateCount}',
        if (model.passCount > 0) 'PASS ${model.passCount}',
      ].join(' · ');

  static String _kindLabel(RoomCircuitOverviewKind kind) => switch (kind) {
        RoomCircuitOverviewKind.pass => 'PASS',
        RoomCircuitOverviewKind.fail => 'FAIL',
        RoomCircuitOverviewKind.indeterminate => 'INDETERMINATE',
        RoomCircuitOverviewKind.incomplete => 'ТРЕБУЮТСЯ ДАННЫЕ',
        RoomCircuitOverviewKind.stale => 'STALE',
      };

  static IconData _kindIcon(RoomCircuitOverviewKind kind) => switch (kind) {
        RoomCircuitOverviewKind.pass => Icons.check_circle_outline,
        RoomCircuitOverviewKind.fail => Icons.error_outline,
        RoomCircuitOverviewKind.indeterminate => Icons.help_outline,
        RoomCircuitOverviewKind.incomplete => Icons.edit_note_outlined,
        RoomCircuitOverviewKind.stale => Icons.history_toggle_off,
      };
}
''')

# Wire to desktop and compact inspector.
path = 'lib/src/features/editor/unified_workspace_editor_screen.dart'
replace_once(path,
"import 'room_circuit_panel.dart';\n",
"import 'room_circuit_overview.dart';\nimport 'room_circuit_panel.dart';\n")
replace_once(path,
"                          children: [\n                            RoomCircuitPanel(controller: controller),\n",
"                          children: [\n                            RoomCircuitOverviewPanel(controller: controller),\n                            RoomCircuitPanel(controller: controller),\n")
replace_once(path,
"          const Divider(height: 1),\n          RoomCircuitPanel(controller: controller),\n",
"          const Divider(height: 1),\n          RoomCircuitOverviewPanel(controller: controller),\n          RoomCircuitPanel(controller: controller),\n")

# Pure summary + navigation widget tests.
Path('test/room_circuit_overview_test.dart').write_text(r'''import 'package:elecx/src/domain/cable_spec.dart';
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

  testWidgets('overview entry selects load for detailed engineering workflow',
      (tester) async {
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
    await tester.tap(find.byKey(const ValueKey('room-circuit-overview-expansion')));
    await tester.pumpAndSettle();
    final entryKey = ValueKey('room-circuit-overview-entry-${load.id}');
    expect(find.byKey(entryKey), findsOneWidget);
    await tester.tap(find.byKey(entryKey));
    await tester.pump();
    expect(editor.p2.selectedComponent?.id, load.id);
  });
}
''')
