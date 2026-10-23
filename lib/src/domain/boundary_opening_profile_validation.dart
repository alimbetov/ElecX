import 'boundary_host_migration.dart';
import 'boundary_host_registry.dart';
import 'boundary_wall_profile_registry.dart';
import 'project_identity.dart';
import 'project_space_semantics.dart';

enum BoundaryOpeningProfileIssueCode {
  missingHostedReference,
  orphanHostedReference,
  incompatibleHostedReference,
  intervalWidthMismatch,
  profileRejectsOpening,
}

final class BoundaryOpeningProfileException implements Exception {
  const BoundaryOpeningProfileException({
    required this.code,
    required this.spaceId,
    required this.message,
    this.openingId,
    this.edgeId,
  });

  final BoundaryOpeningProfileIssueCode code;
  final OpeningId? openingId;
  final SpaceId spaceId;
  final BoundaryEdgeId? edgeId;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

/// P7A-5 pre-commit validation joining semantic opening payloads with their
/// stable wall host and, when present, shaped wall-profile geometry.
///
/// The registry lookup is typed by `(OpeningId, SpaceId)`; callers never parse
/// object-key strings. This keeps P6 semantic opening identity and P7 physical
/// hosting as separate models while still proving the complete physical fit
/// before a topology mutation is committed.
abstract final class BoundaryOpeningProfileValidator {
  static void validateSpace({
    required SpaceId spaceId,
    required Iterable<ProjectOpeningEntity> openings,
    required BoundaryHostedObjectRegistry hostedObjects,
    required BoundaryWallProfileRegistry wallProfiles,
  }) {
    final wallOpenings = openings
        .where(
          (opening) =>
              opening.connectedSpaceIds.contains(spaceId) &&
              _requiresWallHost(opening.kind),
        )
        .toList(growable: false);
    final expectedKeys = <String>{
      for (final opening in wallOpenings)
        BoundaryHostedObjectRegistry.openingObjectKey(opening.id, spaceId),
    };

    for (final reference in hostedObjects.forSpace(spaceId)) {
      if (reference.objectKind != BoundaryHostedObjectKind.opening) continue;
      if (!expectedKeys.contains(reference.objectKey)) {
        throw BoundaryOpeningProfileException(
          code: BoundaryOpeningProfileIssueCode.orphanHostedReference,
          spaceId: spaceId,
          edgeId: reference.host.edgeId,
          message: 'Hosted opening ${reference.objectKey} has no matching '
              'canonical ProjectOpeningEntity in Space $spaceId.',
        );
      }
    }

    for (final opening in wallOpenings) {
      final reference = hostedObjects.openingHost(opening.id, spaceId);
      if (reference == null) {
        throw BoundaryOpeningProfileException(
          code: BoundaryOpeningProfileIssueCode.missingHostedReference,
          openingId: opening.id,
          spaceId: spaceId,
          message: 'Opening ${opening.id} has no stable wall host in '
              'Space $spaceId.',
        );
      }
      if (reference.objectKind != BoundaryHostedObjectKind.opening ||
          reference.geometryKind != BoundaryHostGeometryKind.interval ||
          reference.host.spaceId != spaceId) {
        throw BoundaryOpeningProfileException(
          code: BoundaryOpeningProfileIssueCode.incompatibleHostedReference,
          openingId: opening.id,
          spaceId: spaceId,
          edgeId: reference.host.edgeId,
          message: 'Opening ${opening.id} has incompatible hosted metadata.',
        );
      }

      final start = reference.startOffsetMm!;
      final end = reference.endOffsetMm!;
      if (end - start != opening.widthMm) {
        throw BoundaryOpeningProfileException(
          code: BoundaryOpeningProfileIssueCode.intervalWidthMismatch,
          openingId: opening.id,
          spaceId: spaceId,
          edgeId: reference.host.edgeId,
          message: 'Opening ${opening.id} width ${opening.widthMm}mm does not '
              'match hosted interval ${end - start}mm.',
        );
      }

      final profile = wallProfiles[reference.host];
      if (profile == null) continue;
      if (!profile.containsRect(
        leftMm: start,
        bottomMm: opening.baseElevationMm,
        widthMm: opening.widthMm,
        heightMm: opening.heightMm,
      )) {
        throw BoundaryOpeningProfileException(
          code: BoundaryOpeningProfileIssueCode.profileRejectsOpening,
          openingId: opening.id,
          spaceId: spaceId,
          edgeId: reference.host.edgeId,
          message: 'Opening ${opening.id} no longer fits wall profile on '
              '${reference.host.edgeId}.',
        );
      }
    }
  }

  static bool _requiresWallHost(OpeningKind kind) => switch (kind) {
        OpeningKind.hatch => false,
        OpeningKind.door ||
        OpeningKind.window ||
        OpeningKind.openPassage ||
        OpeningKind.serviceOpening ||
        OpeningKind.other =>
          true,
      };
}
