import '../../../../domain/apartment_topology/apartment_area_fit.dart';
import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_topology_draft.dart';
import '../../../../domain/rectilinear_polygon_relations.dart';

/// Independent P9.6 structural validation over the packed candidate.
///
/// These checks are intentionally outside the packing algorithm so every
/// current/future geometry strategy is held to the same acceptance boundary.
final class ApartmentGeometryStructuralValidator {
  const ApartmentGeometryStructuralValidator();

  GeometryValidationReport validate({
    required ApartmentGeometryCandidate candidate,
    required AreaFittedTopologyDraft fittedDraft,
  }) {
    final issues = <GeometryValidationIssue>[];
    final draftByKey = <String, DraftSpace>{
      for (final space in fittedDraft.draft.spaces) space.semanticKey: space,
    };
    final allSpaces = [
      ...candidate.interiorSpaces,
      ...candidate.exteriorAppendages,
    ];

    for (final space in allSpaces) {
      final draft = draftByKey[space.semanticKey];
      if (draft == null) {
        issues.add(
          GeometryValidationIssue(
            code: 'p9.geometry.unknown-generated-space',
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [space.semanticKey],
          ),
        );
        continue;
      }
      final maxVertices = draft.sourceSpec.geometry.maxVertices;
      if (space.polygon.vertices.length > maxVertices) {
        issues.add(
          GeometryValidationIssue(
            code: 'p9.geometry.vertex-limit',
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [space.semanticKey],
            facts: {
              'actualVertices': space.polygon.vertices.length,
              'maxVertices': maxVertices,
            },
          ),
        );
      }
    }

    _validatePairwiseOverlap(
      issues: issues,
      spaces: candidate.interiorSpaces,
      code: 'p9.geometry.space-overlap',
    );
    _validatePairwiseOverlap(
      issues: issues,
      spaces: candidate.exteriorAppendages,
      code: 'p9.geometry.appendage-overlap',
    );
    for (final appendage in candidate.exteriorAppendages) {
      for (final interior in candidate.interiorSpaces) {
        if (!RectilinearPolygonRelations.overlapsInterior(
            appendage.polygon, interior.polygon)) {
          continue;
        }
        issues.add(
          GeometryValidationIssue(
            code: 'p9.geometry.appendage-interior-overlap',
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [appendage.semanticKey, interior.semanticKey],
          ),
        );
      }
    }

    return GeometryValidationReport(issues);
  }

  void _validatePairwiseOverlap({
    required List<GeometryValidationIssue> issues,
    required List<GeneratedSpaceGeometry> spaces,
    required String code,
  }) {
    for (var first = 0; first < spaces.length; first++) {
      for (var second = first + 1; second < spaces.length; second++) {
        if (!RectilinearPolygonRelations.overlapsInterior(
          spaces[first].polygon,
          spaces[second].polygon,
        )) {
          continue;
        }
        issues.add(
          GeometryValidationIssue(
            code: code,
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [
              spaces[first].semanticKey,
              spaces[second].semanticKey,
            ],
          ),
        );
      }
    }
  }
}
