import '../../../../domain/apartment_topology.dart';
import '../../../../domain/apartment_topology/apartment_candidate_ranking.dart';
import '../../../../domain/apartment_topology/apartment_topology_catalog.dart';
import '../../../../domain/apartment_topology/apartment_topology_catalog_production.dart';
import '../../../../domain/apartment_topology/apartment_topology_draft.dart';
import '../../../../domain/apartment_topology/apartment_topology_generation_runtime.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import 'apartment_area_fitter.dart';
import 'apartment_catalog_filter.dart';
import 'apartment_geometry_stage.dart';
import 'apartment_semantic_validator.dart';
import 'apartment_topology_grammar.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_failure.dart';
import 'p9_sha256.dart';

const String apartmentDiagnosticsVersion = 'p9.diagnostics.v1';

enum ApartmentGenerationDiagnosticStage {
  area,
  semantic,
  geometry,
  accepted,
  scoring,
  selection,
}

enum ApartmentCandidateDiagnosticStatus {
  rejected,
  eligible,
  selected,
  notSelected,
}

/// P9.4/P9.5 are not part of the P9.2 production increment yet.
///
/// Keeping an explicit state prevents diagnostics from fabricating PASS for a
/// validation domain that the current production execution did not evaluate.
enum ApartmentDiagnosticEvidenceState {
  notEvaluated,
  pass,
  fail,
  notApplicable,
  indeterminate,
}

final class ApartmentGenerationDiagnosticEntry {
  ApartmentGenerationDiagnosticEntry({
    required this.templateId,
    required this.templateVersion,
    required this.family,
    required this.variantSeedId,
    required this.draftFingerprint,
    required this.stage,
    required Iterable<String> codes,
    ApartmentCandidateDiagnosticStatus? status,
    Iterable<String> blockerCodes = const [],
    Iterable<String> warningCodes = const [],
    this.geometryFingerprint,
    this.candidateFingerprint,
    this.scoreBreakdown,
    this.rank,
    this.rationaleCode,
    this.normativeState = ApartmentDiagnosticEvidenceState.notEvaluated,
    this.equipmentState = ApartmentDiagnosticEvidenceState.notEvaluated,
  })  : codes = List.unmodifiable(_orderedCodes(codes)),
        status = status ??
            (stage == ApartmentGenerationDiagnosticStage.accepted
                ? ApartmentCandidateDiagnosticStatus.eligible
                : ApartmentCandidateDiagnosticStatus.rejected),
        blockerCodes = List.unmodifiable(_orderedCodes(blockerCodes)),
        warningCodes = List.unmodifiable(_orderedCodes(warningCodes)) {
    if (templateId.trim().isEmpty) {
      throw ArgumentError.value(
        templateId,
        'templateId',
        'Template identity must be non-empty.',
      );
    }
    if (templateVersion <= 0) {
      throw ArgumentError.value(
        templateVersion,
        'templateVersion',
        'Template version must be positive.',
      );
    }
    if (draftFingerprint.trim().isEmpty) {
      throw ArgumentError.value(
        draftFingerprint,
        'draftFingerprint',
        'Draft fingerprint must be non-empty.',
      );
    }
    if (rank != null && rank! <= 0) {
      throw ArgumentError.value(rank, 'rank', 'Rank must be positive.');
    }
    if (this.status == ApartmentCandidateDiagnosticStatus.selected &&
        this.blockerCodes.isNotEmpty) {
      throw ArgumentError(
        'A selected P9 candidate cannot carry blocking reasons.',
      );
    }
  }

  final String templateId;
  final int templateVersion;
  final ApartmentTopologyFamily family;
  final String variantSeedId;
  final String draftFingerprint;
  final ApartmentGenerationDiagnosticStage stage;

  /// Compatibility view retained for the pre-P9.2 inspector.
  final List<String> codes;

  final ApartmentCandidateDiagnosticStatus status;
  final List<String> blockerCodes;
  final List<String> warningCodes;
  final String? geometryFingerprint;
  final String? candidateFingerprint;
  final ApartmentScoreBreakdown? scoreBreakdown;
  final int? rank;
  final String? rationaleCode;
  final ApartmentDiagnosticEvidenceState normativeState;
  final ApartmentDiagnosticEvidenceState equipmentState;

  bool get accepted => stage == ApartmentGenerationDiagnosticStage.accepted;
  bool get selected => status == ApartmentCandidateDiagnosticStatus.selected;
  bool get rejected => status == ApartmentCandidateDiagnosticStatus.rejected;
  bool get eligible =>
      status == ApartmentCandidateDiagnosticStatus.eligible ||
      status == ApartmentCandidateDiagnosticStatus.selected ||
      status == ApartmentCandidateDiagnosticStatus.notSelected;

  String get stableIdentity => <String>[
        '$templateId@$templateVersion',
        family.code,
        variantSeedId,
        draftFingerprint,
      ].join('|');

  String get stableLine => <String>[
        stableIdentity,
        'stage=${stage.name}',
        'status=${status.name}',
        if (blockerCodes.isNotEmpty) 'blockers=${blockerCodes.join(',')}',
        if (warningCodes.isNotEmpty) 'warnings=${warningCodes.join(',')}',
        if (codes.isNotEmpty) 'codes=${codes.join(',')}',
        if (geometryFingerprint != null) 'geometry=$geometryFingerprint',
        if (candidateFingerprint != null) 'candidate=$candidateFingerprint',
        if (scoreBreakdown != null) ..._scoreStableLines(scoreBreakdown!),
        if (rank != null) 'rank=$rank',
        if (rationaleCode != null) 'rationale=$rationaleCode',
        'normative=${normativeState.name}',
        'equipment=${equipmentState.name}',
      ].join('|');

  ApartmentGenerationDiagnosticEntry copyWith({
    ApartmentGenerationDiagnosticStage? stage,
    ApartmentCandidateDiagnosticStatus? status,
    Iterable<String>? codes,
    Iterable<String>? blockerCodes,
    Iterable<String>? warningCodes,
    String? geometryFingerprint,
    String? candidateFingerprint,
    ApartmentScoreBreakdown? scoreBreakdown,
    int? rank,
    String? rationaleCode,
    ApartmentDiagnosticEvidenceState? normativeState,
    ApartmentDiagnosticEvidenceState? equipmentState,
  }) =>
      ApartmentGenerationDiagnosticEntry(
        templateId: templateId,
        templateVersion: templateVersion,
        family: family,
        variantSeedId: variantSeedId,
        draftFingerprint: draftFingerprint,
        stage: stage ?? this.stage,
        codes: codes ?? this.codes,
        status: status ?? this.status,
        blockerCodes: blockerCodes ?? this.blockerCodes,
        warningCodes: warningCodes ?? this.warningCodes,
        geometryFingerprint: geometryFingerprint ?? this.geometryFingerprint,
        candidateFingerprint: candidateFingerprint ?? this.candidateFingerprint,
        scoreBreakdown: scoreBreakdown ?? this.scoreBreakdown,
        rank: rank ?? this.rank,
        rationaleCode: rationaleCode ?? this.rationaleCode,
        normativeState: normativeState ?? this.normativeState,
        equipmentState: equipmentState ?? this.equipmentState,
      );
}

/// Candidate lineage captured by the production execution before ranking.
///
/// This is an execution trace, not a second topology/candidate domain model.
final class ApartmentGenerationDiagnosticSeed {
  ApartmentGenerationDiagnosticSeed({
    required this.templateId,
    required this.templateVersion,
    required this.family,
    required this.variantSeedId,
    required this.draftFingerprint,
    required this.geometryFingerprint,
    required this.areaFitFingerprint,
    Iterable<String> warningCodes = const [],
  }) : warningCodes = List.unmodifiable(_orderedCodes(warningCodes));

  final String templateId;
  final int templateVersion;
  final ApartmentTopologyFamily family;
  final String variantSeedId;
  final String draftFingerprint;
  final String geometryFingerprint;
  final String areaFitFingerprint;
  final List<String> warningCodes;

  String get exactRankingKey => '$areaFitFingerprint|$geometryFingerprint';

  bool matches(RankedApartmentCandidate candidate) =>
      templateId == candidate.candidate.templateId.value &&
      templateVersion == candidate.candidate.templateVersion &&
      variantSeedId == candidate.candidate.variantSeedId &&
      geometryFingerprint == candidate.candidate.geometryFingerprint &&
      areaFitFingerprint == candidate.candidate.areaFitFingerprint;

  ApartmentGenerationDiagnosticEntry toEntry({
    required ApartmentGenerationDiagnosticStage stage,
    required ApartmentCandidateDiagnosticStatus status,
    Iterable<String> blockerCodes = const [],
    ApartmentScoreBreakdown? scoreBreakdown,
    int? rank,
    String? rationaleCode,
    String? candidateFingerprint,
  }) =>
      ApartmentGenerationDiagnosticEntry(
        templateId: templateId,
        templateVersion: templateVersion,
        family: family,
        variantSeedId: variantSeedId,
        draftFingerprint: draftFingerprint,
        stage: stage,
        codes: blockerCodes,
        status: status,
        blockerCodes: blockerCodes,
        warningCodes: warningCodes,
        geometryFingerprint: geometryFingerprint,
        candidateFingerprint: candidateFingerprint,
        scoreBreakdown: scoreBreakdown,
        rank: rank,
        rationaleCode: rationaleCode,
      );
}

final class ApartmentGenerationDiagnosticReport {
  ApartmentGenerationDiagnosticReport({
    required this.catalogVersion,
    required this.intentFingerprint,
    required Iterable<P9Failure> grammarFailures,
    required Iterable<ApartmentGenerationDiagnosticEntry> entries,
    this.generatorVersion,
    this.diagnosticsVersion = apartmentDiagnosticsVersion,
    Iterable<P9Failure> globalFailures = const [],
  })  : grammarFailures = List.unmodifiable(grammarFailures),
        globalFailures = List.unmodifiable(globalFailures),
        entries = List.unmodifiable(
          entries.toList()
            ..sort((left, right) => left.stableLine.compareTo(right.stableLine)),
        );

  final int catalogVersion;
  final String intentFingerprint;
  final String? generatorVersion;
  final String diagnosticsVersion;
  final List<P9Failure> grammarFailures;
  final List<P9Failure> globalFailures;
  final List<ApartmentGenerationDiagnosticEntry> entries;

  List<ApartmentGenerationDiagnosticEntry> get acceptedEntries =>
      List.unmodifiable(entries.where((entry) => entry.accepted));

  List<ApartmentGenerationDiagnosticEntry> get selectedEntries =>
      List.unmodifiable(entries.where((entry) => entry.selected));

  List<ApartmentGenerationDiagnosticEntry> get rejectedEntries =>
      List.unmodifiable(entries.where((entry) => entry.rejected));

  bool get hasAcceptedCandidate => acceptedEntries.isNotEmpty;
  bool get hasSelectedCandidate => selectedEntries.isNotEmpty;

  String get stableSummary {
    final grammarCodes = grammarFailures.map((failure) => failure.code).toSet()
      ..removeWhere((code) => code.isEmpty);
    final sortedGrammarCodes = grammarCodes.toList()..sort();
    final failureCodes = globalFailures.map((failure) => failure.code).toSet()
      ..removeWhere((code) => code.isEmpty);
    final sortedFailureCodes = failureCodes.toList()..sort();
    return <String>[
      'diagnosticsVersion=$diagnosticsVersion',
      if (generatorVersion != null) 'generatorVersion=$generatorVersion',
      'catalogVersion=$catalogVersion',
      'intent=$intentFingerprint',
      if (sortedGrammarCodes.isNotEmpty)
        'grammar=${sortedGrammarCodes.join(',')}',
      if (sortedFailureCodes.isNotEmpty)
        'failures=${sortedFailureCodes.join(',')}',
      for (final entry in entries) entry.stableLine,
    ].join('\n');
  }

  String get diagnosticsFingerprint => p9Sha256Hex(stableSummary);
}

/// Deterministic P9.2 diagnostics assembler.
///
/// [inspect] remains as a compatibility/debug traversal. Production code must
/// use [fromProductionSelection], passing the exact P9.1 evaluations generated
/// by the authoritative execution rather than recomputing candidate validity.
final class ApartmentGenerationDiagnostics {
  const ApartmentGenerationDiagnostics();

  ApartmentGenerationDiagnosticReport fromProductionSelection({
    required int catalogVersion,
    required String generatorVersion,
    required String intentFingerprint,
    required Iterable<P9Failure> grammarFailures,
    required Iterable<P9Failure> globalFailures,
    required Iterable<ApartmentGenerationDiagnosticEntry> terminalEntries,
    required Iterable<ApartmentGenerationDiagnosticSeed> seeds,
    required Iterable<ApartmentTopologyCandidateEvaluation> evaluations,
    String? selectedGeometryFingerprint,
    Map<String, String> candidateFingerprintsByGeometry = const {},
  }) {
    final entries = <ApartmentGenerationDiagnosticEntry>[
      ...terminalEntries,
    ];
    final remainingSeeds = seeds.toList()
      ..sort((left, right) => left.draftFingerprint.compareTo(right.draftFingerprint));
    final orderedEvaluations = evaluations.toList()
      ..sort((left, right) =>
          ApartmentTopologyGenerationRuntime.compareRankedCandidates(
            left.rankedCandidate,
            right.rankedCandidate,
          ));

    var eligibleRank = 0;
    for (final evaluation in orderedEvaluations) {
      final seedIndex = remainingSeeds.indexWhere(
        (seed) => seed.matches(evaluation.rankedCandidate),
      );
      if (seedIndex < 0) {
        continue;
      }
      final seed = remainingSeeds.removeAt(seedIndex);
      final ranked = evaluation.rankedCandidate;
      final selected = evaluation.isEligible &&
          ranked.candidate.geometryFingerprint == selectedGeometryFingerprint;

      int? rank;
      if (evaluation.isEligible) {
        eligibleRank++;
        rank = eligibleRank;
      }

      final status = !evaluation.isEligible
          ? ApartmentCandidateDiagnosticStatus.rejected
          : selected
              ? ApartmentCandidateDiagnosticStatus.selected
              : ApartmentCandidateDiagnosticStatus.notSelected;
      final rationale = !evaluation.isEligible
          ? 'p9.diagnostics.rejected.ineligible'
          : selected
              ? 'p9.diagnostics.selected.frozen-comparator'
              : 'p9.diagnostics.not-selected.lower-rank';
      final stage = evaluation.isEligible
          ? ApartmentGenerationDiagnosticStage.selection
          : ApartmentGenerationDiagnosticStage.scoring;

      entries.add(
        seed.toEntry(
          stage: stage,
          status: status,
          blockerCodes: evaluation.blockerCodes,
          scoreBreakdown: ranked.breakdown,
          rank: rank,
          rationaleCode: rationale,
          candidateFingerprint: candidateFingerprintsByGeometry[
            ranked.candidate.geometryFingerprint
          ],
        ),
      );
    }

    // P9 ranker suppresses exact duplicates after deterministic ranking. They
    // remain visible in diagnostics instead of silently disappearing.
    for (final seed in remainingSeeds) {
      entries.add(
        seed.toEntry(
          stage: ApartmentGenerationDiagnosticStage.scoring,
          status: ApartmentCandidateDiagnosticStatus.rejected,
          blockerCodes: const ['p9.score.exact-duplicate-suppressed'],
          rationaleCode: 'p9.diagnostics.rejected.exact-duplicate',
        ),
      );
    }

    return ApartmentGenerationDiagnosticReport(
      catalogVersion: catalogVersion,
      intentFingerprint: intentFingerprint,
      generatorVersion: generatorVersion,
      grammarFailures: grammarFailures,
      globalFailures: globalFailures,
      entries: entries,
    );
  }

  ApartmentGenerationDiagnosticReport inspect({
    required NormalizedApartmentRequest request,
    ApartmentTopologyCatalog? catalog,
  }) {
    final effectiveCatalog =
        catalog ?? P9ProductionApartmentTopologyCatalog.create();
    final templates = const ApartmentTopologyCatalogFilter()
        .compatibleTemplates(effectiveCatalog, request);
    final expansion = ApartmentTopologyGrammarEngine().expand(
      request: request,
      templates: templates,
    );
    final entries = <ApartmentGenerationDiagnosticEntry>[];

    for (final draft in expansion.drafts) {
      final template = templates.firstWhere(
        (candidate) =>
            candidate.templateId == draft.templateId &&
            candidate.templateVersion == draft.templateVersion,
      );
      final area = const ApartmentAreaFitter().fit(
        draft: draft,
        request: request,
      );
      if (!area.isValid) {
        entries.add(
          _entry(
            draft: draft,
            template: template,
            stage: ApartmentGenerationDiagnosticStage.area,
            codes: area.failures.map((failure) => failure.code),
          ),
        );
        continue;
      }

      final semantic = const ApartmentSemanticValidator().validate(
        fittedDraft: area.fittedDraft!,
        request: request,
        template: template,
      );
      if (!semantic.accepted) {
        entries.add(
          _entry(
            draft: draft,
            template: template,
            stage: ApartmentGenerationDiagnosticStage.semantic,
            codes: semantic.blockers.map((blocker) => blocker.code),
          ),
        );
        continue;
      }

      final geometry = const ApartmentGeometryStage().generate(
        fittedDraft: area.fittedDraft!,
        semanticValidation: semantic,
        template: template,
        request: request,
      );
      if (!geometry.accepted) {
        entries.add(
          _entry(
            draft: draft,
            template: template,
            stage: ApartmentGenerationDiagnosticStage.geometry,
            codes: [
              ...geometry.failures.map((failure) => failure.code),
              ...?geometry.candidate?.validation.issues
                  .where((issue) => !issue.code.startsWith('info.'))
                  .map((issue) => issue.code),
            ],
            geometryFingerprint: geometry.candidate?.geometryFingerprint,
          ),
        );
        continue;
      }

      entries.add(
        _entry(
          draft: draft,
          template: template,
          stage: ApartmentGenerationDiagnosticStage.accepted,
          codes: const [],
          geometryFingerprint: geometry.candidate!.geometryFingerprint,
        ),
      );
    }

    return ApartmentGenerationDiagnosticReport(
      catalogVersion: effectiveCatalog.catalogVersion,
      intentFingerprint: request.intentFingerprint,
      grammarFailures: expansion.failures,
      entries: entries,
    );
  }

  ApartmentGenerationDiagnosticEntry _entry({
    required ApartmentTopologyDraft draft,
    required ApartmentTopologyTemplate template,
    required ApartmentGenerationDiagnosticStage stage,
    required Iterable<String> codes,
    String? geometryFingerprint,
  }) =>
      ApartmentGenerationDiagnosticEntry(
        templateId: template.templateId.value,
        templateVersion: template.templateVersion,
        family: template.family,
        variantSeedId: draft.variantSeedId,
        draftFingerprint: draft.draftFingerprint,
        stage: stage,
        codes: codes,
        blockerCodes: stage == ApartmentGenerationDiagnosticStage.accepted
            ? const []
            : codes,
        geometryFingerprint: geometryFingerprint,
      );
}

List<String> _orderedCodes(Iterable<String> codes) =>
    (codes.where((code) => code.trim().isNotEmpty).toSet().toList()..sort());

List<String> _scoreStableLines(ApartmentScoreBreakdown breakdown) {
  final metricLines = <String>[];
  for (final metric in ApartmentScoreMetric.values) {
    final score = breakdown.metricScoreBp[metric];
    final contribution = breakdown.weightedContributionBp[metric];
    if (score == null && contribution == null) {
      continue;
    }
    metricLines.add(
      '${metric.name}:${score ?? '-'}:${contribution ?? '-'}',
    );
  }
  return <String>[
    'scoreProfile=${breakdown.scoringProfileVersion}',
    'scoreBp=${breakdown.finalScoreBp}',
    if (metricLines.isNotEmpty) 'metrics=${metricLines.join(',')}',
  ];
}
