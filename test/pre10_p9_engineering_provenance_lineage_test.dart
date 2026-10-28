import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_output_integrity.dart';
import 'package:elecx/src/domain/applied_engineering_proposal.dart';
import 'package:elecx/src/domain/applied_engineering_proposal_lineage.dart';
import 'package:elecx/src/domain/generation_provenance.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:elecx/src/serialization/project/applied_engineering_proposal_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = AppliedEngineeringProposalAwareCanonicalProjectDocumentCodec();

  group('PRE10 P9 engineering/provenance cross-registry lineage', () {
    test('PRE10-CQ22 matching candidate and intent lineage is accepted', () {
      final fixture = _fixture();

      expect(
        () => AppliedEngineeringProposalLineageValidator.validateOrThrow(
          provenance: fixture.provenance,
          proposals: fixture.proposals,
        ),
        returnsNormally,
      );
      expect(() => codec.encode(fixture.snapshot), returnsNormally);
    });

    test('PRE10-CQ22 candidate mismatch is rejected before Save', () {
      final fixture = _fixture(proposalCandidateFingerprint: _sha('e'));

      expect(
        () => AppliedEngineeringProposalLineageValidator.validateOrThrow(
          provenance: fixture.provenance,
          proposals: fixture.proposals,
        ),
        throwsA(isA<AppliedEngineeringProposalLineageException>()),
      );
      expect(
        () => codec.encode(fixture.snapshot),
        throwsA(isA<AppliedEngineeringProposalLineageException>()),
      );
    });

    test('PRE10-CQ22 intent mismatch is rejected before Save', () {
      final fixture = _fixture(proposalIntentFingerprint: _sha('f'));

      expect(
        () => codec.encode(fixture.snapshot),
        throwsA(isA<AppliedEngineeringProposalLineageException>()),
      );
    });

    test('PRE10-CQ22 persisted candidate mismatch is rejected on Reopen', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      final tampered = _tamperProposal(
        encoded,
        field: 'candidateFingerprint',
        value: _sha('e'),
      );

      expect(
        () => codec.decode(tampered),
        throwsA(isA<FormatException>()),
      );
    });

    test('PRE10-CQ22 persisted intent mismatch is rejected on Reopen', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      final tampered = _tamperProposal(
        encoded,
        field: 'intentFingerprint',
        value: _sha('f'),
      );

      expect(
        () => codec.decode(tampered),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

ProjectDocument _tamperProposal(
  ProjectDocument source, {
  required String field,
  required String value,
}) {
  final payload = Map<String, Object?>.from(source.payload);
  final registry = Map<String, Object?>.from(
    payload['appliedEngineeringProposals']! as Map,
  );
  final proposals = List<Object?>.from(registry['proposals']! as List);
  final proposal = Map<String, Object?>.from(proposals.single! as Map);
  proposal[field] = value;
  proposals[0] = proposal;
  registry['proposals'] = proposals;
  payload['appliedEngineeringProposals'] = registry;
  return ProjectDocument(schemaVersion: source.schemaVersion, payload: payload);
}

_Pre10LineageFixture _fixture({
  String? proposalCandidateFingerprint,
  String? proposalIntentFingerprint,
}) {
  final projectId = ProjectId('pre10-lineage-project');
  final siteId = SiteId('pre10-lineage-site');
  final buildingId = BuildingId('pre10-lineage-building');
  final levelId = LevelId('pre10-lineage-level');
  final zoneId = ZoneId('pre10-lineage-zone');
  final generationId = GenerationId('pre10-lineage-generation');
  final candidateFingerprint = _sha('a');
  final intentFingerprint = _sha('b');
  final requirementsFingerprint = _sha('c');
  const panelSummary = 'panel=singlePhase;voltage=230';
  final outputFingerprint = computeApartmentEngineeringOutputFingerprint(
    outputProjectionVersion:
        supportedApartmentEngineeringOutputProjectionVersion,
    requirementsFingerprint: requirementsFingerprint,
    loadScheduleRows: const [],
    circuitScheduleRows: const [],
    panelSummary: panelSummary,
    sldNodes: const [],
    sldEdges: const [],
    explanations: const [],
  );

  final manifest = GenerationManifest(
    provenanceSchemaVersion: 1,
    generationId: generationId,
    originType: GenerationOriginType.wizard,
    providerTemplateId: TemplateId('p9-apartment-provider'),
    providerTemplateVersion: 1,
    catalogVersion: 1,
    apartmentTemplateId: TemplateId('pre10-template'),
    apartmentTemplateVersion: 1,
    familyId: 'compact',
    variantSeedId: 'seed-1',
    generatorVersion: 'generator-v1',
    scoringProfileVersion: 'score-v1',
    allocatorVersion: 'allocator-v1',
    geometryAlgorithmVersion: 'geometry-v1',
    normalizedIntentFingerprint: intentFingerprint,
    selectedCandidateFingerprint: candidateFingerprint,
    projectId: projectId,
    buildingId: buildingId,
    levelId: levelId,
    apartmentZoneId: zoneId,
    generatedEntityIds: {zoneId},
  );
  final provenance = GenerationProvenanceRegistry().addGeneration(
    manifest: manifest,
    provenances: [
      EntityGenerationProvenance(
        entityId: zoneId,
        generationId: generationId,
        generationKey: 'zone:apartment',
        generatedProperties: const {GenerationPropertyKey.name},
        generatedBaselineFingerprint: _sha('d'),
      ),
    ],
  );
  final proposal = AppliedEngineeringProposalSnapshot(
    levelId: levelId,
    proposalVersion: supportedApartmentEngineeringProposalVersion,
    outputProjectionVersion:
        supportedApartmentEngineeringOutputProjectionVersion,
    candidateSetFingerprint: _sha('1'),
    candidateFingerprint: proposalCandidateFingerprint ?? candidateFingerprint,
    intentFingerprint: proposalIntentFingerprint ?? intentFingerprint,
    d1RequirementsFingerprint: _sha('2'),
    requirementsFingerprint: requirementsFingerprint,
    outputFingerprint: outputFingerprint,
    proposalFingerprint: _sha('3'),
    loadScheduleRows: const [],
    circuitScheduleRows: const [],
    panelSummary: panelSummary,
    sldNodes: const [],
    sldEdges: const [],
    explanations: const [],
  );
  final proposals = AppliedEngineeringProposalRegistry(
    byLevel: {levelId: proposal},
  );
  final stores = ProjectEntityStores(
    sites: {
      siteId: ProjectSiteEntity(
        id: siteId,
        name: 'Site',
        buildingIds: {buildingId},
      ),
    },
    buildings: {
      buildingId: ProjectBuildingEntity(
        id: buildingId,
        siteId: siteId,
        name: 'Building',
        levelIds: {levelId},
      ),
    },
    levels: {
      levelId: ProjectLevelEntity(
        id: levelId,
        buildingId: buildingId,
        name: 'Level 1',
        levelNumber: 1,
        elevationMm: 0,
        zoneIds: {zoneId},
      ),
    },
    zones: {
      zoneId: ProjectStructuralZoneEntity(
        id: zoneId,
        levelId: levelId,
        name: 'Apartment 1',
        kind: ProjectStructuralZoneKind.apartment,
        spaceIds: const {},
      ),
    },
  );
  final aggregate = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: LocalProjectVersion(1),
    engineeringMetadata: ProjectEngineeringMetadata(
      generationProvenanceRegistry: provenance,
      appliedEngineeringProposalRegistry: proposals,
    ),
    stores: stores,
  );
  final now = DateTime.utc(2026, 10, 28, 15);
  return _Pre10LineageFixture(
    provenance: provenance,
    proposals: proposals,
    snapshot: ProjectSnapshot(
      aggregate: aggregate,
      name: 'PRE10 lineage',
      createdAt: now,
      updatedAt: now,
    ),
  );
}

final class _Pre10LineageFixture {
  const _Pre10LineageFixture({
    required this.provenance,
    required this.proposals,
    required this.snapshot,
  });

  final GenerationProvenanceRegistry provenance;
  final AppliedEngineeringProposalRegistry proposals;
  final ProjectSnapshot snapshot;
}

String _sha(String character) => List.filled(64, character).join();
