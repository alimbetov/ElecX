import 'dart:convert';
import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/project_space_commands.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_canonical_materializer.dart';
import 'package:elecx/src/application/project/wizard/building/apartment_placement.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_geometry.dart';
import 'package:elecx/src/domain/generation_provenance.dart';
import 'package:elecx/src/domain/generation_provenance_integrity.dart';
import 'package:elecx/src/domain/level_apartment_composition.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/serialization/project/level_composition_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p105_composition_fixture.dart';

void main() {
  late P105CompositionFixture fixture;
  setUpAll(() => fixture = P105CompositionFixture.create());
  const codec = LevelCompositionAwareCanonicalProjectDocumentCodec();

  ({ProjectMutationSession session, SharedProjectWizardMutationPort port})
      harness() {
    final session = ProjectMutationSession(fixture.project);
    return (
      session: session,
      port: SharedProjectWizardMutationPort(
          mutations: session,
          idFactory: SecureRandomEntityIdFactory(random: Random(10550)))
    );
  }

  group('P10-Q05 P9 apartment composition integrity', () {
    test(
        'two accepted P9 apartments retain geometry, topology and nested lineage',
        () {
      final h = harness();
      final command = fixture.command();
      final source =
          fixture.candidateSet.recommendedCandidate.rankedCandidate.candidate;
      final sourceGeometry = source.interiorSpaces
          .map((space) => space.polygon.stableSerialization)
          .toList();
      final preview = h.port.preview(command);
      expect(h.session.current.stores.spaces, hasLength(1));
      expect(h.session.undoDepth, 0);
      final result = h.port.commitPreview(preview)!;
      final project = result.mutation.project;
      final registry = project.engineeringMetadata.generationProvenanceRegistry;
      expect(
          project.stores.zones.values.where(
              (zone) => zone.kind == ProjectStructuralZoneKind.apartment),
          hasLength(2));
      expect(registry.manifests, hasLength(2));
      final parent = registry.levelCompositions.values.single;
      expect(parent.candidateFingerprint, command.candidateFingerprint);
      expect(parent.apartments.keys, ['a', 'b']);
      final generated = <EntityId>{};
      for (final apartment in command.apartments) {
        final child = parent.apartments[apartment.slot.key]!;
        final manifest = registry.manifests[child.generationId]!;
        expect(manifest.selectedCandidateFingerprint,
            apartment.slot.source.candidateFingerprint);
        expect(manifest.apartmentZoneId, child.apartmentZoneId);
        expect(generated.intersection(manifest.generatedEntityIds), isEmpty);
        generated.addAll(manifest.generatedEntityIds);
        for (final space in [
          ...apartment.geometry.interiorSpaces,
          ...apartment.geometry.exteriorAppendages
        ]) {
          final id = registry.entities.values
              .singleWhere((value) =>
                  value.generationId == child.generationId &&
                  value.generationKey == 'space:${space.semanticKey}')
              .entityId as SpaceId;
          final boundary = project.stores.boundaries[id]!;
          final polygon = RectilinearPolygonMm.normalized([
            for (final edgeId in boundary.orderedEdgeIds)
              boundary.edges[edgeId]!.start
          ]);
          expect(
              polygon.stableSerialization, space.polygon.stableSerialization);
          expect(polygon.areaMm2, space.realizedAreaMm2);
        }
        final entry = project.stores.openings.values.singleWhere((opening) =>
            opening.connectedSpaceIds.contains(fixture.accessSpaceId) &&
            opening.connectedSpaceIds.any(project
                .stores.zones[child.apartmentZoneId]!.spaceIds.contains));
        expect(entry.connectedSpaceIds, hasLength(2));
        expect(
            entry.widthMm, ApartmentCanonicalMaterializer.primaryEntryWidthMm);
        for (final spaceId in entry.connectedSpaceIds) {
          expect(
              project.engineeringMetadata.boundaryHostedObjectRegistry
                  .openingHost(entry.id, spaceId),
              isNotNull);
        }
        expect(
            project.stores.adjacencies.values.any((adjacency) =>
                adjacency.kind == SpaceAdjacencyKind.opening &&
                adjacency.openingId == entry.id),
            isTrue);
      }
      GenerationProvenanceIntegrityValidator.validateOrThrow(registry,
          project: project);
      LevelApartmentCompositionIntegrity.validateOrThrow(
          registry: registry, projectId: project.id, stores: project.stores);
      expect(
          source.interiorSpaces
              .map((space) => space.polygon.stableSerialization),
          sourceGeometry);
    });

    test(
        'slot order does not alter the candidate fingerprint or semantic output',
        () {
      expect(
          fixture.command(slots: fixture.slots.reversed).candidateFingerprint,
          fixture.command().candidateFingerprint);
      final a = harness();
      final b = harness();
      a.port.commitPreview(a.port.preview(fixture.command()));
      b.port.commitPreview(
          b.port.preview(fixture.command(slots: fixture.slots.reversed)));
      expect(jsonEncode(codec.encode(p105Snapshot(a.session.current)).payload),
          jsonEncode(codec.encode(p105Snapshot(b.session.current)).payload));
    });

    test(
        'all four integer quarter-turns preserve P9 geometry and hosted entry access',
        () {
      for (var turns = 0; turns < 4; turns++) {
        final f = P105CompositionFixture.create(quarterTurns: turns);
        final session = ProjectMutationSession(f.project);
        final port = SharedProjectWizardMutationPort(
            mutations: session,
            idFactory:
                SecureRandomEntityIdFactory(random: Random(10600 + turns)));
        port.commitPreview(port.preview(f.command()));
        expect(
            session.current.engineeringMetadata.generationProvenanceRegistry
                .manifests,
            hasLength(2));
        expect(() => codec.decode(codec.encode(p105Snapshot(session.current))),
            returnsNormally);
      }
    });

    test('touching apartments receive explicit shared-boundary adjacency', () {
      final f = P105CompositionFixture.create(touching: true);
      final session = ProjectMutationSession(f.project);
      final coordinator = ReservedProjectMutationCoordinator(session,
          entityIdFactory: SecureRandomEntityIdFactory(random: Random(10620)));
      coordinator.commitPreview(coordinator.preview(f.command()));
      final parent = session.current.engineeringMetadata
          .generationProvenanceRegistry.levelCompositions.values.single;
      final a = session.current.stores
          .zones[parent.apartments['a']!.apartmentZoneId]!.spaceIds;
      final b = session.current.stores
          .zones[parent.apartments['b']!.apartmentZoneId]!.spaceIds;
      expect(
          session.current.stores.adjacencies.values.any((value) =>
              value.kind == SpaceAdjacencyKind.sharedBoundary &&
              ((a.contains(value.spaceAId) && b.contains(value.spaceBId)) ||
                  (b.contains(value.spaceAId) && a.contains(value.spaceBId)))),
          isTrue);
    });

    test('P9 default insertion still rejects a nonempty target', () {
      const materializer = ApartmentCanonicalMaterializer();
      final candidate =
          fixture.candidateSet.recommendedCandidate.rankedCandidate.candidate;
      final reservation = materializer.reserveIdentities(
          factory: SecureRandomEntityIdFactory(), candidate: candidate);
      expect(
          () => materializer.validateReservation(
              current: fixture.project,
              target: fixture.target,
              candidate: candidate,
              reservation: reservation),
          throwsA(isA<ApartmentMaterializationException>().having(
              (error) => error.code,
              'code',
              'p9.materialize.target-not-empty')));
    });
  });

  group('P10-Q06 apartment editability and atomicity', () {
    test('one room edit preserves its sibling apartment and child lineage', () {
      final h = harness();
      h.port.commitPreview(h.port.preview(fixture.command()));
      final registry =
          h.session.current.engineeringMetadata.generationProvenanceRegistry;
      final parent = registry.levelCompositions.values.single;
      final a = h.session.current.stores
          .zones[parent.apartments['a']!.apartmentZoneId]!.spaceIds.first;
      final b = h.session.current.stores
          .zones[parent.apartments['b']!.apartmentZoneId]!.spaceIds.first;
      final beforeB = h.session.current.stores.spaces[b]!;
      final boundaryB = h.session.current.stores.boundaries[b]!;
      h.session.commit(ProjectMutationRequest(
          expectedVersion: h.session.current.version,
          command: RenameSpaceCommand(spaceId: a, name: 'Edited A')));
      final after =
          h.session.current.engineeringMetadata.generationProvenanceRegistry;
      expect(after.provenanceFor(a)!.overriddenProperties,
          contains(GenerationPropertyKey.name));
      expect(after.provenanceFor(b)!.overriddenProperties, isEmpty);
      expect(h.session.current.stores.spaces[b], same(beforeB));
      expect(h.session.current.stores.boundaries[b], same(boundaryB));
      expect(after.levelCompositions.values.single.sameAs(parent), isTrue);
      h.session.undo(h.session.current.version);
      expect(
          h.session.current.engineeringMetadata.generationProvenanceRegistry
              .sameAs(registry),
          isTrue);
    });

    test('one composition is exactly one Undo/Redo with the same allocated IDs',
        () {
      final h = harness();
      h.port.commitPreview(h.port.preview(fixture.command()));
      final after = h.session.current;
      final registry = after.engineeringMetadata.generationProvenanceRegistry;
      expect(h.session.undoDepth, 1);
      h.session.undo(h.session.current.version);
      expect(h.session.current.stores.spaces.keys,
          fixture.project.stores.spaces.keys);
      expect(
          h.session.current.engineeringMetadata.generationProvenanceRegistry
              .manifests,
          isEmpty);
      expect(
          h.session.current.engineeringMetadata.generationProvenanceRegistry
              .levelCompositions,
          isEmpty);
      h.session.redo(h.session.current.version);
      expect(h.session.current.stores.spaces.keys.toSet(),
          after.stores.spaces.keys.toSet());
      expect(
          h.session.current.engineeringMetadata.generationProvenanceRegistry
              .sameAs(registry),
          isTrue);
    });

    test('cancel and stale confirmation leave canonical state unchanged', () {
      final h = harness();
      final before =
          jsonEncode(codec.encode(p105Snapshot(h.session.current)).payload);
      final cancelled = h.port.preview(fixture.command());
      h.port.discardPreview(cancelled);
      expect(jsonEncode(codec.encode(p105Snapshot(h.session.current)).payload),
          before);
      expect(() => h.port.commitPreview(cancelled),
          throwsA(isA<DiscardedWizardPreviewException>()));
      final stale = h.port.preview(fixture.command());
      h.session.commit(ProjectMutationRequest(
          expectedVersion: h.session.current.version,
          command: RenameSpaceCommand(
              spaceId: fixture.accessSpaceId, name: 'Changed common hall')));
      final changed =
          jsonEncode(codec.encode(p105Snapshot(h.session.current)).payload);
      expect(() => h.port.commitPreview(stale),
          throwsA(isA<StaleProjectMutationException>()));
      expect(jsonEncode(codec.encode(p105Snapshot(h.session.current)).payload),
          changed);
    });

    test('overlapping placement and duplicate slot keys fail before mutation',
        () {
      final first = fixture.slots.first;
      final duplicate = ApartmentPlacementSlot.fromCandidateSet(
          key: 'b',
          displayName: 'B',
          candidateSet: fixture.candidateSet,
          selection: fixture.candidateSet
              .selectionFor(fixture.candidateSet.recommendedCandidate),
          transform: first.transform,
          accessSpaceId: fixture.accessSpaceId);
      expect(() => fixture.command(slots: [first, duplicate]),
          throwsA(isA<ApartmentCompositionException>()));
      expect(() => fixture.command(slots: [first, first]),
          throwsA(isA<ApartmentCompositionException>()));
      expect(fixture.project.stores.spaces, hasLength(1));
    });
  });
}
