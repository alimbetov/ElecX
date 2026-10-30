import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_orientation_commands.dart';
import 'package:elecx/src/application/project/project_service_anchor_commands.dart';
import 'package:elecx/src/application/project/project_site_layout_commands.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/application/project/wizard/building/building_composition_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/building/building_generation_parameters.dart';
import 'package:elecx/src/application/project/wizard/building/cottage_composition.dart';
import 'package:elecx/src/domain/composition_generation_provenance.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/domain/project_service_anchor.dart';
import 'package:elecx/src/domain/project_site_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p1011_wizard_fixture.dart';

void main() {
  for (final family in BuildingCompositionWizardFamily.values) {
    test('P10-Q17 ${family.name}: one room edit retains unrelated evidence',
        () {
      final r = _applied(family);
      final before = r.mutations.current;
      final id = before.stores.spaces.keys.first;
      // Empty advisory IDs must not suppress owner-derived provenance changes.
      final request = ProjectMutationRequest(
          expectedVersion: before.version,
          command: _WithoutDeclaredIds(
              RenameSpaceCommand(spaceId: id, name: 'Manual room')));
      final preview = r.mutations.preview(request);
      _expectLocalChange(before, preview.candidate, {id});
      expect(identical(r.mutations.current, before), isTrue);
      r.mutations.commit(request);
      _expectLocalChange(before, r.mutations.current, {id});
      final parent = r.mutations.current.engineeringMetadata
          .generationProvenanceRegistry.compositions.values.single;
      expect(parent.entities.values.singleWhere((e) => e.id == id).overrides,
          {'name'});
      expect(() => parent.entities.clear(), throwsUnsupportedError);
      expect(() => parent.entities.values.first.baseline.clear(),
          throwsUnsupportedError);

      // Further edits of the same overridden field need no new provenance.
      final edited = r.mutations.current;
      r.mutations.commit(ProjectMutationRequest(
          expectedVersion: edited.version,
          command: RenameSpaceCommand(spaceId: id, name: 'Manual room again')));
      _expectLocalChange(edited, r.mutations.current, {});
      r.mutations.undo(r.mutations.current.version);
      expect(p1011Bytes(r.mutations.current, includeVersion: false),
          p1011Bytes(edited, includeVersion: false));
      r.mutations.undo(r.mutations.current.version);
      expect(p1011Bytes(r.mutations.current, includeVersion: false),
          p1011Bytes(before, includeVersion: false));
      r.mutations.redo(r.mutations.current.version);
      expect(p1011Bytes(r.mutations.current, includeVersion: false),
          p1011Bytes(edited, includeVersion: false));
    });
  }

  test(
      'P10-Q17 metadata-only placement, anchor and physical host edits are local',
      () {
    final r = _applied(BuildingCompositionWizardFamily.cottage);
    void apply(ProjectCommand command, EntityId id) {
      final before = r.mutations.current;
      final result = r.mutations.commit(ProjectMutationRequest(
          expectedVersion: before.version,
          command: _WithoutDeclaredIds(command)))!;
      expect(result.changeSet.entityDiff.isEmpty, isTrue);
      _expectLocalChange(before, r.mutations.current, {id});
    }

    final layout = r.mutations.current.engineeringMetadata.siteLayout;
    final building = layout.placements.entries.single;
    apply(
        UpdateBuildingSitePlacementCommand(
            buildingId: building.key,
            placement: ProjectBuildingSitePlacement(
                xMm: building.value.xMm + 100000,
                yMm: building.value.yMm,
                orientation: building.value.orientation,
                widthMm: building.value.widthMm,
                depthMm: building.value.depthMm)),
        building.key);
    final anchor = layout.serviceAnchors.values
        .whereType<ProjectSiteServiceAnchor>()
        .first;
    apply(
        UpdateServiceAnchorCommand(
            anchor: ProjectSiteServiceAnchor(
                id: anchor.id,
                siteId: anchor.siteId,
                name: 'Manual service area',
                kind: anchor.kind,
                point: anchor.point,
                servedBuildingIds: anchor.servedBuildingIds)),
        anchor.id);
    final wall = layout.serviceAnchors.values
        .whereType<ProjectBoundaryServiceAnchor>()
        .first;
    final host = r
        .mutations.current.engineeringMetadata.boundaryHostedObjectRegistry
        .serviceEntryHost(wall.id)!;
    apply(
        UpdateServiceAnchorCommand(
            anchor: wall,
            boundaryBinding: ServiceAnchorBoundaryBinding(
                host: host.host, offsetMm: host.startOffsetMm! + 100)),
        wall.id);
    final beforeRemoval = r.mutations.current;
    apply(RemoveServiceAnchorCommand(wall.id), wall.id);
    final removed = r.mutations.current;
    final tombstone = removed.engineeringMetadata.generationProvenanceRegistry
        .compositions.values.single.entities.values
        .singleWhere((e) => e.id == wall.id);
    expect(tombstone.removed, isTrue);
    expect(() => tombstone.reconcile({'name': 'ID reuse'}), throwsStateError);
    r.mutations.undo(removed.version);
    expect(p1011Bytes(r.mutations.current, includeVersion: false),
        p1011Bytes(beforeRemoval, includeVersion: false));
    r.mutations.redo(r.mutations.current.version);
    expect(p1011Bytes(r.mutations.current, includeVersion: false),
        p1011Bytes(removed, includeVersion: false));
  });

  test(
      'P10-Q17 independent compositions and project-only edits retain manifests',
      () {
    final r = _applied(BuildingCompositionWizardFamily.cottage);
    final original = r.mutations.current;
    final source = p1011Parameters(BuildingCompositionWizardFamily.cottage);
    final p = source.buildingParameters!;
    final command = CottageCompositionCommand.create(
        project: original,
        compositionKey: 'independent.cottage',
        allowExistingBuildings: true,
        parameters: BuildingGenerationParameters(
            kind: p.kind,
            siteId: p.siteId,
            displayName: 'Independent cottage',
            placement: BuildingSitePlacement(
                xMm: 200000,
                yMm: 0,
                orientation: ProjectEngineeringNorth.fromDegrees(0)),
            levelStack: p.levelStack,
            commonCore: p.commonCore,
            serviceAnchors: ServiceAnchorParameters(),
            template: p.template),
        layout: source.layout!);
    r.port.commitPreview(r.port.preview(command));
    final before = r.mutations.current;
    expect(before.engineeringMetadata.generationProvenanceRegistry.compositions,
        hasLength(2));
    _expectLocalChange(original, before, {});
    final id = original.stores.spaces.keys.first;
    r.mutations.commit(ProjectMutationRequest(
        expectedVersion: before.version,
        command: RenameSpaceCommand(spaceId: id, name: 'Local room')));
    _expectLocalChange(before, r.mutations.current, {id});
    final renamed = r.mutations.current;
    r.mutations.commit(ProjectMutationRequest(
        expectedVersion: renamed.version,
        command:
            SetProjectNorthCommand(ProjectEngineeringNorth.fromDegrees(90))));
    _expectLocalChange(renamed, r.mutations.current, {});
  });

  test('P10-Q17 frozen tracked candidate applies, forged evidence is atomic',
      () {
    final r = _applied(BuildingCompositionWizardFamily.cottage);
    final before = r.mutations.current;
    final id = before.stores.spaces.keys.first;
    final preview = r.mutations.preview(ProjectMutationRequest(
        expectedVersion: before.version,
        command: RenameSpaceCommand(spaceId: id, name: 'Frozen room')));
    r.mutations.commit(ProjectMutationRequest(
        expectedVersion: before.version,
        command:
            _StateCommand(ProjectMutableState.fromProject(preview.candidate))));
    _expectLocalChange(before, r.mutations.current, {id});
    final current = r.mutations.current;
    final registry = current.engineeringMetadata.generationProvenanceRegistry;
    final parent = registry.compositions.values.single;
    final slot = parent.entities.entries.firstWhere((e) => e.value.id == id);
    for (final forged in [
      CompositionGenerationManifest(
          id: parent.id,
          projectId: parent.projectId,
          siteId: parent.siteId,
          commandType: parent.commandType,
          canonicalEvidence: parent.canonicalEvidence,
          children: parent.children,
          entities: {
            ...parent.entities,
            slot.key: CompositionGeneratedEntity(
                id: id, baseline: slot.value.baseline, overrides: {})
          }),
      CompositionGenerationManifest(
          id: parent.id,
          projectId: parent.projectId,
          siteId: parent.siteId,
          commandType: parent.commandType,
          canonicalEvidence: parent.canonicalEvidence,
          children: parent.children,
          entities: {
            ...parent.entities,
            slot.key: CompositionGeneratedEntity(
                id: id,
                baseline: {...slot.value.baseline, 'name': '0' * 64},
                overrides: slot.value.overrides)
          })
    ]) {
      final depth = r.mutations.undoDepth;
      final state = ProjectMutableState(
          stores: current.stores,
          engineeringMetadata: current.engineeringMetadata
              .withGenerationProvenanceRegistry(
                  registry.copyWith(compositions: {parent.id: forged})));
      expect(
          () => r.mutations.commit(ProjectMutationRequest(
              expectedVersion: current.version, command: _StateCommand(state))),
          throwsStateError);
      expect(identical(r.mutations.current, current), isTrue);
      expect(r.mutations.undoDepth, depth);
    }
  });
}

P1011WizardRuntime _applied(BuildingCompositionWizardFamily family) {
  final r = P1011WizardRuntime(family: family);
  expect(r.wizard.generatePreview(), isTrue);
  expect(r.wizard.confirm(), isTrue);
  return r;
}

void _expectLocalChange(ProjectAggregateRoot before, ProjectAggregateRoot after,
    Set<EntityId> changed) {
  for (final m in before
      .engineeringMetadata.generationProvenanceRegistry.compositions.values) {
    final next = after
        .engineeringMetadata.generationProvenanceRegistry.compositions[m.id]!;
    expect(next.immutableFingerprint, m.immutableFingerprint);
    expect(identical(next.children, m.children), isTrue);
    var count = 0;
    for (final e in m.entities.entries) {
      final member = next.entities[e.key]!;
      expect(identical(member.baseline, e.value.baseline), isTrue);
      final replaced = changed.contains(member.id);
      expect(identical(member, e.value), !replaced, reason: '${member.id}');
      if (replaced) count++;
    }
    expect(identical(m, next), count == 0);
  }
  CompositionProvenanceIntegrity.validate(after);
}

final class _WithoutDeclaredIds implements ProjectCommand {
  const _WithoutDeclaredIds(this.delegate);
  final ProjectCommand delegate;
  @override
  String get commandType => delegate.commandType;
  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) =>
      ProjectCommandCandidate.fromState(
          state: delegate.buildCandidate(current).resolveState(current));
}

final class _StateCommand implements ProjectCommand {
  const _StateCommand(this.state);
  final ProjectMutableState state;
  @override
  String get commandType => 'test.p10.frozen-state';
  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) =>
      ProjectCommandCandidate.fromState(state: state);
}
