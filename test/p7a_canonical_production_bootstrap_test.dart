import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_repository.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/features/editor/canonical_editor_production_bootstrap.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first open persists sidecar and reopen reuses exact canonical identity',
      () async {
    final fixture = _LegacyFixture();
    addTearDown(fixture.dispose);
    final repository = _MemoryProjectRepository();

    final first = await CanonicalEditorProductionHandle.loadOrBootstrap(
      legacyDocument: fixture.document,
      repository: repository,
    );
    expect(repository.saveCount, 1);
    final firstSpaceIds = first.owner.project.stores.spaces.keys.toList();
    final firstEdges = {
      for (final entry in first.owner.project.stores.boundaries.entries)
        entry.key: List<BoundaryEdgeId>.of(entry.value.orderedEdgeIds),
    };

    final reopened = await CanonicalEditorProductionHandle.loadOrBootstrap(
      legacyDocument: fixture.document,
      repository: repository,
    );
    expect(repository.saveCount, 1);
    expect(reopened.owner.project.stores.spaces.keys, firstSpaceIds);
    for (final entry in firstEdges.entries) {
      expect(
        reopened.owner.project.index.boundary(entry.key)?.orderedEdgeIds,
        entry.value,
      );
    }
  });

  test('mutation receipt owns synchronously and disk changes only on save',
      () async {
    final fixture = _LegacyFixture();
    addTearDown(fixture.dispose);
    final repository = _MemoryProjectRepository();
    final handle = await CanonicalEditorProductionHandle.loadOrBootstrap(
      legacyDocument: fixture.document,
      repository: repository,
    );
    final persistedVersion = repository.saved!.localVersion;

    final authored = handle.session.createBuilding(
      const CreateBuildingRequest(name: 'Added building'),
    );
    final mutation = ProjectMutationResult(
      project: authored.project,
      changeSet: authored.changeSet,
    );
    handle.runtimeConfig.onCanonicalMutationCommitted!(
      handle.session,
      mutation,
    );
    handle.runtimeConfig.onAuthoringCommitted!(
      handle.session,
      authored.createdId,
    );

    expect(handle.owner.project, same(handle.session.project));
    expect(handle.owner.version, persistedVersion.next());
    expect(repository.saved!.localVersion, persistedVersion);

    await handle.saveCanonical();
    expect(repository.saved!.localVersion, handle.owner.version);
    expect(repository.saveCount, 2);
  });
}

final class _LegacyFixture {
  _LegacyFixture() {
    final polygon = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4000, 3000),
    );
    final space = EngineeringSpace(
      id: 'room-A',
      name: 'Room A',
      type: SpaceType.room,
      boundary: polygon,
      referenceFrame: RoomReferenceFrame(origin: polygon.bounds.center),
    );
    controller = EditorController.restored(
      level: BuildingLevel(
        id: 'level-1',
        name: 'Level 1',
        elevationMm: 0,
        spaces: [space],
      ),
      openings: const [],
    );
    workspace = EditorBuildingWorkspace.blank(
      controller,
      projectId: 'P-200',
      projectName: 'Production bootstrap',
    );
    document = EditorProjectDocument.capture(
      workspace,
      now: DateTime.utc(2026, 10, 23, 7),
    );
  }

  late final EditorController controller;
  late final EditorBuildingWorkspace workspace;
  late final EditorProjectDocument document;

  void dispose() {
    workspace.dispose();
    controller.disposeP2State();
    controller.dispose();
  }
}

final class _MemoryProjectRepository implements ProjectRepository {
  ProjectSnapshot? saved;
  int saveCount = 0;

  @override
  Future<ProjectSnapshot?> load(ProjectId projectId) async =>
      saved?.id == projectId ? saved : null;

  @override
  Future<void> save(ProjectSnapshot snapshot) async {
    saved = snapshot;
    saveCount++;
  }

  @override
  Future<List<ProjectSummary>> list() async =>
      saved == null ? const [] : [saved!.toSummary()];
}
