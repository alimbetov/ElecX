import 'package:elecx/src/application/project/project_repository.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/wizard/basic_building_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/editor/canonical_editor_production_bootstrap.dart';
import 'package:elecx/src/features/editor/canonical_legacy_structure_projector.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/initial_editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup Wizard shares owner timeline and keeps Undo after rebind',
      () async {
    final repository = _MemoryProjectRepository();
    final initial = _initial('production-wizard-project', 'Production Wizard');
    final handle = await CanonicalEditorProductionHandle.loadOrBootstrap(
      legacyDocument: initial,
      repository: repository,
    );
    final wizard = _wizard(handle);

    _configureAndGenerate(wizard, 'Production Tower');
    expect(wizard.confirm(), isTrue);
    final commit = wizard.commitResult!;
    expect(handle.session.canUndoCanonicalMutation, isTrue);

    final projected = const CanonicalLegacyStructureProjector().project(
      legacy: initial,
      canonical: handle.session.project,
      binding: handle.binding,
    );
    handle.acceptWizardCommit(commit);
    expect(handle.owner.version.value, 1);
    await handle.saveCanonical();

    final rebound = handle.rebindToLegacy(projected);
    expect(identical(rebound.session, handle.session), isTrue);
    expect(identical(rebound.wizardMutations, handle.wizardMutations), isTrue);
    expect(rebound.session.canUndoCanonicalMutation, isTrue);
    expect(rebound.binding.legacyLevelIds, hasLength(4));

    final undo = rebound.session.undoCanonicalMutation();
    expect(undo, isNotNull);
    rebound.runtimeConfig.onCanonicalMutationCommitted!(rebound.session, undo!);
    expect(rebound.owner.version.value, 2);
    expect(rebound.session.project.stores.levels, hasLength(1));
    expect(rebound.session.canRedoCanonicalMutation, isTrue);

    await rebound.saveCanonical();
    final persisted = await repository.load(rebound.owner.projectId);
    expect(persisted, isNotNull);
    expect(persisted!.localVersion.value, 2);
    expect(persisted.aggregate.stores.levels, hasLength(1));
  });

  test('Wizard ownership acknowledgement is accepted exactly once', () async {
    final repository = _MemoryProjectRepository();
    final initial = _initial('owner-once-project', 'Owner once');
    final handle = await CanonicalEditorProductionHandle.loadOrBootstrap(
      legacyDocument: initial,
      repository: repository,
    );
    final wizard = _wizard(handle);

    _configureAndGenerate(wizard, 'Owner Once Tower');
    expect(wizard.confirm(), isTrue);
    final commit = wizard.commitResult!;

    handle.acceptWizardCommit(commit);
    expect(handle.owner.version.value, 1);
    final ownedFingerprint = _fingerprint(handle.owner.project);

    expect(
      () => handle.acceptWizardCommit(commit),
      throwsStateError,
    );
    expect(handle.owner.version.value, 1);
    expect(_fingerprint(handle.owner.project), ownedFingerprint);
  });

  test(
      'Wizard Apply save reopen preserves exact generated canonical identities',
      () async {
    final repository = _MemoryProjectRepository();
    final initial = _initial('reopen-wizard-project', 'Reopen Wizard');
    final handle = await CanonicalEditorProductionHandle.loadOrBootstrap(
      legacyDocument: initial,
      repository: repository,
    );
    final wizard = _wizard(handle);

    _configureAndGenerate(wizard, 'Restart Safe Tower');
    expect(wizard.confirm(), isTrue);
    final commit = wizard.commitResult!;
    final committed = handle.session.project;
    final committedFingerprint = _fingerprint(committed);
    final committedLevelIds =
        committed.stores.levels.keys.map((id) => id.value).toSet();
    final committedBuildingIds =
        committed.stores.buildings.keys.map((id) => id.value).toSet();

    final projected = const CanonicalLegacyStructureProjector().project(
      legacy: initial,
      canonical: committed,
      binding: handle.binding,
    );
    handle.acceptWizardCommit(commit);
    await handle.saveCanonical();

    final reopened = await CanonicalEditorProductionHandle.loadOrBootstrap(
      legacyDocument: projected,
      repository: repository,
    );

    expect(reopened.owner.version, handle.owner.version);
    expect(_fingerprint(reopened.owner.project), committedFingerprint);
    expect(
      reopened.owner.project.stores.levels.keys.map((id) => id.value).toSet(),
      committedLevelIds,
    );
    expect(
      reopened.owner.project.stores.buildings.keys
          .map((id) => id.value)
          .toSet(),
      committedBuildingIds,
    );
    expect(
      reopened.binding.legacyLevelIds.keys.map((id) => id.value).toSet(),
      committedLevelIds,
    );
  });
}

EditorProjectDocument _initial(String projectId, String projectName) =>
    createInitialEditorProjectDocument(
      EditorProjectMetadata.create(
        projectName: projectName,
        projectId: projectId,
        now: DateTime.utc(2026, 10, 24, 11),
      ),
    );

WizardSession _wizard(CanonicalEditorProductionHandle handle) {
  final project = handle.session.project;
  return WizardSession(
    target: NewProjectWizardTarget(
      projectId: project.id,
      siteId: project.siteId,
      baseVersion: project.version,
    ),
    registry: WizardProviderRegistry([BasicBuildingWizardProvider()]),
    mutations: handle.wizardMutations,
  );
}

void _configureAndGenerate(WizardSession wizard, String buildingName) {
  expect(wizard.begin(), isTrue);
  expect(wizard.selectFamily(BasicBuildingWizardProvider.familyId), isTrue);
  expect(
    wizard.updateParameters(
      BasicBuildingWizardParameters(
        buildingName: buildingName,
        aboveGroundLevelCount: 2,
        basementLevelCount: 1,
        floorToFloorHeightMm: 3100,
        createGroundLevel: true,
      ),
    ),
    isTrue,
  );
  expect(wizard.generatePreview(), isTrue);
}

String _fingerprint(ProjectAggregateRoot project) {
  final buildings = project.stores.buildings.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value));
  final levels = project.stores.levels.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value));
  return <String>[
    'project=${project.id.value}|site=${project.siteId.value}|v=${project.version.value}',
    for (final building in buildings)
      'B|${building.id.value}|${building.siteId.value}|${building.name}|'
          '${building.displayOrder}|${building.levelIds.map((id) => id.value).join(',')}',
    for (final level in levels)
      'L|${level.id.value}|${level.buildingId.value}|${level.name}|'
          '${level.levelNumber}|${level.elevationMm}|${level.kind.name}|'
          '${level.floorToFloorHeightMm}|${level.displayOrder}',
  ].join('\n');
}

final class _MemoryProjectRepository implements ProjectRepository {
  final Map<ProjectId, ProjectSnapshot> _snapshots = {};

  @override
  Future<ProjectSnapshot?> load(ProjectId projectId) async =>
      _snapshots[projectId];

  @override
  Future<void> save(ProjectSnapshot snapshot) async {
    _snapshots[snapshot.id] = snapshot;
  }

  @override
  Future<List<ProjectSummary>> list() async => [
        for (final snapshot in _snapshots.values) snapshot.toSummary(),
      ];
}
