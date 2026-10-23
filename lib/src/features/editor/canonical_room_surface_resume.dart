import '../../domain/project_identity.dart';

enum CanonicalRoomSurfaceResumeKind { plan, floor, ceiling, wall }

/// Durable P7A-4 resume identity for one canonical Room surface.
///
/// A wall is persisted only as [BoundaryEdgeId]. Legacy wall ordinals are
/// intentionally absent from this contract and remain a runtime projection
/// detail at the EditorController compatibility boundary.
final class CanonicalRoomSurfaceResume {
  CanonicalRoomSurfaceResume({
    required this.spaceId,
    required this.kind,
    this.boundaryEdgeId,
  }) {
    final hasEdge = boundaryEdgeId != null;
    if (kind == CanonicalRoomSurfaceResumeKind.wall && !hasEdge) {
      throw ArgumentError(
        'Canonical wall resume requires a BoundaryEdgeId.',
      );
    }
    if (kind != CanonicalRoomSurfaceResumeKind.wall && hasEdge) {
      throw ArgumentError(
        'Only canonical wall resume may carry a BoundaryEdgeId.',
      );
    }
  }

  final SpaceId spaceId;
  final CanonicalRoomSurfaceResumeKind kind;
  final BoundaryEdgeId? boundaryEdgeId;

  Map<String, Object?> toJson() => <String, Object?>{
        'spaceId': spaceId.value,
        'kind': kind.name,
        'boundaryEdgeId': boundaryEdgeId?.value,
      };

  factory CanonicalRoomSurfaceResume.fromJson(Map<String, Object?> json) {
    final rawSpaceId = json['spaceId'];
    final rawKind = json['kind'];
    final rawBoundaryEdgeId = json['boundaryEdgeId'];
    if (rawSpaceId is! String || rawSpaceId.trim().isEmpty) {
      throw const FormatException(
        'canonicalSurface.spaceId must be non-empty.',
      );
    }
    if (rawKind is! String) {
      throw const FormatException('canonicalSurface.kind must be a string.');
    }
    CanonicalRoomSurfaceResumeKind kind;
    try {
      kind = CanonicalRoomSurfaceResumeKind.values.byName(rawKind);
    } on ArgumentError {
      throw FormatException('Unknown canonicalSurface.kind $rawKind.');
    }
    if (rawBoundaryEdgeId != null &&
        (rawBoundaryEdgeId is! String || rawBoundaryEdgeId.trim().isEmpty)) {
      throw const FormatException(
        'canonicalSurface.boundaryEdgeId must be non-empty when present.',
      );
    }
    try {
      return CanonicalRoomSurfaceResume(
        spaceId: SpaceId(rawSpaceId),
        kind: kind,
        boundaryEdgeId: rawBoundaryEdgeId == null
            ? null
            : BoundaryEdgeId(rawBoundaryEdgeId as String),
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid canonicalSurface resume: $error');
    }
  }
}
