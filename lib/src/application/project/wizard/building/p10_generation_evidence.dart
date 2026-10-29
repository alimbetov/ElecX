import '../../composition_provenance_command.dart';
import 'building_generation_parameters.dart';
import 'building_template_catalog.dart';

CompositionGenerationEvidence p10GenerationEvidence(String version,
    String fingerprint, Map<String, BuildingGenerationParameters> parameters,
    {String? canonicalRequest}) {
  final templates = <String, Object?>{};
  for (final e in parameters.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key))) {
    if (e.value.template == null) continue;
    final binding = BuildingTemplateCatalog.residentialV1().bind(e.value);
    templates[e.key] = {
      'id': binding.reference.id.value,
      'version': binding.reference.templateVersion,
      'catalogVersion': binding.reference.catalogVersion,
      'fingerprint': binding.templateFingerprint
    };
  }
  return CompositionGenerationEvidence(
      canonicalRequest: canonicalRequest,
      generatorVersion: version,
      candidateFingerprint: fingerprint,
      templates: templates);
}
