import '../../domain/geometry.dart';
import '../../domain/surfaces.dart';
import '../../engine/snap_engine.dart';
import 'port_driven_cable_authoring.dart';

/// Resolves a unique compatible physical port under the canvas pointer.
///
/// Semantic port snapping has priority over the normal CAD grid. Equal-distance
/// or co-located compatible ports are ambiguous: the canvas must not silently
/// choose one. The authoring bar remains the explicit disambiguation fallback.
abstract final class CableCanvasPortAcquisition {
  static PortDrivenCableCompletionTarget? resolve({
    required Iterable<PortDrivenCableCompletionTarget> targets,
    required RoomSurfaceRef surface,
    required SurfacePointMm rawPoint,
    required double acquisitionRadiusMm,
  }) {
    if (!acquisitionRadiusMm.isFinite || acquisitionRadiusMm <= 0) {
      return null;
    }
    final onHost = targets
        .where((target) => target.surface == surface)
        .toList(growable: false);
    if (onHost.isEmpty) return null;

    final pointer = MmPoint(rawPoint.xMm, rawPoint.yMm);
    final candidate = SnapEngine.resolve(
      SnapRequest(
        rawPoint: pointer,
        acquisitionRadiusMm: acquisitionRadiusMm,
        gridStepMm: 100,
        semanticAnchors: [
          for (final target in onHost)
            SemanticSnapAnchor(
              kind: SnapKind.port,
              point: MmPoint(target.position.xMm, target.position.yMm),
              sourceId: '${target.componentId}:${target.portId}',
            ),
        ],
      ),
    );
    if (candidate == null || candidate.kind != SnapKind.port) {
      return null;
    }

    final matches = onHost
        .where(
          (target) =>
              '${target.componentId}:${target.portId}' == candidate.sourceId,
        )
        .toList(growable: false);
    if (matches.length != 1) return null;
    final selected = matches.single;
    for (final other in onHost) {
      if (identical(other, selected)) continue;
      final otherDistance = pointer.distanceTo(
        MmPoint(other.position.xMm, other.position.yMm),
      );
      // A tie is not an identity. It needs explicit port selection.
      if ((otherDistance - candidate.distanceMm).abs() < 0.001) {
        return null;
      }
    }
    return selected;
  }
}
