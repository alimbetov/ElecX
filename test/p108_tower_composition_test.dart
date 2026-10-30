import 'package:elecx/src/serialization/project/composition_provenance_aware_canonical_project_document_codec.dart';
import 'dart:convert';
import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/building/residential_tower_composition.dart';
import 'package:elecx/src/domain/boundary_opening_profile_validation.dart';
import 'package:elecx/src/domain/generation_provenance.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p108_tower_fixture.dart';

void main() {
  final fixture = P108TowerFixture();
  late ResidentialTowerCompositionCommand command;
  setUpAll(() => command = fixture.command());
  ProjectMutationSession session() => ProjectMutationSession(fixture.project);
  SharedProjectWizardMutationPort port(ProjectMutationSession session,
          [int seed = 108]) =>
      SharedProjectWizardMutationPort(
          mutations: session,
          idFactory: SecureRandomEntityIdFactory(random: Random(seed)));

  test(
      'P10-Q10 tower composes basement ground repeated apartments technical roof and physical cores',
      () {
    final mutations = session();
    final preview = port(mutations).preview(command);
    expect(mutations.current.stores.buildings, isEmpty);
    final tower = preview.candidate;
    expect(tower.stores.levels, hasLength(6));
    expect(tower.stores.slabs, hasLength(5));
    expect(tower.stores.verticalCores, hasLength(5));
    expect(
        tower.stores.verticalCores.values.map((c) => c.usage),
        containsAll([
          VerticalCoreUsage.stairwell,
          VerticalCoreUsage.elevatorShaft,
          VerticalCoreUsage.electricalRiser,
          VerticalCoreUsage.telecomRiser
        ]));
    final registry = tower.engineeringMetadata.generationProvenanceRegistry;
    expect(registry.levelCompositions, hasLength(2));
    expect(registry.manifests, hasLength(4));
    expect(registry.floorInstances, hasLength(2));
    expect(registry.typicalFloorDefinitions, hasLength(1));
    for (final parent in registry.levelCompositions.values) {
      expect(parent.apartments, hasLength(2));
      for (final child in parent.apartments.values) {
        final spaces = tower.stores.zones[child.apartmentZoneId]!.spaceIds;
        final entry = tower.stores.openings.values.singleWhere((o) =>
            o.connectedSpaceIds.contains(child.accessSpaceId) &&
            o.connectedSpaceIds.any(spaces.contains));
        expect(
            tower.stores.adjacencies.values.any((a) => a.openingId == entry.id),
            isTrue);
      }
    }
    for (final core in tower.stores.verticalCores.values) {
      expect(core.levelIds, hasLength(5));
      expect(core.hostSpaceIdsByLevel.values.toSet(), hasLength(5));
    }
    for (final id in tower.stores.spaces.keys) {
      BoundaryOpeningProfileValidator.validateSpace(
          spaceId: id,
          openings: tower.stores.openings.values,
          hostedObjects: tower.engineeringMetadata.boundaryHostedObjectRegistry,
          wallProfiles: tower.engineeringMetadata.boundaryWallProfileRegistry);
    }
    expect(
        tower.stores.levels.values
            .singleWhere((l) => l.kind == ProjectLevelKind.roof)
            .spaceIds,
        isEmpty);
    final ids = preview.reservation.entityIds;
    expect(ids.whereType<GenerationId>(), hasLength(7));
    expect(ids.whereType<TypicalFloorDefinitionId>(), hasLength(1));
  });

  test('one parent preview applies once with one Undo and exact identity Redo',
      () {
    final mutations = session();
    final gateway = port(mutations);
    final preview = gateway.preview(command);
    expect(
        preview.semanticChangeSet.operations
            .whereType<CreateEntityOperation>()
            .where((o) => o.entityId is TypicalFloorDefinitionId),
        hasLength(1));
    gateway.commitPreview(preview);
    expect(mutations.undoDepth, 1);
    final ids = mutations.current.stores.spaces.keys.toSet();
    final registry =
        mutations.current.engineeringMetadata.generationProvenanceRegistry;
    mutations.undo(mutations.current.version);
    expect(mutations.current.stores.buildings, isEmpty);
    expect(mutations.current.stores.spaces, isEmpty);
    expect(
        mutations.current.engineeringMetadata.generationProvenanceRegistry
            .floorInstances,
        isEmpty);
    mutations.redo(mutations.current.version);
    expect(mutations.current.stores.spaces.keys.toSet(), ids);
    expect(
        mutations.current.engineeringMetadata.generationProvenanceRegistry
            .sameAs(registry),
        isTrue);
  });

  test(
      'typical-floor and P9 overrides affect one independent floor and apartment',
      () {
    final mutations = session();
    final gateway = port(mutations);
    gateway.commitPreview(gateway.preview(command));
    final registry =
        mutations.current.engineeringMetadata.generationProvenanceRegistry;
    final parents = registry.levelCompositions.values.toList();
    final a = mutations.current.stores
        .zones[parents.first.apartments['a']!.apartmentZoneId]!.spaceIds.first;
    final b = mutations.current.stores
        .zones[parents.last.apartments['a']!.apartmentZoneId]!.spaceIds.first;
    final siblingName = mutations.current.stores.spaces[b]!.name;
    mutations.commit(ProjectMutationRequest(
        expectedVersion: mutations.current.version,
        command:
            RenameSpaceCommand(spaceId: a, name: 'Custom first-floor room')));
    final after =
        mutations.current.engineeringMetadata.generationProvenanceRegistry;
    expect(after.provenanceFor(a)!.overriddenProperties,
        contains(GenerationPropertyKey.name));
    expect(after.floorInstances[parents.first.levelId]!.overriddenProperties,
        isNotEmpty);
    expect(after.floorInstances[parents.last.levelId]!.overriddenProperties,
        isEmpty);
    expect(mutations.current.stores.spaces[b]!.name, siblingName);
    final firstIds =
        after.floorInstances[parents.first.levelId]!.entities.values.toSet();
    expect(
        firstIds.intersection(after
            .floorInstances[parents.last.levelId]!.entities.values
            .toSet()),
        isEmpty);
  });

  test(
      'equivalent slot order generates identical accepted candidates and canonical bytes',
      () {
    final other = fixture.command(requests: fixture.requests.reversed);
    expect(other.plan.semanticFingerprint, command.plan.semanticFingerprint);
    final a = port(session()).preview(command).candidate;
    final b = port(session()).preview(other).candidate;
    const codec = CompositionProvenanceAwareCanonicalProjectDocumentCodec();
    expect(jsonEncode(codec.encode(p108Snapshot(a)).payload),
        jsonEncode(codec.encode(p108Snapshot(b)).payload));
  });
}
