import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/features/editor/canonical_space_semantics_adapter.dart';
import 'package:elecx/src/features/editor/space_semantics_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows useful canonical room semantics and changes usage', (
    tester,
  ) async {
    SpaceUsage? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: SpaceSemanticsInspector(
              projection: _projection(),
              onUsageChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    expect(find.text('ROOM SEMANTICS'), findsOneWidget);
    expect(find.text('Bedroom 101'), findsOneWidget);
    expect(find.text('Door · 900×2100 mm'), findsOneWidget);
    expect(find.text('Corridor'), findsWidgets);
    expect(find.text('Connected by opening'), findsOneWidget);
    expect(find.text('FC-01'), findsOneWidget);
    expect(find.textContaining('Fire safety'), findsOneWidget);
    expect(find.textContaining('wallIndex'), findsNothing);
    expect(find.textContaining('BoundaryEdgeId'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('space-semantics-usage')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Office').last);
    await tester.pumpAndSettle();

    expect(selected, SpaceUsage.office);
  });

  testWidgets('read-only projection exposes usage without an editor control', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpaceSemanticsInspector(projection: _projection()),
        ),
      ),
    );

    expect(find.text('Usage: '), findsOneWidget);
    expect(find.text('Bedroom'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<SpaceUsage>), findsNothing);
  });
}

CanonicalSpaceSemanticsProjection _projection() {
  final levelId = LevelId('level-1');
  final roomId = SpaceId('room-101');
  final corridorId = SpaceId('corridor-1');
  final boundary = MmPolygon.rectangle(
    const MmPoint(0, 0),
    const MmPoint(4200, 3200),
  );
  final room = ProjectSpaceEntity(
    id: roomId,
    levelId: levelId,
    name: 'Bedroom 101',
    usage: SpaceUsage.bedroom,
  );
  final corridor = ProjectSpaceEntity(
    id: corridorId,
    levelId: levelId,
    name: 'Corridor',
    usage: SpaceUsage.corridor,
  );
  final opening = ProjectOpeningEntity(
    id: OpeningId('door-1'),
    levelId: levelId,
    kind: OpeningKind.door,
    connectedSpaceIds: <SpaceId>[roomId, corridorId],
    widthMm: 900,
    heightMm: 2100,
  );
  final adjacency = ProjectSpaceAdjacencyEntity(
    id: SpaceAdjacencyId('adj-1'),
    spaceAId: roomId,
    spaceBId: corridorId,
    kind: SpaceAdjacencyKind.opening,
    openingId: opening.id,
  );
  final overlay = ProjectOverlayClassificationEntity(
    id: OverlayClassificationId('fire-1'),
    name: 'FC-01',
    discipline: OverlayDiscipline.fireSafety,
    kind: OverlayClassificationKind.fireCompartment,
    spaceIds: <SpaceId>[roomId],
  );

  return CanonicalSpaceSemanticsProjection(
    projectId: ProjectId('project-1'),
    projectVersion: LocalProjectVersion(3),
    space: room,
    legacySpace: EngineeringSpace(
      id: 'legacy-room-101',
      name: 'Bedroom 101',
      type: SpaceType.room,
      boundary: boundary,
      referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
    ),
    openings: <ProjectOpeningEntity>[opening],
    adjacencies: <ProjectSpaceAdjacencyEntity>[adjacency],
    overlays: <ProjectOverlayClassificationEntity>[overlay],
    adjacentSpaces: <SpaceId, ProjectSpaceEntity>{corridorId: corridor},
  );
}
