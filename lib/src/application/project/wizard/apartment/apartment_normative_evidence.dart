import '../../../../domain/engineering_graph.dart';
import '../../../../domain/installation_guides.dart';
import '../../../../engine/kz_installation_rules.dart';
import 'apartment_canonical_projection.dart';
import 'apartment_generation_diagnostics.dart';
import 'p9_failure.dart';
import 'p9_sha256.dart';

const String apartmentNormativeEvaluationVersion = 'p9.normative.v1';
const String apartmentNormativeProfileId = 'kz.residential.sp404106';
const String apartmentNormativeProfileVersion = '2013-p9.v1';

/// P9 eligibility metadata around one result produced by the existing
/// normative rules engine. The rule result remains authoritative; this wrapper
/// only declares whether an indeterminate result is safety-critical for
/// unattended generation.
final class ApartmentNormativeAssertion {
  ApartmentNormativeAssertion({
    required this.result,
    required this.safetyCritical,
  }) {
    if (result.ruleId.trim().isEmpty) {
      throw ArgumentError.value(
        result.ruleId,
        'result.ruleId',
        'Normative rule identity must be non-empty.',
      );
    }
    final source = result.source;
    final evidence = result.evidence;
    if (source == null || evidence == null) {
      throw ArgumentError(
        'P9 normative assertions require reproducible source evidence.',
      );
    }
    if (!source.isRevisionPinned || !evidence.source.isRevisionPinned) {
      throw ArgumentError(
        'P9 normative evidence cannot use an unpinned source revision.',
      );
    }
  }

  final InstallationRuleResult result;
  final bool safetyCritical;

  bool get blocksEligibility =>
      result.kind == InstallationRuleResultKind.fail ||
      (safetyCritical &&
          result.kind == InstallationRuleResultKind.indeterminate);

  String get stableSerialization {
    final source = result.source!;
    final evidence = result.evidence!;
    final facts = [...evidence.facts]..sort();
    return <String>[
      'rule=${result.ruleId}',
      'kind=${result.kind.name}',
      'safetyCritical=$safetyCritical',
      'applicability=${evidence.applicability.name}',
      'sourceCode=${source.code}',
      'sourceRevision=${source.revision}',
      'sourceClause=${source.clause ?? '-'}',
      'sourceEffectiveFrom=${source.effectiveFrom ?? '-'}',
      'sourceUri=${source.sourceUri ?? '-'}',
      'sourceAuthority=${source.authority.name}',
      'facts=${facts.join(',')}',
      'rationale=${evidence.rationale}',
    ].join('|');
  }
}

/// Immutable P9.4 overlay bound to one exact P9.3 canonical projection.
///
/// The bundle never owns or rewrites graph/placement state. Normative profile
/// changes therefore change only [evidenceFingerprint], while the source P9.3
/// graph and placement fingerprints remain untouched.
final class ApartmentNormativeEvidenceBundle {
  ApartmentNormativeEvidenceBundle({
    required this.evaluationVersion,
    required this.normativeProfileId,
    required this.normativeProfileVersion,
    required this.selectedCandidateFingerprint,
    required this.projectionFingerprint,
    required Iterable<ApartmentNormativeAssertion> assertions,
  }) : assertions = List.unmodifiable(
          assertions.toList()
            ..sort(
              (left, right) =>
                  left.result.ruleId.compareTo(right.result.ruleId),
            ),
        ) {
    if (evaluationVersion.trim().isEmpty ||
        normativeProfileId.trim().isEmpty ||
        normativeProfileVersion.trim().isEmpty ||
        selectedCandidateFingerprint.trim().isEmpty ||
        projectionFingerprint.trim().isEmpty) {
      throw ArgumentError(
        'P9 normative evidence identity/version fields must be non-empty.',
      );
    }
    if (this.assertions.isEmpty) {
      throw ArgumentError('P9 normative evidence must contain assertions.');
    }
    final ruleIds = <String>{};
    for (final assertion in this.assertions) {
      if (!ruleIds.add(assertion.result.ruleId)) {
        throw ArgumentError(
          'Duplicate normative rule ${assertion.result.ruleId}.',
        );
      }
    }
  }

  final String evaluationVersion;
  final String normativeProfileId;
  final String normativeProfileVersion;
  final String selectedCandidateFingerprint;
  final String projectionFingerprint;
  final List<ApartmentNormativeAssertion> assertions;

  bool get blocksEligibility =>
      assertions.any((assertion) => assertion.blocksEligibility);

  InstallationRuleResultKind get overallState {
    if (assertions.any(
      (assertion) => assertion.result.kind == InstallationRuleResultKind.fail,
    )) {
      return InstallationRuleResultKind.fail;
    }
    if (assertions.any(
      (assertion) =>
          assertion.result.kind == InstallationRuleResultKind.indeterminate,
    )) {
      return InstallationRuleResultKind.indeterminate;
    }
    if (assertions.any(
      (assertion) => assertion.result.kind == InstallationRuleResultKind.pass,
    )) {
      return InstallationRuleResultKind.pass;
    }
    return InstallationRuleResultKind.notApplicable;
  }

  String get stableSerialization => <String>[
        'evaluationVersion=$evaluationVersion',
        'profile=$normativeProfileId@$normativeProfileVersion',
        'candidate=$selectedCandidateFingerprint',
        'projection=$projectionFingerprint',
        for (final assertion in assertions) assertion.stableSerialization,
      ].join('\n');

  String get evidenceFingerprint => p9Sha256Hex(stableSerialization);
}

final class ApartmentNormativeEvidenceEvaluationResult {
  ApartmentNormativeEvidenceEvaluationResult({
    required this.evidence,
    Iterable<P9Failure> failures = const [],
  }) : failures = List.unmodifiable(failures);

  final ApartmentNormativeEvidenceBundle? evidence;
  final List<P9Failure> failures;

  bool get accepted =>
      evidence != null &&
      !evidence!.blocksEligibility &&
      failures.every((failure) => !failure.isBlocker);
}

/// P9.4 Kazakhstan residential normative overlay.
///
/// P9.3 currently produces spatial architecture only. Device-specific rules are
/// therefore evaluated as explicit NOT_APPLICABLE, never as PASS and never as
/// missing-data INDETERMINATE. Once a later stage provides actual electrical
/// targets and facts, this evaluator must be versioned and those targets must be
/// evaluated through [KzInstallationRules] rather than inferred from absence.
final class ApartmentNormativeEvidenceEvaluator {
  const ApartmentNormativeEvidenceEvaluator();

  ApartmentNormativeEvidenceEvaluationResult evaluate({
    required ApartmentEngineeringProjection projection,
  }) {
    final nonSpatialComponents = projection.graph.components
        .where(
          (component) =>
              component.discipline != EngineeringDiscipline.architecture,
        )
        .toList();
    if (nonSpatialComponents.isNotEmpty) {
      return ApartmentNormativeEvidenceEvaluationResult(
        evidence: null,
        failures: [
          P9Failure(
            code: 'NORMATIVE_BLOCKED',
            stage: P9FailureStage.normative,
            severity: P9FailureSeverity.blocker,
            facts: {
              'reason': 'p9-normative-v1-requires-spatial-only-projection',
              'projectionFingerprint': projection.projectionFingerprint,
              'nonSpatialComponentCount': nonSpatialComponents.length,
            },
          ),
        ],
      );
    }

    const noDeviceTargetRationale =
        'P9.3 projection contains spatial architecture only; '
        'no installation-device target exists for this rule.';
    const noDeviceTargetFacts = <String>[
      'applicableTargetCount=0',
      'projectionScope=spatialArchitectureOnly',
    ];

    final assertions = <ApartmentNormativeAssertion>[
      ApartmentNormativeAssertion(
        result: KzInstallationRules.residentialSocketHeightNotApplicable(
          rationale: noDeviceTargetRationale,
          facts: noDeviceTargetFacts,
        ),
        safetyCritical: true,
      ),
      ApartmentNormativeAssertion(
        result: KzInstallationRules.generalLightingSwitchHeightNotApplicable(
          rationale: noDeviceTargetRationale,
          facts: noDeviceTargetFacts,
        ),
        safetyCritical: true,
      ),
      ApartmentNormativeAssertion(
        result: KzInstallationRules.gasPipeDistanceNotApplicable(
          rationale: noDeviceTargetRationale,
          facts: noDeviceTargetFacts,
        ),
        safetyCritical: true,
      ),
      ApartmentNormativeAssertion(
        result: KzInstallationRules.validateChildOccupancyHeight(
          null,
          childOccupancyConfirmed: false,
        ),
        safetyCritical: true,
      ),
    ];

    final evidence = ApartmentNormativeEvidenceBundle(
      evaluationVersion: apartmentNormativeEvaluationVersion,
      normativeProfileId: apartmentNormativeProfileId,
      normativeProfileVersion: apartmentNormativeProfileVersion,
      selectedCandidateFingerprint: projection.selectedCandidateFingerprint,
      projectionFingerprint: projection.projectionFingerprint,
      assertions: assertions,
    );
    return ApartmentNormativeEvidenceEvaluationResult(evidence: evidence);
  }
}

extension ApartmentNormativeDiagnosticsOverlay
    on ApartmentGenerationDiagnosticReport {
  ApartmentGenerationDiagnosticReport withNormativeEvidence(
    ApartmentNormativeEvidenceBundle evidence,
  ) {
    var matchedSelected = 0;
    final normativeState = _diagnosticState(evidence.overallState);
    final updatedEntries = <ApartmentGenerationDiagnosticEntry>[
      for (final entry in entries)
        if (entry.selected &&
            entry.candidateFingerprint == evidence.selectedCandidateFingerprint)
          (() {
            matchedSelected++;
            return entry.copyWith(normativeState: normativeState);
          })()
        else
          entry,
    ];
    if (matchedSelected != 1) {
      throw StateError(
        'P9.4 evidence must bind exactly one selected diagnostic entry; '
        'matched=$matchedSelected.',
      );
    }
    return ApartmentGenerationDiagnosticReport(
      catalogVersion: catalogVersion,
      intentFingerprint: intentFingerprint,
      generatorVersion: generatorVersion,
      diagnosticsVersion: diagnosticsVersion,
      grammarFailures: grammarFailures,
      globalFailures: globalFailures,
      entries: updatedEntries,
    );
  }
}

ApartmentDiagnosticEvidenceState _diagnosticState(
  InstallationRuleResultKind kind,
) =>
    switch (kind) {
      InstallationRuleResultKind.pass => ApartmentDiagnosticEvidenceState.pass,
      InstallationRuleResultKind.fail => ApartmentDiagnosticEvidenceState.fail,
      InstallationRuleResultKind.notApplicable =>
        ApartmentDiagnosticEvidenceState.notApplicable,
      InstallationRuleResultKind.indeterminate =>
        ApartmentDiagnosticEvidenceState.indeterminate,
    };
