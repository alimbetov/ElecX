import '../../domain/boundary_topology.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_model.dart';

enum CanonicalRoomBoundaryProjectionIssueCode {
  canonicalSpaceMismatch,
  legacySpaceMismatch,
  invalidCanonicalTopology,
  wallCountMismatch,
  edgeGeometryMismatch,
  duplicateBoundaryEdgeIdentity,
}

final class CanonicalRoomBoundaryProjectionException implements Exception {
  const CanonicalRoomBoundaryProjectionException({
    required this.code,
    required this.message,
    this.edgeId,
    this.wallOrdinal,
  });

  final CanonicalRoomBoundaryProjectionIssueCode code;
  final String message;
  final BoundaryEdgeId? edgeId;
  final int? wallOrdinal;

  @override
  String toString() => '${code.name}: $message';
}

/// One transient editor-wall projection of a durable canonical boundary edge.
///
/// [wallOrdinal] is deliberately not identity. It exists only to address the
/// transitional [EditorController] APIs that still expose walls by polygon
/// order. [edgeId] remains the authoritative engineering identity.
final class CanonicalEditorWallProjection {
  const CanonicalEditorWallProjection({
    required this.edgeId,
    required this.wallOrdinal,
    required this.start,
    required this.end,
  });

  final BoundaryEdgeId edgeId;
  final int wallOrdinal;
  final BoundaryPointMm start;
  final BoundaryPointMm end;
}

/// Strict P7A-4 bridge from canonical stable boundary identity to the legacy
/// editor's polygon-ordinal wall surface model.
///
/// The bridge never infers or repairs identity. Canonical and legacy geometry
/// must already represent the same ordered polygon exactly. Any drift fails
/// closed so a durable [BoundaryEdgeId] can never silently bind to another wall.
final class CanonicalRoomBoundaryProjection {
  CanonicalRoomBoundaryProjection._({
    required this.canonicalSpaceId,
    required this.legacySpaceId,
    required List<CanonicalEditorWallProjection> walls,
  })  : walls = List.unmodifiable(walls),
        _wallByEdgeId = Map.unmodifiable({
          for (final wall in walls) wall.edgeId: wall,
        });

  factory CanonicalRoomBoundaryProjection.build({
    required SpaceId canonicalSpaceId,
    required String legacySpaceId,
    required SpaceBoundaryTopology canonicalTopology,
    required EngineeringSpace legacySpace,
  }) {
    if (canonicalTopology.spaceId != canonicalSpaceId) {
      throw CanonicalRoomBoundaryProjectionException(
        code: CanonicalRoomBoundaryProjectionIssueCode.canonicalSpaceMismatch,
        message: 'Canonical topology belongs to ${canonicalTopology.spaceId}, '
            'not requested space $canonicalSpaceId.',
      );
    }
    if (legacySpace.id != legacySpaceId) {
      throw CanonicalRoomBoundaryProjectionException(
        code: CanonicalRoomBoundaryProjectionIssueCode.legacySpaceMismatch,
        message: 'Legacy editor space ${legacySpace.id} does not match bound '
            'space id $legacySpaceId.',
      );
    }

    try {
      canonicalTopology.validateOrThrow();
    } on BoundaryTopologyValidationException catch (error) {
      throw CanonicalRoomBoundaryProjectionException(
        code: CanonicalRoomBoundaryProjectionIssueCode.invalidCanonicalTopology,
        message: 'Canonical topology for $canonicalSpaceId cannot be projected '
            'into the legacy editor: $error',
      );
    }

    final legacyVertices = legacySpace.boundary.vertices;
    final edgeIds = canonicalTopology.orderedEdgeIds;
    if (legacyVertices.length != edgeIds.length) {
      throw CanonicalRoomBoundaryProjectionException(
        code: CanonicalRoomBoundaryProjectionIssueCode.wallCountMismatch,
        message: 'Canonical boundary has ${edgeIds.length} walls while legacy '
            'space $legacySpaceId has ${legacyVertices.length}.',
      );
    }

    final seen = <BoundaryEdgeId>{};
    final walls = <CanonicalEditorWallProjection>[];
    for (var ordinal = 0; ordinal < edgeIds.length; ordinal++) {
      final edgeId = edgeIds[ordinal];
      if (!seen.add(edgeId)) {
        throw CanonicalRoomBoundaryProjectionException(
          code: CanonicalRoomBoundaryProjectionIssueCode
              .duplicateBoundaryEdgeIdentity,
          edgeId: edgeId,
          wallOrdinal: ordinal,
          message: 'Boundary edge $edgeId appears more than once in the '
              'canonical wall projection.',
        );
      }
      final edge = canonicalTopology.edges[edgeId]!;
      final legacyStart = legacyVertices[ordinal];
      final legacyEnd = legacyVertices[(ordinal + 1) % legacyVertices.length];
      final expectedStart = BoundaryPointMm(
        xMm: legacyStart.x,
        yMm: legacyStart.y,
      );
      final expectedEnd = BoundaryPointMm(
        xMm: legacyEnd.x,
        yMm: legacyEnd.y,
      );
      if (edge.start != expectedStart || edge.end != expectedEnd) {
        throw CanonicalRoomBoundaryProjectionException(
          code: CanonicalRoomBoundaryProjectionIssueCode.edgeGeometryMismatch,
          edgeId: edgeId,
          wallOrdinal: ordinal,
          message: 'Canonical edge $edgeId at wall ordinal $ordinal has '
              '${edge.start}->${edge.end}, but the legacy canvas materializes '
              '$expectedStart->$expectedEnd.',
        );
      }
      walls.add(
        CanonicalEditorWallProjection(
          edgeId: edgeId,
          wallOrdinal: ordinal,
          start: edge.start,
          end: edge.end,
        ),
      );
    }

    return CanonicalRoomBoundaryProjection._(
      canonicalSpaceId: canonicalSpaceId,
      legacySpaceId: legacySpaceId,
      walls: walls,
    );
  }

  final SpaceId canonicalSpaceId;
  final String legacySpaceId;
  final List<CanonicalEditorWallProjection> walls;
  final Map<BoundaryEdgeId, CanonicalEditorWallProjection> _wallByEdgeId;

  int get wallCount => walls.length;
  List<BoundaryEdgeId> get orderedEdgeIds =>
      List.unmodifiable(walls.map((wall) => wall.edgeId));

  BoundaryEdgeId edgeIdAtOrdinal(int wallOrdinal) {
    if (wallOrdinal < 0 || wallOrdinal >= walls.length) {
      throw RangeError.index(wallOrdinal, walls, 'wallOrdinal');
    }
    return walls[wallOrdinal].edgeId;
  }

  int? ordinalForEdgeId(BoundaryEdgeId edgeId) =>
      _wallByEdgeId[edgeId]?.wallOrdinal;

  CanonicalEditorWallProjection? wallForEdgeId(BoundaryEdgeId edgeId) =>
      _wallByEdgeId[edgeId];
}
