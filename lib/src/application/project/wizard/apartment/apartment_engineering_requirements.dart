import 'apartment_canonical_projection.dart';
import 'apartment_normative_evidence.dart';
import 'p9_failure.dart';
import 'p9_sha256.dart';

const String apartmentEngineeringRequirementsVersion = 'p9.requirements.v1';

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
    Map<String, String> establishedFacts = const {},
  })  : requiredFactKeys = List.unmodifiable(
          requiredFactKeys.toSet().toList()..sort(),
        ),
        establishedFacts = Map.unmodifiable(
          Map.fromEntries(
            establishedFacts.entries.toList()
              ..sort((left, right) => left.key.compareTo(right.key)),
          ),
        ) {
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
    if (this.establishedFacts.keys.any((key) => key.trim().isEmpty)) {
      throw ArgumentError(
        'P9.5-A established fact keys must be non-empty.',
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
  final Map<String, String> establishedFacts;

  bool get isResolved =>
      evidenceState == ApartmentEngineeringRequirementEvidenceState.proven ||
      evidenceState ==
          ApartmentEngineeringRequirementEvidenceState.notApplicable;

  bool get blocksEquipmentConfiguration =>
      !isResolved &&
      criticality != ApartmentEngineeringRequirementCriticality.advisory;

  String get stableSerialization => <String>[
        'id=$requirementId',
        'domain=${domain.name}',
        'subjectKind=${subjectKind.name}',
        'subject=$subjectStableId',
        'state=${evidenceState.name}',
        'criticality=${criticality.name}',
        'rationale=$rationaleCode',
        'requiredFacts=${requiredFactKeys.join(',')}',
        'establishedFacts=${establishedFacts.entries.map((entry) => '${entry.key}=${entry.value}').join(',')}',
      ].join('|');
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

  String get stableSerialization => <String>[
        'requirementsVersion=$requirementsVersion',
        'candidate=$selectedCandidateFingerprint',
        'projection=$projectionFingerprint',
        'graph=$graphFingerprint',
        'placement=$placementFingerprint',
        'normative=$normativeEvidenceFingerprint',
        'normativeProfile=$normativeProfileId@$normativeProfileVersion',
        for (final requirement in requirements)
          requirement.stableSerialization,
      ].join('\n');

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
  final requirementId = 'req-${p9Sha256Hex(<String>[
        apartmentEngineeringRequirementsVersion,
        'projection=$projectionFingerprint',
        'normative=$normativeEvidenceFingerprint',
        'domain=${domain.name}',
        'subject=$subjectStableId',
        'rationale=$rationaleCode',
      ].join('|')).substring(0, 24)}';
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
