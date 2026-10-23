import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_space_semantics_editing.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/features/editor/canonical_space_semantics_adapter.dart';
import 'package:elecx/src/features/editor/space_semantics_inspector_editing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P6F inspector editing coordinator', () {
    test('forwards the exact projected version as expectedVersion', () {
      final editing = _FakeEditingPort(projectId: ProjectId('project-1'));
      final coordinator = SpaceSemanticsInspectorEditingCoordinator(editing);
      final projection = _projection(
        projectId: ProjectId('project-1'),
        version: LocalProjectVersion(7),
      );

      coordinator.setUsage(projection, SpaceUsage.office);

      expect(editing.lastSpaceId, projection.spaceId);
      expect(editing.lastUsage, SpaceUsage.office);
      expect(editing.lastExpectedVersion, LocalProjectVersion(7));
    });

    test('rejects a projection from another project before mutation', () {
      final editing = _FakeEditingPort(projectId: ProjectId('project-a'));
      final coordinator = SpaceSemanticsInspectorEditingCoordinator(editing);

      expect(
        () => coordinator.setUsage(
          _projection(
            projectId: ProjectId('project-b'),
            version: LocalProjectVersion(2),
          ),
          SpaceUsage.office,
        ),
        throwsA(
          isA<SpaceSemanticsInspectorEditingException>().having(
            (error) => error.code,
            'code',
            SpaceSemanticsInspectorEditingIssueCode.projectMismatch,
          ),
        ),
      );
      expect(editing.lastSpaceId, isNull);
    });
  });
}

final class _FakeEditingPort implements ProjectSpaceSemanticsEditingPort {
  _FakeEditingPort({required this.projectId});

  @override
  final ProjectId projectId;

  @override
  LocalProjectVersion get version => LocalProjectVersion(99);

  @override
  bool get canEdit => true;

  SpaceId? lastSpaceId;
  SpaceUsage? lastUsage;
  LocalProjectVersion? lastExpectedVersion;

  @override
  ProjectSpaceEntity? space(SpaceId spaceId) => null;

  @override
  ProjectMutationResult? setType(
    SpaceId spaceId,
    ProjectSpaceType type, {
    LocalProjectVersion? expectedVersion,
  }) => null;

  @override
  ProjectMutationResult? setUsage(
    SpaceId spaceId,
    SpaceUsage usage, {
    LocalProjectVersion? expectedVersion,
  }) {
    lastSpaceId = spaceId;
    lastUsage = usage;
    lastExpectedVersion = expectedVersion;
    return null;
  }

  @override
  ProjectMutationResult? assignStructuralZone(
    SpaceId spaceId,
    ZoneId zoneId, {
    LocalProjectVersion? expectedVersion,
  }) => null;

  @override
  ProjectMutationResult? unassignStructuralZone(
    SpaceId spaceId, {
    LocalProjectVersion? expectedVersion,
  }) => null;
}

CanonicalSpaceSemanticsProjection _projection({
  required ProjectId projectId,
  required LocalProjectVersion version,
}) {
  final levelId = LevelId('level-1');
  final spaceId = SpaceId('space-1');
  final boundary = MmPolygon.rectangle(
    const MmPoint(0, 0),
    const MmPoint(3000, 3000),
  );
  return CanonicalSpaceSemanticsProjection(
    projectId: projectId,
    projectVersion: version,
    space: ProjectSpaceEntity(id: spaceId, levelId: levelId, name: 'Room'),
    legacySpace: EngineeringSpace(
      id: 'legacy-room',
      name: 'Room',
      type: SpaceType.room,
      boundary: boundary,
      referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
    ),
    openings: const <ProjectOpeningEntity>[],
    adjacencies: const <ProjectSpaceAdjacencyEntity>[],
    overlays: const <ProjectOverlayClassificationEntity>[],
    adjacentSpaces: const <SpaceId, ProjectSpaceEntity>{},
  );
}
