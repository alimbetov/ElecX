import '../../../../domain/project_aggregate.dart';
import '../../project_mutation_reservation.dart';
import '../wizard_diff.dart';

/// UI-neutral P10 preview projection built exclusively from the frozen reserved
/// candidate and the canonical semantic diff. No provider pipeline is rerun.
final class BuildingCompositionWizardPreview {
  const BuildingCompositionWizardPreview({
    required this.diff,
    required this.addedBuildings,
    required this.addedLevels,
    required this.addedStructuralZones,
    required this.addedSpaces,
    required this.addedOpenings,
    required this.addedVerticalCores,
    required this.addedServiceAnchors,
  });

  final WizardDiffModel diff;
  final int addedBuildings;
  final int addedLevels;
  final int addedStructuralZones;
  final int addedSpaces;
  final int addedOpenings;
  final int addedVerticalCores;
  final int addedServiceAnchors;

  int get addedCanonicalEntities =>
      addedBuildings +
      addedLevels +
      addedStructuralZones +
      addedSpaces +
      addedOpenings +
      addedVerticalCores +
      addedServiceAnchors;
}

final class BuildingCompositionWizardPreviewProjector {
  const BuildingCompositionWizardPreviewProjector();

  BuildingCompositionWizardPreview project({
    required ProjectAggregateRoot before,
    required ReservedProjectMutationPreview preview,
  }) {
    final candidate = preview.candidate;
    int added<K, V>(Map<K, V> left, Map<K, V> right) =>
        right.keys.where((key) => !left.containsKey(key)).length;

    final beforeAnchors = before.engineeringMetadata.siteLayout.serviceAnchors;
    final candidateAnchors =
        candidate.engineeringMetadata.siteLayout.serviceAnchors;
    return BuildingCompositionWizardPreview(
      diff: const WizardDiffProjector().project(
        before: before,
        preview: preview,
      ),
      addedBuildings:
          added(before.stores.buildings, candidate.stores.buildings),
      addedLevels: added(before.stores.levels, candidate.stores.levels),
      addedStructuralZones: added(before.stores.zones, candidate.stores.zones),
      addedSpaces: added(before.stores.spaces, candidate.stores.spaces),
      addedOpenings: added(before.stores.openings, candidate.stores.openings),
      addedVerticalCores:
          added(before.stores.verticalCores, candidate.stores.verticalCores),
      addedServiceAnchors: added(beforeAnchors, candidateAnchors),
    );
  }
}
