import '../../domain/boundary_construction_transition_resolver.dart';
import '../../domain/project_model.dart';
import '../../domain/surface_transition_graph.dart';
import '../../domain/surfaces.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'editor_controller.dart';
import 'physical_manual_cable_draft_persistence.dart';

extension ManualCableDraftPersistence on EditorController {
  /// Production manual-route commit boundary.
  ///
  /// The public API remains stable for SurfaceCanvas, but route construction is
  /// now delegated to the physical authoring flow. Every surface change must be
  /// proven by SurfaceTransitionGraph; canonical runtime additionally resolves
  /// wall thickness/material from BoundaryConstructionRegistry. A missing or
  /// conflicting physical construction therefore preserves the draft and
  /// rejects commit instead of creating a teleporting cable.
  bool finishManualCableDraft({int endpointSnapRadiusMm = 180}) {
    final routingContext =
        CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(this);
    return finishPhysicalManualCableDraft(
      endpointSnapRadiusMm: endpointSnapRadiusMm,
      resolveTransition: (fromSurface, fromPoint, toSurface, toPoint) {
        final fromSpace = _spaceById(level, fromSurface.spaceId);
        if (fromSpace == null) return null;

        if (routingContext != null) {
          return BoundaryConstructionTransitionResolver.resolve(
            level: level,
            fromSpace: fromSpace,
            fromSurface: fromSurface,
            fromPoint: fromPoint,
            toSurface: toSurface,
            toPoint: toPoint,
            constructions: routingContext.constructions,
            edgeOrderResolver: routingContext.edgeOrderForLegacySpace,
            canonicalSpaceIdResolver:
                routingContext.canonicalSpaceIdForLegacy,
          );
        }

        // Transitional/offline editor sessions have no canonical construction
        // registry. Ordinary same-room surface adjacency remains available,
        // while a physical wall crossing has no thickness evidence and is
        // consequently rejected by CablePenetrationAuthoring.
        for (final candidate in SurfaceTransitionGraph.candidates(
          level: level,
          fromSpace: fromSpace,
          fromSurface: fromSurface,
          point: fromPoint,
        )) {
          if (candidate.toSurface == toSurface &&
              candidate.toPoint == toPoint &&
              !candidate.requiresPenetration) {
            return candidate;
          }
        }
        return null;
      },
    );
  }

  void cancelManualCableDraft({bool exitTool = false}) {
    if (routeSegments.isNotEmpty) clearRouteDraft();
    if (exitTool && tool == EditorTool.cableRoute) {
      setTool(EditorTool.select);
    }
  }
}

EngineeringSpace? _spaceById(BuildingLevel level, String spaceId) {
  for (final space in level.spaces) {
    if (space.id == spaceId) return space;
  }
  return null;
}
