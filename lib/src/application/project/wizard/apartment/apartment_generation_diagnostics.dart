import '../../../../domain/apartment_topology/apartment_topology_catalog.dart';
import '../../../../domain/apartment_topology/apartment_topology_catalog_production.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import 'apartment_area_fitter.dart';
import 'apartment_catalog_filter.dart';
import 'apartment_geometry_stage.dart';
import 'apartment_semantic_validator.dart';
import 'apartment_topology_grammar.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_failure.dart';

enum ApartmentGenerationDiagnosticStage {
  area,
  semantic,
  geometry,
  accepted,
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
    this.geometryFingerprint,
  }) : codes = List.unmodifiable(codes.toSet().toList()..sort());

  final String templateId;
  final int templateVersion;
  final ApartmentTopologyFamily family;
  final String variantSeedId;
  final String draftFingerprint;
  final ApartmentGenerationDiagnosticStage stage;
  final List<String> codes;
  final String? geometryFingerprint;

  bool get accepted => stage == ApartmentGenerationDiagnosticStage.accepted;

  String get stableLine => <String>[
        '${templateId}@${templateVersion}',
        family.code,
        variantSeedId,
        draftFingerprint,
        stage.name,
        if (codes.isNotEmpty) codes.join(','),
        if (geometryFingerprint != null) geometryFingerprint!,
      ].join('|');
}

final class ApartmentGenerationDiagnosticReport {
  ApartmentGenerationDiagnosticReport({
    required this.catalogVersion,
    required this.intentFingerprint,
    required Iterable<P9Failure> grammarFailures,
    required Iterable<ApartmentGenerationDiagnosticEntry> entries,
  })  : grammarFailures = List.unmodifiable(grammarFailures),
        entries = List.unmodifiable(entries);

  final int catalogVersion;
  final String intentFingerprint;
  final List<P9Failure> grammarFailures;
  final List<ApartmentGenerationDiagnosticEntry> entries;

  List<ApartmentGenerationDiagnosticEntry> get acceptedEntries =>
      List.unmodifiable(entries.where((entry) => entry.accepted));

  bool get hasAcceptedCandidate => acceptedEntries.isNotEmpty;

  String get stableSummary {
    final grammarCodes = grammarFailures.map((failure) => failure.code).toSet()
      ..removeWhere((code) => code.isEmpty);
    final sortedGrammarCodes = grammarCodes.toList()..sort();
    return <String>[
      'catalogVersion=$catalogVersion',
      'intent=$intentFingerprint',
      if (sortedGrammarCodes.isNotEmpty)
        'grammar=${sortedGrammarCodes.join(',')}',
      for (final entry in entries) entry.stableLine,
    ].join('\n');
  }
}

/// Deterministic diagnostic traversal for the P9.2 -> P9.6 pipeline.
///
/// This service is intentionally side-effect free and allocates no canonical
/// project IDs. It exists so qualification and future Wizard diagnostics can
/// explain why every generated draft was accepted or rejected instead of
/// collapsing the pipeline to a final `null` candidate.
final class ApartmentGenerationDiagnostics {
  const ApartmentGenerationDiagnostics();

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

    entries.sort((left, right) => left.stableLine.compareTo(right.stableLine));
    return ApartmentGenerationDiagnosticReport(
      catalogVersion: effectiveCatalog.catalogVersion,
      intentFingerprint: request.intentFingerprint,
      grammarFailures: expansion.failures,
      entries: entries,
    );
  }

  ApartmentGenerationDiagnosticEntry _entry({
    required dynamic draft,
    required ApartmentTopologyTemplate template,
    required ApartmentGenerationDiagnosticStage stage,
    required Iterable<String> codes,
    String? geometryFingerprint,
  }) =>
      ApartmentGenerationDiagnosticEntry(
        templateId: template.templateId.value,
        templateVersion: template.templateVersion,
        family: template.family,
        variantSeedId: draft.variantSeedId as String,
        draftFingerprint: draft.draftFingerprint as String,
        stage: stage,
        codes: codes,
        geometryFingerprint: geometryFingerprint,
      );
}
