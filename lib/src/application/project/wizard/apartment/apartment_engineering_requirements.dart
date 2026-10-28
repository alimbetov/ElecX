import 'apartment_canonical_projection.dart';
import 'apartment_normative_evidence.dart';
import 'p9_canonical_serialization.dart';
import 'p9_failure.dart';
import 'p9_sha256.dart';

const String apartmentEngineeringRequirementsVersion = 'p9.requirements.v3';

enum ApartmentEngineeringRequirementDomain {
  supply,
  load,
  circuit,
  protection,
}

enum ApartmentEngineeringRequirementEvidenceState {
  notEvaluated,
  proven,
  indeterminate,
  notApplicable,
}

enum ApartmentEngineeringRequirementCriticality {
  safetyCritical,
  engineeringCritical,
  advisory,
}

enum ApartmentEngineeringRequirementSubjectKind {
  projection,
  component,
  connection,
  placement,
}

enum ApartmentEngineeringFactValueKind {
  integer,
  decimal,
  booleanValue,
  text,
}

enum ApartmentEngineeringFactUnit {
  none,
  volt,
  ampere,
  watt,
  hertz,
  squareMillimeter,
  milliampere,
  kiloampere,
  count,
  percent,
  ratio,
  code,
}

extension ApartmentEngineeringFactUnitSymbol on ApartmentEngineeringFactUnit {
  String get symbol => switch (this) {
        ApartmentEngineeringFactUnit.none => '',
        ApartmentEngineeringFactUnit.volt => 'V',
        ApartmentEngineeringFactUnit.ampere => 'A',
        ApartmentEngineeringFactUnit.watt => 'W',
        ApartmentEngineeringFactUnit.hertz => 'Hz',
        ApartmentEngineeringFactUnit.squareMillimeter => 'mm2',
        ApartmentEngineeringFactUnit.milliampere => 'mA',
        ApartmentEngineeringFactUnit.kiloampere => 'kA',
        ApartmentEngineeringFactUnit.count => 'count',
        ApartmentEngineeringFactUnit.percent => '%',
        ApartmentEngineeringFactUnit.ratio => 'ratio',
        ApartmentEngineeringFactUnit.code => 'code',
      };
}

/// One typed, source-pinned engineering fact.
///
/// A fact exists only when its value is backed by an authoritative source and
/// revision. Unknown facts are represented by absence, never by zero/defaults.
final class ApartmentEngineeringFactEvidence {
  ApartmentEngineeringFactEvidence({
    required this.factKey,
    required this.valueKind,
    required this.value,
    required this.unit,
    required this.sourceId,
    required this.sourceRevision,
  }) {
    if (factKey.trim().isEmpty ||
        sourceId.trim().isEmpty ||
        sourceRevision.trim().isEmpty) {
      throw ArgumentError(
        'P9.5-A fact identity/source fields must be non-empty.',
      );
    }
    _validateTypedValue(valueKind: valueKind, value: value);
  }

  final String factKey;
  final ApartmentEngineeringFactValueKind valueKind;
  final Object value;
  final ApartmentEngineeringFactUnit unit;
  final String sourceId;
  final String sourceRevision;

  String get canonicalValue => switch (valueKind) {
        ApartmentEngineeringFactValueKind.integer => (value as int).toString(),
        ApartmentEngineeringFactValueKind.decimal =>
          (value as double).toString(),
        ApartmentEngineeringFactValueKind.booleanValue =>
          (value as bool).toString(),
        ApartmentEngineeringFactValueKind.text => value as String,
      };

  String get displayValue =>
      unit.symbol.isEmpty ? canonicalValue : '$canonicalValue ${unit.symbol}';

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('factKey', factKey),
        MapEntry('valueKind', valueKind.name),
        MapEntry('value', canonicalValue),
        MapEntry('unit', unit.name),
        MapEntry('sourceId', sourceId),
        MapEntry('sourceRevision', sourceRevision),
      ]);

  String get evidenceFingerprint => p9Sha256Hex(stableSerialization);
}

/// One immutable engineering requirement that must be established before
/// equipment can be configured automatically.
///
/// P9.5-A deliberately models required facts separately from established facts.
/// Missing upstream electrical intent is represented as [notEvaluated]; it is
/// never replaced by guessed voltage, power, current, circuit or protection
/// values.
final class ApartmentEngineeringRequirement {
  ApartmentEngineeringRequirement({
    required this.requirementId,
    required this.domain,
    required this.subjectKind,
    required this.subjectStableId,
    required this.evidenceState,
    required this.criticality,
    required this.rationaleCode,
    required Iterable<String> requiredFactKeys,
    Iterable<ApartmentEngineeringFactEvidence> factEvidence = const [],
    Map<String, String> establishedFacts = const {},
  })  : requiredFactKeys = List.unmodifiable(
          requiredFactKeys.toSet().toList()..sort(),
        ),
        factEvidence = _indexFactEvidence(factEvidence) {
    if (requirementId.trim().isEmpty ||
        subjectStableId.trim().isEmpty ||
        rationaleCode.trim().isEmpty) {
      throw ArgumentError(
        'P9.5-A requirement identity and rationale must be non-empty.',
      );
    }
    if (this.requiredFactKeys.isEmpty ||
        this.requiredFactKeys.any((key) => key.trim().isEmpty)) {
      throw ArgumentError(
        'P9.5-A requirement must declare non-empty required fact keys.',
      );
    }
    if (establishedFacts.isNotEmpty) {
      throw ArgumentError(
        'Legacy string establishedFacts are not accepted. Use typed factEvidence.',
      );
    }

    final unknownFactKeys = this
        .factEvidence
        .keys
        .where((key) => !this.requiredFactKeys.contains(key))
        .toList(growable: false);
    if (unknownFactKeys.isNotEmpty) {
      throw ArgumentError(
        'P9.5-A evidence contains facts not declared by the requirement: '
        '$unknownFactKeys.',
      );
    }

    if (evidenceState == ApartmentEngineeringRequirementEvidenceState.proven) {
      final missingFactKeys = this
          .requiredFactKeys
          .where((key) => !this.factEvidence.containsKey(key))
          .toList(growable: false);
      if (missingFactKeys.isNotEmpty) {
        throw ArgumentError(
          'Proven P9.5-A requirement is missing typed evidence for: '
          '$missingFactKeys.',
        );
      }
    }

    if ((evidenceState ==
                ApartmentEngineeringRequirementEvidenceState.notEvaluated ||
            evidenceState ==
                ApartmentEngineeringRequirementEvidenceState.notApplicable) &&
        this.factEvidence.isNotEmpty) {
      throw ArgumentError(
        'P9.5-A ${evidenceState.name} requirement cannot carry proven facts.',
      );
    }
  }

  final String requirementId;
  final ApartmentEngineeringRequirementDomain domain;
  final ApartmentEngineeringRequirementSubjectKind subjectKind;
  final String subjectStableId;
  final ApartmentEngineeringRequirementEvidenceState evidenceState;
  final ApartmentEngineeringRequirementCriticality criticality;
  final String rationaleCode;
  final List<String> requiredFactKeys;
  final Map<String, ApartmentEngineeringFactEvidence> factEvidence;

  /// Compatibility view for older diagnostics/tests. It is derived from the
  /// authoritative typed evidence and cannot be used to construct requirements.
  Map<String, String> get establishedFacts => Map.unmodifiable({
        for (final entry in factEvidence.entries)
          entry.key: entry.value.displayValue,
      });

  bool get isResolved =>
      evidenceState == ApartmentEngineeringRequirementEvidenceState.proven ||
      evidenceState ==
          ApartmentEngineeringRequirementEvidenceState.notApplicable;

  bool get blocksEquipmentConfiguration =>
      !isResolved &&
      criticality != ApartmentEngineeringRequirementCriticality.advisory;

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('id', requirementId),
        MapEntry('domain', domain.name),
        MapEntry('subjectKind', subjectKind.name),
        MapEntry('subject', subjectStableId),
        MapEntry('state', evidenceState.name),
        MapEntry('criticality', criticality.name),
        MapEntry('rationale', rationaleCode),
        MapEntry(
          'requiredFacts',
          p9CanonicalSerializeFields([
            for (final key in requiredFactKeys) MapEntry('fact', key),
          ]),
        ),
        MapEntry(
          'factEvidence',
          p9CanonicalSerializeFields([
            for (final entry in factEvidence.entries)
              MapEntry(entry.key, entry.value.stableSerialization),
          ]),
        ),
      ]);
}

/// Immutable P9.5-A contract between the accepted P9.3/P9.4 proposal and later
/// equipment feasibility/catalog stages.
///
/// The envelope owns no graph, geometry or normative data. It only pins their
/// fingerprints and declares which authoritative electrical facts are still
/// required before P9.5-B+ may select equipment.
final class ApartmentEngineeringDesignRequirements {
  ApartmentEngineeringDesignRequirements({
    required this.requirementsVersion,
    required this.selectedCandidateFingerprint,
    required this.projectionFingerprint,
    required this.graphFingerprint,
    required this.placementFingerprint,
    required this.normativeEvidenceFingerprint,
    required this.normativeProfileId,
    required this.normativeProfileVersion,
    required Iterable<ApartmentEngineeringRequirement> requirements,
  }) : requirements = List.unmodifiable(
          requirements.toList()
            ..sort((left, right) =>
                left.requirementId.compareTo(right.requirementId)),
        ) {
    if (requirementsVersion.trim().isEmpty ||
        selectedCandidateFingerprint.trim().isEmpty ||
        projectionFingerprint.trim().isEmpty ||
        graphFingerprint.trim().isEmpty ||
        placementFingerprint.trim().isEmpty ||
        normativeEvidenceFingerprint.trim().isEmpty ||
        normativeProfileId.trim().isEmpty ||
        normativeProfileVersion.trim().isEmpty) {
      throw ArgumentError(
        'P9.5-A requirements lineage/version fields must be non-empty.',
      );
    }
    if (this.requirements.isEmpty) {
      throw ArgumentError('P9.5-A must declare engineering requirements.');
    }
    final ids = <String>{};
    for (final requirement in this.requirements) {
      if (!ids.add(requirement.requirementId)) {
        throw ArgumentError(
          'Duplicate P9.5-A requirement ${requirement.requirementId}.',
        );
      }
    }
  }

  final String requirementsVersion;
  final String selectedCandidateFingerprint;
  final String projectionFingerprint;
  final String graphFingerprint;
  final String placementFingerprint;
  final String normativeEvidenceFingerprint;
  final String normativeProfileId;
  final String normativeProfileVersion;
  final List<ApartmentEngineeringRequirement> requirements;

  List<ApartmentEngineeringRequirement> get unresolvedRequirements =>
      List.unmodifiable(
        requirements.where((requirement) => !requirement.isResolved),
      );

  List<ApartmentEngineeringRequirement> get blockingUnresolvedRequirements =>
      List.unmodifiable(
        requirements.where(
          (requirement) => requirement.blocksEquipmentConfiguration,
        ),
      );

  bool get readyForEquipmentConfiguration =>
      blockingUnresolvedRequirements.isEmpty;

  String get stableSerialization => p9CanonicalSerializeFields([
        MapEntry('requirementsVersion', requirementsVersion),
        MapEntry('candidate', selectedCandidateFingerprint),
        MapEntry('projection', projectionFingerprint),
        MapEntry('graph', graphFingerprint),
        MapEntry('placement', placementFingerprint),
        MapEntry('normative', normativeEvidenceFingerprint),
        MapEntry('normativeProfileId', normativeProfileId),
        MapEntry('normativeProfileVersion', normativeProfileVersion),
        for (final requirement in requirements)
          MapEntry('requirement', requirement.stableSerialization),
      ]);

  String get requirementsFingerprint => p9Sha256Hex(stableSerialization);
}

final class ApartmentEngineeringRequirementsResult {
  ApartmentEngineeringRequirementsResult({
    required this.requirements,
    Iterable<P9Failure> failures = const [],
  }) : failures = List.unmodifiable(failures);

  final ApartmentEngineeringDesignRequirements? requirements;
  final List<P9Failure> failures;

  bool get accepted =>
      requirements != null && failures.every((failure) => !failure.isBlocker);
}

/// P9.5-A exact-lineage requirements derivation.
///
/// This service is intentionally catalog-agnostic. It never selects equipment,
/// never assigns circuits and never infers electrical values from room usage.
final class ApartmentEngineeringRequirementsService {
  const ApartmentEngineeringRequirementsService();

  ApartmentEngineeringRequirementsResult derive({
    required String selectedCandidateFingerprint,
    required ApartmentEngineeringProjection projection,
    required ApartmentNormativeEvidenceBundle normativeEvidence,
  }) {
    final lineageFailure = _lineageFailure(
      selectedCandidateFingerprint: selectedCandidateFingerprint,
      projection: projection,
      normativeEvidence: normativeEvidence,
    );
    if (lineageFailure != null) {
      return ApartmentEngineeringRequirementsResult(
        requirements: null,
        failures: [lineageFailure],
      );
    }
    if (normativeEvidence.blocksEligibility) {
      return ApartmentEngineeringRequirementsResult(
        requirements: null,
        failures: [
          P9Failure(
            code: 'NORMATIVE_BLOCKED',
            stage: P9FailureStage.normative,
            severity: P9FailureSeverity.blocker,
            facts: {
              'reason': 'p9.5a-source-normative-evidence-blocks-eligibility',
              'candidateFingerprint': selectedCandidateFingerprint,
              'projectionFingerprint': projection.projectionFingerprint,
              'normativeEvidenceFingerprint':
                  normativeEvidence.evidenceFingerprint,
              'normativeState': normativeEvidence.overallState.name,
            },
          ),
        ],
      );
    }

    try {
      final subjectStableId = projection.projectionFingerprint;
      final normativeFingerprint = normativeEvidence.evidenceFingerprint;
      final requirements = <ApartmentEngineeringRequirement>[
        _unresolvedRequirement(
          domain: ApartmentEngineeringRequirementDomain.supply,
          criticality:
              ApartmentEngineeringRequirementCriticality.safetyCritical,
          subjectStableId: subjectStableId,
          projectionFingerprint: projection.projectionFingerprint,
          normativeEvidenceFingerprint: normativeFingerprint,
          rationaleCode: 'p9.requirements.supply-intent-not-provided',
          requiredFactKeys: const [
            'supply.availablePowerW',
            'supply.frequencyHz',
            'supply.phaseCount',
            'supply.prospectiveShortCircuitCurrentA',
            'supply.voltageV',
          ],
        ),
        _unresolvedRequirement(
          domain: ApartmentEngineeringRequirementDomain.load,
          criticality:
              ApartmentEngineeringRequirementCriticality.engineeringCritical,
          subjectStableId: subjectStableId,
          projectionFingerprint: projection.projectionFingerprint,
          normativeEvidenceFingerprint: normativeFingerprint,
          rationaleCode: 'p9.requirements.load-intent-not-provided',
          requiredFactKeys: const [
            'load.connectedPowerW',
            'load.designCurrentA',
            'load.designPowerW',
            'load.diversityPolicy',
            'load.reservePolicy',
          ],
        ),
        _unresolvedRequirement(
          domain: ApartmentEngineeringRequirementDomain.circuit,
          criticality:
              ApartmentEngineeringRequirementCriticality.engineeringCritical,
          subjectStableId: subjectStableId,
          projectionFingerprint: projection.projectionFingerprint,
          normativeEvidenceFingerprint: normativeFingerprint,
          rationaleCode: 'p9.requirements.circuit-intent-not-provided',
          requiredFactKeys: const [
            'circuit.conductorConstraints',
            'circuit.definition',
            'circuit.installationMethod',
            'circuit.loadAssignments',
          ],
        ),
        _unresolvedRequirement(
          domain: ApartmentEngineeringRequirementDomain.protection,
          criticality:
              ApartmentEngineeringRequirementCriticality.safetyCritical,
          subjectStableId: subjectStableId,
          projectionFingerprint: projection.projectionFingerprint,
          normativeEvidenceFingerprint: normativeFingerprint,
          rationaleCode: 'p9.requirements.protection-intent-not-provided',
          requiredFactKeys: const [
            'protection.disconnection',
            'protection.overload',
            'protection.residualCurrent',
            'protection.shortCircuit',
          ],
        ),
      ];

      return ApartmentEngineeringRequirementsResult(
        requirements: ApartmentEngineeringDesignRequirements(
          requirementsVersion: apartmentEngineeringRequirementsVersion,
          selectedCandidateFingerprint: selectedCandidateFingerprint,
          projectionFingerprint: projection.projectionFingerprint,
          graphFingerprint: projection.graphFingerprint,
          placementFingerprint: projection.placementFingerprint,
          normativeEvidenceFingerprint: normativeFingerprint,
          normativeProfileId: normativeEvidence.normativeProfileId,
          normativeProfileVersion: normativeEvidence.normativeProfileVersion,
          requirements: requirements,
        ),
      );
    } catch (error) {
      return ApartmentEngineeringRequirementsResult(
        requirements: null,
        failures: [
          P9Failure(
            code: 'INTERNAL_GENERATION_ERROR',
            stage: P9FailureStage.materialization,
            severity: P9FailureSeverity.blocker,
            facts: {
              'reason': 'selected-winner-requirements-derivation-failed',
              'candidateFingerprint': selectedCandidateFingerprint,
              'projectionFingerprint': projection.projectionFingerprint,
              'errorType': error.runtimeType.toString(),
            },
          ),
        ],
      );
    }
  }
}

ApartmentEngineeringRequirement _unresolvedRequirement({
  required ApartmentEngineeringRequirementDomain domain,
  required ApartmentEngineeringRequirementCriticality criticality,
  required String subjectStableId,
  required String projectionFingerprint,
  required String normativeEvidenceFingerprint,
  required String rationaleCode,
  required List<String> requiredFactKeys,
}) {
  final identitySerialization = p9CanonicalSerializeFields([
    MapEntry('version', apartmentEngineeringRequirementsVersion),
    MapEntry('projection', projectionFingerprint),
    MapEntry('normative', normativeEvidenceFingerprint),
    MapEntry('domain', domain.name),
    MapEntry('subject', subjectStableId),
    MapEntry('rationale', rationaleCode),
  ]);
  final requirementId =
      'req-${p9Sha256Hex(identitySerialization).substring(0, 24)}';
  return ApartmentEngineeringRequirement(
    requirementId: requirementId,
    domain: domain,
    subjectKind: ApartmentEngineeringRequirementSubjectKind.projection,
    subjectStableId: subjectStableId,
    evidenceState: ApartmentEngineeringRequirementEvidenceState.notEvaluated,
    criticality: criticality,
    rationaleCode: rationaleCode,
    requiredFactKeys: requiredFactKeys,
  );
}

P9Failure? _lineageFailure({
  required String selectedCandidateFingerprint,
  required ApartmentEngineeringProjection projection,
  required ApartmentNormativeEvidenceBundle normativeEvidence,
}) {
  final mismatches = <String>[];
  if (selectedCandidateFingerprint.trim().isEmpty) {
    mismatches.add('selectedCandidateFingerprint.empty');
  }
  if (projection.projectionVersion != apartmentProjectionVersion) {
    mismatches.add('projection.version');
  }
  if (projection.selectedCandidateFingerprint != selectedCandidateFingerprint) {
    mismatches.add('projection.candidate');
  }
  if (normativeEvidence.evaluationVersion !=
      apartmentNormativeEvaluationVersion) {
    mismatches.add('normative.version');
  }
  if (normativeEvidence.selectedCandidateFingerprint !=
      selectedCandidateFingerprint) {
    mismatches.add('normative.candidate');
  }
  if (normativeEvidence.projectionFingerprint !=
      projection.projectionFingerprint) {
    mismatches.add('normative.projection');
  }
  if (projection.graphFingerprint.trim().isEmpty ||
      projection.placementFingerprint.trim().isEmpty ||
      projection.projectionFingerprint.trim().isEmpty ||
      normativeEvidence.evidenceFingerprint.trim().isEmpty) {
    mismatches.add('fingerprint.empty');
  }
  if (mismatches.isEmpty) {
    return null;
  }
  return P9Failure(
    code: 'INTERNAL_GENERATION_ERROR',
    stage: P9FailureStage.materialization,
    severity: P9FailureSeverity.blocker,
    facts: {
      'reason': 'selected-winner-requirements-lineage-mismatch',
      'mismatches': mismatches.join(','),
      'candidateFingerprint': selectedCandidateFingerprint,
      'projectionFingerprint': projection.projectionFingerprint,
      'normativeEvidenceFingerprint': normativeEvidence.evidenceFingerprint,
    },
  );
}

Map<String, ApartmentEngineeringFactEvidence> _indexFactEvidence(
  Iterable<ApartmentEngineeringFactEvidence> evidence,
) {
  final result = <String, ApartmentEngineeringFactEvidence>{};
  for (final fact in evidence) {
    if (result.containsKey(fact.factKey)) {
      throw ArgumentError('Duplicate P9.5-A fact evidence ${fact.factKey}.');
    }
    result[fact.factKey] = fact;
  }
  final entries = result.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return Map.unmodifiable(Map.fromEntries(entries));
}

void _validateTypedValue({
  required ApartmentEngineeringFactValueKind valueKind,
  required Object value,
}) {
  final valid = switch (valueKind) {
    ApartmentEngineeringFactValueKind.integer => value is int,
    ApartmentEngineeringFactValueKind.decimal =>
      value is double && value.isFinite,
    ApartmentEngineeringFactValueKind.booleanValue => value is bool,
    ApartmentEngineeringFactValueKind.text =>
      value is String && value.trim().isNotEmpty,
  };
  if (!valid) {
    throw ArgumentError(
      'P9.5-A fact value does not match declared kind ${valueKind.name}.',
    );
  }
}
