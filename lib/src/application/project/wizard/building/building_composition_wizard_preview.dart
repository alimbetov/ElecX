import '../../../../domain/project_aggregate.dart';
import '../../../../domain/project_identity.dart';
import '../../../../domain/project_service_anchor.dart';
import '../../../../domain/project_service_anchor_integrity.dart';
import '../../../../domain/boundary_topology.dart';
import '../wizard_preview_scene.dart';
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
    required this.addedApartments,
    required this.addedSharedAnchors,
    required this.addedCanonicalEntities,
    required this.serviceCounts,
  });

  final WizardDiffModel diff;
  final int addedBuildings;
  final int addedLevels;
  final int addedStructuralZones;
  final int addedSpaces;
  final int addedOpenings;
  final int addedVerticalCores;
  final int addedServiceAnchors;

  final int addedApartments;
  final int addedSharedAnchors;
  final int addedCanonicalEntities;
  final Map<ProjectServiceAnchorKind, int> serviceCounts;
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
    final services = <ProjectServiceAnchorKind, int>{};
    for (final anchor in candidateAnchors.values) {
      if (!beforeAnchors.containsKey(anchor.id)) {
        services.update(anchor.kind, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final shared = added(before.engineeringMetadata.siteLayout.sharedAnchors,
        candidate.engineeringMetadata.siteLayout.sharedAnchors);
    final definitions = added(
        before.engineeringMetadata.generationProvenanceRegistry
            .typicalFloorDefinitions,
        candidate.engineeringMetadata.generationProvenanceRegistry
            .typicalFloorDefinitions);
    return BuildingCompositionWizardPreview(
      addedApartments: candidate.stores.zones.values
          .where((z) =>
              !before.stores.zones.containsKey(z.id) &&
              z.kind == ProjectStructuralZoneKind.apartment)
          .length,
      addedSharedAnchors: shared,
      serviceCounts: Map.unmodifiable(services),
      addedCanonicalEntities: preview.preview.entityDiff.addedEntityIds.length +
          added(beforeAnchors, candidateAnchors) +
          shared +
          definitions,
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

/// Site/floor geometry comes exclusively from the frozen canonical candidate.
final class BuildingCompositionWizardSceneProjector {
  const BuildingCompositionWizardSceneProjector();
  WizardPreviewScene project(ReservedProjectMutationPreview preview,
      {LevelId? levelId}) {
    final project = preview.candidate;
    final polygons = <(EntityId, List<BoundaryPointMm>, String)>[];
    final markers = <(ServiceEntryId, BoundaryPointMm, String)>[];
    if (levelId == null) {
      for (final p
          in project.engineeringMetadata.siteLayout.placements.entries) {
        polygons.add((
          p.key,
          p.value.siteFootprint.vertices,
          project.stores.buildings[p.key]!.name
        ));
      }
      for (final anchor
          in project.engineeringMetadata.siteLayout.serviceAnchors.values) {
        markers.add((
          anchor.id,
          ProjectServiceAnchorResolver.position(project, anchor.id,
                  siteCoordinates: true)
              .point,
          anchor.name
        ));
      }
      for (final anchor
          in project.engineeringMetadata.siteLayout.sharedAnchors.values) {
        markers.add((anchor.id, anchor.point, anchor.name));
      }
    } else {
      final level = project.stores.levels[levelId];
      if (level == null) throw ArgumentError('Unknown preview Level.');
      for (final id in level.spaceIds) {
        final boundary = project.stores.boundaries[id];
        if (boundary != null) {
          polygons.add((
            id,
            [
              for (final edge in boundary.orderedEdgeIds)
                boundary.edges[edge]!.start
            ],
            project.stores.spaces[id]!.name
          ));
        }
      }
      for (final core in project.stores.verticalCores.values) {
        if (core.levelIds.contains(levelId)) {
          polygons.add((core.id, core.footprint, core.name ?? core.usage.name));
        }
      }
      for (final anchor
          in project.engineeringMetadata.siteLayout.serviceAnchors.values) {
        final position =
            ProjectServiceAnchorResolver.position(project, anchor.id);
        if (position.levelId == levelId) {
          markers.add((anchor.id, position.point, anchor.name));
        }
      }
    }
    final points = [
      for (final p in polygons) ...p.$2,
      for (final m in markers) m.$2
    ];
    if (points.isEmpty) throw StateError('Preview geometry is missing.');
    final xs = points.map((p) => p.xMm).toList()..sort(),
        ys = points.map((p) => p.yMm).toList()..sort();
    final sx = 640 / (xs.last - xs.first).clamp(1, 2000000000),
        sy = 440 / (ys.last - ys.first).clamp(1, 2000000000),
        scale = sx < sy ? sx : sy;
    WizardPreviewPoint map(BoundaryPointMm point) => WizardPreviewPoint(
        40 + (point.xMm - xs.first) * scale,
        50 + (ys.last - point.yMm) * scale);
    final elements = <WizardPreviewElement>[];
    for (final (id, points, name) in polygons) {
      final mapped = points.map(map).toList();
      elements.add(WizardPreviewPolygon(
          key: 'outline:${id.value}',
          role: levelId == null
              ? WizardPreviewRole.buildingFrame
              : WizardPreviewRole.spaceRegion,
          sourceEntityId: id,
          points: mapped));
      elements.add(WizardPreviewText(
          key: 'label:${id.value}',
          role: WizardPreviewRole.label,
          sourceEntityId: id,
          x: mapped.map((p) => p.x).reduce((a, b) => a + b) / mapped.length,
          y: mapped.map((p) => p.y).reduce((a, b) => a + b) / mapped.length,
          text: name));
    }
    for (final (id, point, name) in markers) {
      final p = map(point);
      elements.add(WizardPreviewRect(
          key: 'anchor:${id.value}',
          role: WizardPreviewRole.entryMarker,
          sourceEntityId: id,
          x: p.x - 4,
          y: p.y - 4,
          width: 8,
          height: 8));
      elements.add(WizardPreviewText(
          key: 'anchor-label:${id.value}',
          role: WizardPreviewRole.label,
          sourceEntityId: id,
          x: p.x + 6,
          y: p.y - 6,
          text: name));
    }
    return WizardPreviewScene(
        width: 720,
        height: 540,
        semanticLabel:
            levelId == null ? 'Site' : project.stores.levels[levelId]!.name,
        elements: elements);
  }
}
