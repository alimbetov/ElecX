import '../../application/project/project_snapshot.dart';
import '../../domain/applied_engineering_proposal.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_identity.dart';
import 'generation_provenance_aware_canonical_project_document_codec.dart';
import 'project_document_codec.dart';

/// Schema-v13 additive persistence for the exact engineering proposal committed
/// by P9 Apply.
///
/// v1..v12 remain owned by the existing codec chain. Older documents load with
/// an explicit empty applied-proposal registry.
final class AppliedEngineeringProposalAwareCanonicalProjectDocumentCodec
    implements ProjectDocumentCodec {
  const AppliedEngineeringProposalAwareCanonicalProjectDocumentCodec();

  static const int schemaVersion = 13;
  static const int proposalSchemaVersion = 1;
  static const GenerationProvenanceAwareCanonicalProjectDocumentCodec _base =
      GenerationProvenanceAwareCanonicalProjectDocumentCodec();

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  ProjectDocument encode(ProjectSnapshot snapshot) {
    final base = _base.encode(snapshot);
    return ProjectDocument(
      schemaVersion: schemaVersion,
      payload: <String, Object?>{
        ...base.payload,
        'appliedEngineeringProposals': _encodeRegistry(
          snapshot
              .aggregate.engineeringMetadata.appliedEngineeringProposalRegistry,
        ),
      },
    );
  }

  @override
  ProjectSnapshot decode(ProjectDocument document) {
    if (document.schemaVersion < 1 || document.schemaVersion > schemaVersion) {
      throw FormatException(
        'Unsupported canonical ElecX project schema '
        '${document.schemaVersion}; supported versions are 1..$schemaVersion.',
      );
    }
    if (document.schemaVersion <=
        GenerationProvenanceAwareCanonicalProjectDocumentCodec.schemaVersion) {
      return _base.decode(document);
    }

    final registry = _decodeRegistry(
      document.payload['appliedEngineeringProposals'],
    );
    final base = _base.decode(
      ProjectDocument(
        schemaVersion: GenerationProvenanceAwareCanonicalProjectDocumentCodec
            .schemaVersion,
        payload: document.payload,
      ),
    );
    for (final levelId in registry.byLevel.keys) {
      if (!base.aggregate.stores.levels.containsKey(levelId)) {
        throw FormatException(
          'Applied engineering proposal references missing level $levelId.',
        );
      }
    }
    final aggregate = ProjectAggregateRoot(
      id: base.id,
      siteId: base.siteId,
      version: base.localVersion,
      engineeringMetadata: base.aggregate.engineeringMetadata
          .withAppliedEngineeringProposalRegistry(registry),
      stores: base.aggregate.stores,
    );
    return base.copyWith(aggregate: aggregate);
  }

  static Map<String, Object?> _encodeRegistry(
    AppliedEngineeringProposalRegistry registry,
  ) {
    final proposals = registry.byLevel.values.toList()
      ..sort(
          (left, right) => left.levelId.value.compareTo(right.levelId.value));
    return <String, Object?>{
      'schemaVersion': proposalSchemaVersion,
      'proposals': <Object?>[
        for (final proposal in proposals)
          <String, Object?>{
            'levelId': proposal.levelId.value,
            'proposalVersion': proposal.proposalVersion,
            'outputProjectionVersion': proposal.outputProjectionVersion,
            'candidateSetFingerprint': proposal.candidateSetFingerprint,
            'candidateFingerprint': proposal.candidateFingerprint,
            'intentFingerprint': proposal.intentFingerprint,
            'd1RequirementsFingerprint': proposal.d1RequirementsFingerprint,
            'requirementsFingerprint': proposal.requirementsFingerprint,
            'outputFingerprint': proposal.outputFingerprint,
            'proposalFingerprint': proposal.proposalFingerprint,
            'loadScheduleRows': proposal.loadScheduleRows,
            'circuitScheduleRows': proposal.circuitScheduleRows,
            'panelSummary': proposal.panelSummary,
            'sldNodes': proposal.sldNodes,
            'sldEdges': proposal.sldEdges,
            'explanations': proposal.explanations,
          },
      ],
    };
  }

  static AppliedEngineeringProposalRegistry _decodeRegistry(Object? raw) {
    final json = _map(raw, 'appliedEngineeringProposals');
    final version = _int(
      json['schemaVersion'],
      'appliedEngineeringProposals.schemaVersion',
    );
    if (version != proposalSchemaVersion) {
      throw FormatException(
        'Unsupported applied engineering proposal schema $version; expected '
        '$proposalSchemaVersion.',
      );
    }
    final byLevel = <LevelId, AppliedEngineeringProposalSnapshot>{};
    for (final rawProposal
        in _list(json['proposals'], 'appliedEngineeringProposals.proposals')) {
      final value = _map(rawProposal, 'appliedEngineeringProposal');
      final levelId = LevelId(
        _string(value['levelId'], 'appliedEngineeringProposal.levelId'),
      );
      if (byLevel.containsKey(levelId)) {
        throw FormatException(
          'Duplicate applied engineering proposal for $levelId.',
        );
      }
      byLevel[levelId] = AppliedEngineeringProposalSnapshot(
        levelId: levelId,
        proposalVersion: _string(
          value['proposalVersion'],
          'appliedEngineeringProposal.proposalVersion',
        ),
        outputProjectionVersion: _string(
          value['outputProjectionVersion'],
          'appliedEngineeringProposal.outputProjectionVersion',
        ),
        candidateSetFingerprint: _string(
          value['candidateSetFingerprint'],
          'appliedEngineeringProposal.candidateSetFingerprint',
        ),
        candidateFingerprint: _string(
          value['candidateFingerprint'],
          'appliedEngineeringProposal.candidateFingerprint',
        ),
        intentFingerprint: _string(
          value['intentFingerprint'],
          'appliedEngineeringProposal.intentFingerprint',
        ),
        d1RequirementsFingerprint: _string(
          value['d1RequirementsFingerprint'],
          'appliedEngineeringProposal.d1RequirementsFingerprint',
        ),
        requirementsFingerprint: _string(
          value['requirementsFingerprint'],
          'appliedEngineeringProposal.requirementsFingerprint',
        ),
        outputFingerprint: _string(
          value['outputFingerprint'],
          'appliedEngineeringProposal.outputFingerprint',
        ),
        proposalFingerprint: _string(
          value['proposalFingerprint'],
          'appliedEngineeringProposal.proposalFingerprint',
        ),
        loadScheduleRows: _stringList(
          value['loadScheduleRows'],
          'appliedEngineeringProposal.loadScheduleRows',
        ),
        circuitScheduleRows: _stringList(
          value['circuitScheduleRows'],
          'appliedEngineeringProposal.circuitScheduleRows',
        ),
        panelSummary: _string(
          value['panelSummary'],
          'appliedEngineeringProposal.panelSummary',
        ),
        sldNodes: _stringList(
          value['sldNodes'],
          'appliedEngineeringProposal.sldNodes',
        ),
        sldEdges: _stringList(
          value['sldEdges'],
          'appliedEngineeringProposal.sldEdges',
        ),
        explanations: _stringList(
          value['explanations'],
          'appliedEngineeringProposal.explanations',
        ),
      );
    }
    return AppliedEngineeringProposalRegistry(byLevel: byLevel);
  }

  static Map<String, Object?> _map(Object? value, String path) {
    if (value is! Map) {
      throw FormatException('$path must be an object.');
    }
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<Object?> _list(Object? value, String path) {
    if (value is! List) {
      throw FormatException('$path must be an array.');
    }
    return List<Object?>.from(value);
  }

  static int _int(Object? value, String path) {
    if (value is! int) throw FormatException('$path must be an integer.');
    return value;
  }

  static String _string(Object? value, String path) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$path must be a non-empty string.');
    }
    return value;
  }

  static List<String> _stringList(Object? value, String path) =>
      _list(value, path).map((item) => _string(item, '$path[]')).toList();
}
