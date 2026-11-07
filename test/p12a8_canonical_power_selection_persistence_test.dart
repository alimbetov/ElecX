import 'dart:convert';
import 'dart:io';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_mutation_reservation.dart';
import 'package:elecx/src/application/project/engineering/engineering_proposal_diff.dart';
import 'package:elecx/src/application/project/engineering/engineering_reserved_project_command.dart';
import 'package:elecx/src/domain/canonical_engineering_graph.dart';
import 'package:elecx/src/domain/canonical_power_selection.dart';
import 'package:elecx/src/domain/engineering_circuit_topology.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/engineering_project_state.dart';
import 'package:elecx/src/domain/engineering_supply_topology.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/serialization/project/engineering_state_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/power_selection_aware_canonical_project_document_codec.dart';
import 'package:elecx/src/serialization/project/project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p1010_service_anchor_fixture.dart';
import 'support/p109_site_fixture.dart';

const digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

CanonicalEngineeringSourceReference source(String id) =>
    CanonicalEngineeringSourceReference(
      sourceId: id,
      revision: 'rev-1',
      sha256: digest,
      approvalId: 'approval-1',
    );

CanonicalPowerCircuitSelection selection(String id) =>
    CanonicalPowerCircuitSelection(
      circuitId: CircuitId(id),
      generationKey: 'generation-$id',
      boardComponentId: ComponentId('board-1'),
      boardCatalogTypeId: 'board-type-v2',
      catalogSnapshotId: 'catalog-snapshot-v2',
      boardRatings: CanonicalBoardElectricalRatings(
        ratedBusbarCurrentA: 63,
        shortCircuitWithstandKa: 6,
        ratedVoltageV: 230,
        ipRating: 'IP40',
        manufacturerSourceId: 'board-doc',
      ),
      cableCatalogId: 'cable-3x2.5',
      cableRatings: CanonicalCableElectricalRatings(
        conductorCrossSectionMm2: 2.5,
        conductorCount: 3,
        ratedVoltageV: 450,
        governingAmpacityA: 25,
        calculatedVoltageDropRatio: 0.012,
      ),
      cableSourceId: 'cable-doc',
      protectionCatalogId: 'mcb-b16',
      protectionRatings: CanonicalProtectionElectricalRatings(
        ratedCurrentA: 16,
        breakingCapacityKa: 6,
        poleCount: 1,
        deviceKind: 'mcb',
        tripCharacteristic: 'B',
      ),
      protectionSourceId: 'breaker-doc',
      normativeSourceId: 'normative-doc',
      routeEvidenceSourceId: 'route-survey',
      faultCurrentEvidenceSourceId: 'fault-study',
      routeLengthMm: 12000,
      evidenceFingerprint: digest,
      sources: [
        source('breaker-doc'),
        source('board-doc'),
        source('cable-doc'),
        source('normative-doc'),
        source('route-survey'),
        source('fault-study'),
      ],
    );

EngineeringProjectState validEngineeringState() {
  final circuitId = CircuitId('c1');
  final board = EngineeringGraphComponent(
    id: ComponentId('board-1'),
    componentTypeId: 'board-type-v2',
    discipline: EngineeringDiscipline.power,
    systemClass: EngineeringSystemClass.powerAc,
    ports: [
      EngineeringPortSpec.identified(
        portId: PortId('out'),
        direction: EngineeringPortDirection.output,
        allowedConnections: {EngineeringConnectionType.acSinglePhase},
        media: {EngineeringMedia.acPower},
      ),
    ],
  );
  final load = EngineeringGraphComponent(
    id: ComponentId('load-1'),
    componentTypeId: 'load-type',
    discipline: EngineeringDiscipline.power,
    systemClass: EngineeringSystemClass.powerAc,
    ports: [
      EngineeringPortSpec.identified(
        portId: PortId('in'),
        direction: EngineeringPortDirection.input,
        allowedConnections: {EngineeringConnectionType.acSinglePhase},
        media: {EngineeringMedia.acPower},
      ),
    ],
  );
  final connection = EngineeringGraphConnection(
    id: EngineeringConnectionId('feed-1'),
    fromComponentId: board.id,
    fromPortId: PortId('out'),
    toComponentId: load.id,
    toPortId: PortId('in'),
    connectionType: EngineeringConnectionType.acSinglePhase,
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
    circuitId: circuitId,
  );
  final source = EngineeringSupplySource(
    id: EngineeringSupplySourceId('power-source-1'),
    endpoint: EngineeringPortRef(
      componentId: board.id,
      portId: PortId('out'),
    ),
    systemClass: EngineeringSystemClass.powerAc,
    media: EngineeringMedia.acPower,
  );
  return EngineeringProjectState(
    graph: CanonicalEngineeringGraph(
      components: [board, load],
      connections: [connection],
    ),
    circuits: [
      EngineeringCircuit(
        id: circuitId,
        systemClass: EngineeringSystemClass.powerAc,
        media: EngineeringMedia.acPower,
        connectionIds: [connection.id],
      ),
    ],
    sources: [source],
    circuitSupplies: [
      EngineeringCircuitSupply(
        circuitId: circuitId,
        sourceIds: [source.id],
      ),
    ],
  );
}

ProjectAggregateRoot projectWithPowerSelection() {
  final project = P1010ServiceAnchorFixture().project;
  return ProjectAggregateRoot(
    id: project.id,
    siteId: project.siteId,
    version: project.version,
    stores: project.stores,
    engineeringMetadata: project.engineeringMetadata
        .withEngineeringState(validEngineeringState())
        .withPowerSelections(
          CanonicalPowerSelectionRegistry(selections: [selection('c1')]),
        ),
  );
}

/// Simulates a structurally valid but referentially destructive update.
final class _DropEngineeringStateCommand implements ProjectCommand {
  @override
  String get commandType => 'test.drop-engineering-state';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) =>
      ProjectCommandCandidate.fromState(
        state: ProjectMutableState(
          engineeringMetadata: current.engineeringMetadata.withEngineeringState(
            EngineeringProjectState.empty(),
          ),
          stores: current.stores,
        ),
      );
}

void main() {
  group('P12A.8 canonical POWER persistence model', () {
    test('registry JSON round-trip preserves all fields and stable fingerprint',
        () {
      final first = CanonicalPowerSelectionRegistry(
        selections: [selection('c2'), selection('c1')],
      );
      final encoded = jsonEncode(first.toCanonicalJson());
      final decoded = CanonicalPowerSelectionRegistry.fromCanonicalJson(
        jsonDecode(encoded),
      );
      expect(decoded.fingerprint, first.fingerprint);
      expect(jsonEncode(decoded.toCanonicalJson()), encoded);
      expect(decoded.byCircuit[CircuitId('c1')]!.cableCatalogId, 'cable-3x2.5');
      expect(
        decoded.byCircuit[CircuitId('c1')]!.boardRatings.ratedBusbarCurrentA,
        63,
      );
      expect(decoded.byCircuit[CircuitId('c1')]!.sources, hasLength(6));
      expect(
          decoded.byCircuit[CircuitId('c1')]!.cableRatings.conductorCount, 3);
      expect(
          decoded.byCircuit[CircuitId('c1')]!.protectionRatings.ratedCurrentA,
          16);
      expect(() => decoded.byCircuit.clear(), throwsUnsupportedError);
    });

    test('duplicate IDs and generation keys are rejected', () {
      expect(
        () => CanonicalPowerSelectionRegistry(
          selections: [selection('c1'), selection('c1')],
        ),
        throwsArgumentError,
      );
    });

    test('unsupported versions and unknown persisted fields fail closed', () {
      final original = CanonicalPowerSelectionRegistry(
        selections: [selection('c1')],
      ).toCanonicalJson();
      expect(
        () => CanonicalPowerSelectionRegistry.fromCanonicalJson({
          ...original,
          'schemaVersion': 999,
        }),
        throwsFormatException,
      );
      final modified = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
      (modified['selections'] as List).first['inventedKey'] = true;
      expect(
        () => CanonicalPowerSelectionRegistry.fromCanonicalJson(modified),
        throwsFormatException,
      );
    });

    test('nonfinite ratings and missing source references are rejected', () {
      expect(
        () => CanonicalBoardElectricalRatings(
          ratedBusbarCurrentA: double.nan,
          shortCircuitWithstandKa: 6,
          ratedVoltageV: 230,
          ipRating: 'IP40',
          manufacturerSourceId: 'board-doc',
        ),
        throwsArgumentError,
      );
      final encoded = selection('c1').toCanonicalJson();
      (encoded['sources'] as List).removeLast();
      expect(
        () => CanonicalPowerCircuitSelection.fromCanonicalJson(encoded),
        throwsArgumentError,
      );
    });
  });

  group('P12A.8 reserved engineering preview', () {
    test(
        'frozen canonical preview uses existing P11 circuit IDs and cannot Apply',
        () {
      final base = P1010ServiceAnchorFixture().project;
      final current = ProjectAggregateRoot(
        id: base.id,
        siteId: base.siteId,
        version: base.version,
        stores: base.stores,
        engineeringMetadata: base.engineeringMetadata
            .withEngineeringState(validEngineeringState()),
      );
      final proposed = EngineeringProposalDiff(
        sourceFingerprint: 'test-source',
        boardGenerationKey: 'board-key',
        catalogSnapshotId: 'catalog-snapshot-v2',
        entries: [
          EngineeringProposalDiffEntry(
            generationKey: 'generation-c1',
            calculationCircuitId: 'calculated-c1',
            status: EngineeringProposalStatus.selected,
            cableCatalogId: 'cable-3x2.5',
            protectionCatalogId: 'mcb-b16',
          ),
        ],
        issues: const [],
      );
      final command = EngineeringReservedProjectCommand(
        proposal: proposed,
        requestedSelections:
            CanonicalPowerSelectionRegistry(selections: [selection('c1')]),
        canonicalCircuitIdsByCalculationId: {'calculated-c1': CircuitId('c1')},
        expectedEngineeringStateFingerprint:
            current.engineeringMetadata.engineeringState.fingerprint,
        expectedPowerSelectionFingerprint:
            current.engineeringMetadata.powerSelections.fingerprint,
      );
      final session = ProjectMutationSession(current);
      final coordinator = ReservedProjectMutationCoordinator(session);
      final preview = coordinator.preview(command);
      expect(preview.hasChanges, isTrue);
      expect(preview.candidate.engineeringMetadata.powerSelections.byCircuit,
          contains(CircuitId('c1')));
      expect(preview.preview.engineeringMetadataDiff.powerSelectionsChanged,
          isTrue);
      expect(preview.semanticChangeSet.operations.single.semanticKey,
          contains('c1'));
      expect(
          session.current.engineeringMetadata.powerSelections.isEmpty, isTrue);
      expect(() => coordinator.commitPreview(preview), throwsStateError);
      expect(session.current.version, current.version);
      expect(session.undoDepth, 0);
    });

    test('incorrect or incomplete calculator-to-canonical lineage fails closed',
        () {
      final proposal = EngineeringProposalDiff(
        sourceFingerprint: 'source',
        boardGenerationKey: 'board-key',
        catalogSnapshotId: 'catalog-snapshot-v2',
        entries: [
          EngineeringProposalDiffEntry(
            generationKey: 'generation-c1',
            calculationCircuitId: 'calculated-c1',
            status: EngineeringProposalStatus.selected,
            cableCatalogId: 'cable-3x2.5',
            protectionCatalogId: 'mcb-b16',
          ),
        ],
        issues: const [],
      );
      EngineeringReservedProjectCommand create(Map<String, CircuitId> ids) =>
          EngineeringReservedProjectCommand(
            proposal: proposal,
            requestedSelections: CanonicalPowerSelectionRegistry(
              selections: [selection('c1')],
            ),
            canonicalCircuitIdsByCalculationId: ids,
            expectedEngineeringStateFingerprint: 'state',
            expectedPowerSelectionFingerprint: 'registry',
          );

      expect(() => create({}), throwsArgumentError);
      expect(
        () => create({'calculated-c1': CircuitId('wrong-circuit')}),
        throwsArgumentError,
      );
      expect(
        () => create({
          'calculated-c1': CircuitId('c1'),
          'undeclared-calculation': CircuitId('extra'),
        }),
        throwsArgumentError,
      );
      final mutable = {'calculated-c1': CircuitId('c1')};
      final command = create(mutable);
      final intent = command.normalizedIntentKey;
      mutable['calculated-c1'] = CircuitId('tampered');
      expect(command.normalizedIntentKey, intent);
      expect(
        command.canonicalCircuitIdsByCalculationId['calculated-c1'],
        CircuitId('c1'),
      );
    });

    test('proposal/selection catalog mismatch fails closed before preview', () {
      final proposal = EngineeringProposalDiff(
        sourceFingerprint: 'source',
        boardGenerationKey: 'board-key',
        catalogSnapshotId: 'catalog-snapshot-v2',
        entries: [
          EngineeringProposalDiffEntry(
            generationKey: 'generation-c1',
            calculationCircuitId: 'calculated-c1',
            status: EngineeringProposalStatus.selected,
            cableCatalogId: 'different-cable',
            protectionCatalogId: 'mcb-b16',
          ),
        ],
        issues: const [],
      );
      expect(
        () => EngineeringReservedProjectCommand(
          proposal: proposal,
          requestedSelections: CanonicalPowerSelectionRegistry(
            selections: [selection('c1')],
          ),
          canonicalCircuitIdsByCalculationId: {'calculated-c1': CircuitId('c1')},
          expectedEngineeringStateFingerprint: 'state',
          expectedPowerSelectionFingerprint: 'registry',
        ),
        throwsArgumentError,
      );
    });
  });

  group('P12A.8 v21 project persistence envelope', () {
    const codec = PowerSelectionAwareCanonicalProjectDocumentCodec();
    const legacy = EngineeringStateAwareCanonicalProjectDocumentCodec();

    test('v20 project upgrades to v21 with empty canonical POWER registry', () {
      final aggregate = P1010ServiceAnchorFixture().project;
      final snapshot = p109Snapshot(aggregate);
      final old = legacy.encode(snapshot);
      final migrated = codec.decode(old);
      expect(migrated.aggregate.engineeringMetadata.powerSelections.isEmpty,
          isTrue);
      final document = codec.encode(migrated);
      expect(document.schemaVersion, 21);
      final reopened = codec.decode(document);
      expect(reopened.aggregate.engineeringMetadata.powerSelections.isEmpty,
          isTrue);
      expect(jsonEncode(codec.encode(reopened).payload),
          jsonEncode(document.payload));
    });

    test('aggregate rejects orphan selections before persistence or commit',
        () {
      final project = P1010ServiceAnchorFixture().project;
      expect(
        () => ProjectAggregateRoot(
          id: project.id,
          siteId: project.siteId,
          version: project.version,
          stores: project.stores,
          engineeringMetadata: project.engineeringMetadata.withPowerSelections(
            CanonicalPowerSelectionRegistry(selections: [selection('orphan')]),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('P11 engineering-state-only edits produce a canonical metadata diff',
        () {
      final base = P1010ServiceAnchorFixture().project;
      final project = ProjectAggregateRoot(
        id: base.id,
        siteId: base.siteId,
        version: base.version,
        stores: base.stores,
        engineeringMetadata: base.engineeringMetadata
            .withEngineeringState(validEngineeringState()),
      );
      final session = ProjectMutationSession(project);
      final preview = session.preview(ProjectMutationRequest(
        expectedVersion: project.version,
        command: _DropEngineeringStateCommand(),
      ));
      expect(preview.hasChanges, isTrue);
      expect(preview.engineeringMetadataDiff.engineeringStateChanged, isTrue);
      expect(session.current.engineeringMetadata.engineeringState.isEmpty,
          isFalse);
    });

    test(
        'P11 engineering-only commit advances version and Undo/Redo restores it',
        () {
      final base = P1010ServiceAnchorFixture().project;
      final original = ProjectAggregateRoot(
        id: base.id,
        siteId: base.siteId,
        version: base.version,
        stores: base.stores,
        engineeringMetadata: base.engineeringMetadata
            .withEngineeringState(validEngineeringState()),
      );
      final session = ProjectMutationSession(original);
      final committed = session.commit(ProjectMutationRequest(
        expectedVersion: original.version,
        command: _DropEngineeringStateCommand(),
      ))!;
      expect(
          committed.changeSet.engineeringMetadataDiff.engineeringStateChanged,
          isTrue);
      expect(
          session.current.engineeringMetadata.engineeringState.isEmpty, isTrue);
      expect(session.undoDepth, 1);
      final undo = session.undo(session.current.version)!;
      expect(undo.changeSet.engineeringMetadataDiff.engineeringStateChanged,
          isTrue);
      expect(session.current.engineeringMetadata.engineeringState.fingerprint,
          original.engineeringMetadata.engineeringState.fingerprint);
      final redo = session.redo(session.current.version)!;
      expect(redo.changeSet.engineeringMetadataDiff.engineeringStateChanged,
          isTrue);
      expect(
          session.current.engineeringMetadata.engineeringState.isEmpty, isTrue);
    });

    test('mutation preview refuses to drop a selected P11 circuit and board',
        () {
      final valid = projectWithPowerSelection();
      final session = ProjectMutationSession(valid);
      expect(
        () => session.preview(ProjectMutationRequest(
          expectedVersion: valid.version,
          command: _DropEngineeringStateCommand(),
        )),
        throwsArgumentError,
      );
      expect(session.current.engineeringMetadata.powerSelections.byCircuit,
          contains(CircuitId('c1')));
    });

    test('non-empty v21 JSON repository Save/Reopen preserves all evidence',
        () async {
      final project = projectWithPowerSelection();
      final directory = await Directory.systemTemp.createTemp('p12a8-v21-');
      addTearDown(() => directory.delete(recursive: true));
      final repository = JsonProjectRepository(
        rootDirectory: directory,
        codec: codec,
      );
      await repository.save(p109Snapshot(project));
      final loaded = (await repository.load(project.id))!;
      final original = project.engineeringMetadata.powerSelections;
      final reopened = loaded.aggregate.engineeringMetadata.powerSelections;
      expect(reopened.sameAs(original), isTrue);
      expect(reopened.fingerprint, original.fingerprint);
      expect(loaded.aggregate.engineeringMetadata.engineeringState.fingerprint,
          project.engineeringMetadata.engineeringState.fingerprint);
      expect(
        reopened.byCircuit[CircuitId('c1')]!.boardComponentId,
        ComponentId('board-1'),
      );
      expect(
        reopened.byCircuit[CircuitId('c1')]!.sources.map((s) => s.sourceId),
        containsAll(['fault-study', 'normative-doc', 'route-survey']),
      );
      final old = legacy;
      expect(() => old.encode(p109Snapshot(project)), throwsFormatException);
    });

    test('v21 decoder rejects tampered orphan selection references', () {
      final document = codec.encode(p109Snapshot(projectWithPowerSelection()));
      final payload =
          jsonDecode(jsonEncode(document.payload)) as Map<String, dynamic>;
      final selection =
          (payload['powerSelections']['selections'] as List).first;
      selection['circuitId'] = 'missing-circuit';
      expect(
        () => codec.decode(ProjectDocument(
          schemaVersion: 21,
          payload: payload,
        )),
        throwsFormatException,
      );
    });

    test('older schema cannot disguise a v21 POWER selection payload', () {
      final aggregate = P1010ServiceAnchorFixture().project;
      final v21 = codec.encode(p109Snapshot(aggregate));
      expect(
        () => codec.decode(ProjectDocument(
          schemaVersion: 20,
          payload: v21.payload,
        )),
        throwsFormatException,
      );
    });
  });
}
