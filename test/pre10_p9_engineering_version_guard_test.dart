import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_output_integrity.dart';
import 'package:elecx/src/domain/applied_engineering_proposal.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/serialization/project/applied_engineering_proposal_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = AppliedEngineeringProposalAwareCanonicalProjectDocumentCodec();

  group('PRE10 P9 nested engineering semantic versions', () {
    test('PRE10-CQ29 unknown proposalVersion is rejected on decode', () {
      final document = _documentWithProposal(
        proposalVersion: 'p9.engineering-proposal.v999',
        outputProjectionVersion:
            supportedApartmentEngineeringOutputProjectionVersion,
      );

      expect(() => codec.decode(document), throwsFormatException);
    });

    test('PRE10-CQ30 unknown outputProjectionVersion is rejected on decode', () {
      final document = _documentWithProposal(
        proposalVersion: supportedApartmentEngineeringProposalVersion,
        outputProjectionVersion: 'p9.engineering-output-projection.v999',
      );

      expect(() => codec.decode(document), throwsFormatException);
    });

    test('PRE10-CQ29 empty proposalVersion is rejected on decode', () {
      final document = _documentWithProposal(
        proposalVersion: '   ',
        outputProjectionVersion:
            supportedApartmentEngineeringOutputProjectionVersion,
      );

      expect(() => codec.decode(document), throwsFormatException);
    });

    test('PRE10-CQ30 supported v1 versions survive Save Reopen', () {
      final document = _documentWithProposal(
        proposalVersion: supportedApartmentEngineeringProposalVersion,
        outputProjectionVersion:
            supportedApartmentEngineeringOutputProjectionVersion,
      );

      final decoded = codec.decode(document);
      final proposal = decoded.aggregate.engineeringMetadata
          .appliedEngineeringProposalRegistry
          .forLevel(LevelId('pre10-level'));

      expect(proposal, isNotNull);
      expect(
        proposal!.proposalVersion,
        supportedApartmentEngineeringProposalVersion,
      );
      expect(
        proposal.outputProjectionVersion,
        supportedApartmentEngineeringOutputProjectionVersion,
      );
    });

    test('PRE10-CQ17 tampered D8 payload with preserved hash is rejected', () {
      final original = _documentWithProposal(
        proposalVersion: supportedApartmentEngineeringProposalVersion,
        outputProjectionVersion:
            supportedApartmentEngineeringOutputProjectionVersion,
      );
      final payload = Map<String, Object?>.from(original.payload);
      final registry = Map<String, Object?>.from(
        payload['appliedEngineeringProposals']! as Map,
      );
      final proposals = List<Object?>.from(registry['proposals']! as List);
      final proposal = Map<String, Object?>.from(proposals.single! as Map);
      final originalFingerprint = proposal['outputFingerprint'];

      proposal['panelSummary'] = 'tampered-panel-summary';
      expect(proposal['outputFingerprint'], originalFingerprint);
      proposals[0] = proposal;
      registry['proposals'] = proposals;
      payload['appliedEngineeringProposals'] = registry;

      final tampered = ProjectDocument(
        schemaVersion: original.schemaVersion,
        payload: payload,
      );
      expect(() => codec.decode(tampered), throwsFormatException);
    });
  });
}

ProjectDocument _documentWithProposal({
  required String proposalVersion,
  required String outputProjectionVersion,
}) {
  const codec = AppliedEngineeringProposalAwareCanonicalProjectDocumentCodec();
  final now = DateTime.utc(2026, 10, 28);
  final levelId = LevelId('pre10-level');
  final siteId = SiteId('pre10-site');
  final buildingId = BuildingId('pre10-building');
  final aggregate = ProjectAggregateRoot(
    id: ProjectId('pre10-project'),
    siteId: siteId,
    version: LocalProjectVersion(1),
    stores: ProjectEntityStores(
      sites: <SiteId, ProjectSiteEntity>{
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: <BuildingId>{buildingId},
        ),
      },
      buildings: <BuildingId, ProjectBuildingEntity>{
        buildingId: ProjectBuildingEntity(
          id: buildingId,
          siteId: siteId,
          name: 'Building',
          levelIds: <LevelId>{levelId},
        ),
      },
      levels: <LevelId, ProjectLevelEntity>{
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Level 1',
          levelNumber: 1,
          elevationMm: 0,
          kind: ProjectLevelKind.residential,
          spaceIds: const <SpaceId>{},
        ),
      },
    ),
  );
  final encoded = codec.encode(
    ProjectSnapshot(
      aggregate: aggregate,
      name: 'PRE10 engineering version guard',
      createdAt: now,
      updatedAt: now,
    ),
  );

  const panelSummary = 'panel-summary';
  const loadScheduleRows = <String>[];
  const circuitScheduleRows = <String>[];
  const sldNodes = <String>[];
  const sldEdges = <String>[];
  const explanations = <String>[];
  final requirementsFingerprint = _sha('5');
  final outputFingerprint = computeApartmentEngineeringOutputFingerprint(
    outputProjectionVersion: outputProjectionVersion,
    requirementsFingerprint: requirementsFingerprint,
    loadScheduleRows: loadScheduleRows,
    circuitScheduleRows: circuitScheduleRows,
    panelSummary: panelSummary,
    sldNodes: sldNodes,
    sldEdges: sldEdges,
    explanations: explanations,
  );

  final payload = Map<String, Object?>.from(encoded.payload);
  final registry = Map<String, Object?>.from(
    payload['appliedEngineeringProposals']! as Map,
  );
  registry['proposals'] = <Object?>[
    <String, Object?>{
      'levelId': levelId.value,
      'proposalVersion': proposalVersion,
      'outputProjectionVersion': outputProjectionVersion,
      'candidateSetFingerprint': _sha('1'),
      'candidateFingerprint': _sha('2'),
      'intentFingerprint': _sha('3'),
      'd1RequirementsFingerprint': _sha('4'),
      'requirementsFingerprint': requirementsFingerprint,
      'outputFingerprint': outputFingerprint,
      'proposalFingerprint': _sha('7'),
      'loadScheduleRows': loadScheduleRows,
      'circuitScheduleRows': circuitScheduleRows,
      'panelSummary': panelSummary,
      'sldNodes': sldNodes,
      'sldEdges': sldEdges,
      'explanations': explanations,
    },
  ];
  payload['appliedEngineeringProposals'] = registry;
  return ProjectDocument(
    schemaVersion:
        AppliedEngineeringProposalAwareCanonicalProjectDocumentCodec
            .schemaVersion,
    payload: payload,
  );
}

String _sha(String character) => List<String>.filled(64, character).join();
