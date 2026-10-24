import 'package:elecx/src/application/project/project_repository.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/wizard/basic_building_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_diff.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/editor/canonical_editor_production_bootstrap.dart';
import 'package:elecx/src/features/editor/canonical_legacy_structure_projector.dart';
import 'package:elecx/src/features/editor/initial_editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'P8 Golden Journey: New Project -> Wizard -> Preview/Diff -> Apply -> Undo -> Redo -> Save -> Reopen',
      () async {
    final repository = _MemoryProjectRepository();
    final initial = createInitialEditorProjectDocument(
      EditorProjectMetadata.create(
        projectName: 'P8 Golden Journey',
        projectId: 'p8-golden-journey',
        now: DateTime.utc(2026, 10, 24, 12),
      ),
    );
    final handle = await CanonicalEditorProductionHandle.loadOrBootstrap(
      legacyDocument: initial,
      repository: repository,
    );
    final before = handle.session.project;
    final beforeSemanticFingerprint = _semanticFingerprint(before);

    final wizard = WizardSession(
      target: NewProjectWizardTarget(
        projectId: before.id,
        siteId: before.siteId,
        baseVersion: before.version,
      ),
      registry: WizardProviderRegistry([BasicBuildingWizardProvider()]),
      mutations: handle.wizardMutations,
    );

    expect(wizard.begin(), isTrue);
    expect(wizard.selectFamily(BasicBuildingWizardProvider.familyId), isTrue);
    expect(
      wizard.updateParameters(
        const BasicBuildingWizardParameters(
          buildingName: 'Golden Tower',
          aboveGroundLevelCount: 3,
          basementLevelCount: 1,
          floorToFloorHeightMm: 3200,
          createGroundLevel: true,
        ),
      ),
      isTrue,
    );
    expect(wizard.generatePreview(), isTrue);
    expect(wizard.preview, isNotNull);

    final preview = wizard.preview!;
    final diff = const WizardDiffProjector().project(
      before: before,
      preview: preview,
    );
    expect(diff.entries, isNotEmpty);
    expect(diff.entries.any((entry) => entry.fields.isNotEmpty), isTrue);

    expect(wizard.confirm(), isTrue);
    final commit = wizard.commitResult!;
    handle.acceptWizardCommit(commit);

    final applied = handle.session.project;
    final appliedSemanticFingerprint = _semanticFingerprint(applied);
    expect(appliedSemanticFingerprint, isNot(beforeSemanticFingerprint));
    final appliedBuildingIds =
        applied.stores.buildings.keys.map((id) => id.value).toSet();
    final appliedLevelIds =
        applied.stores.levels.keys.map((id) => id.value).toSet();
    expect(handle.session.canUndoCanonicalMutation, isTrue);

    final undo = handle.session.undoCanonicalMutation();
    expect(undo, isNotNull);
    handle.runtimeConfig.onCanonicalMutationCommitted!(handle.session, undo!);
    expect(
      _semanticFingerprint(handle.session.project),
      beforeSemanticFingerprint,
    );
    expect(handle.session.canRedoCanonicalMutation, isTrue);

    final redo = handle.session.redoCanonicalMutation();
    expect(redo, isNotNull);
    handle.runtimeConfig.onCanonicalMutationCommitted!(handle.session, redo!);
    expect(
      _semanticFingerprint(handle.session.project),
      appliedSemanticFingerprint,
    );
    expect(
      handle.session.project.stores.buildings.keys
          .map((id) => id.value)
          .toSet(),
      appliedBuildingIds,
    );
    expect(
      handle.session.project.stores.levels.keys.map((id) => id.value).toSet(),
      appliedLevelIds,
    );

    final projected = const CanonicalLegacyStructureProjector().project(
      legacy: initial,
      canonical: handle.session.project,
      binding: handle.binding,
    );
    await handle.saveCanonical();

    final reopened = await CanonicalEditorProductionHandle.loadOrBootstrap(
      legacyDocument: projected,
      repository: repository,
    );
    expect(
      _semanticFingerprint(reopened.owner.project),
      appliedSemanticFingerprint,
    );
    expect(
      reopened.owner.project.stores.buildings.keys
          .map((id) => id.value)
          .toSet(),
      appliedBuildingIds,
    );
    expect(
      reopened.owner.project.stores.levels.keys.map((id) => id.value).toSet(),
      appliedLevelIds,
    );
    expect(
      reopened.binding.legacyLevelIds.keys.map((id) => id.value).toSet(),
      appliedLevelIds,
    );
    expect(reopened.owner.version, handle.owner.version);
  });
}

String _semanticFingerprint(ProjectAggregateRoot project) {
  final buildings = project.stores.buildings.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value));
  final levels = project.stores.levels.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value));
  return <String>[
    'project=${project.id.value}|site=${project.siteId.value}',
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
