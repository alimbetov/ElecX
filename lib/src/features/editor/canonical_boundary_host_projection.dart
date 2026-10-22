import '../../domain/boundary_host_migration.dart';
import '../../domain/boundary_host_registry.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import 'editor_p2_session.dart';

/// P7A-5 bridge between legacy editor materialization and canonical wall-host
/// ownership. It never mutates either side; callers can calculate the complete
/// projection first and publish it atomically with their owning transaction.
abstract final class CanonicalBoundaryHostProjection {
  static BoundaryHostedObjectRegistry capture({
    required SpaceId canonicalSpaceId,
    required EngineeringSpace legacySpace,
    required List<BoundaryEdgeId> orderedEdgeIds,
    required Iterable<ArchitecturalOpening> openings,
    required EditorP2State p2State,
    BoundaryHostedObjectRegistry base =
        const BoundaryHostedObjectRegistry.empty(),
  }) {
    _requireAffinity(legacySpace, orderedEdgeIds);
    var registry = base;

    for (final entry in legacySpace.wallProfiles.entries) {
      final edgeId = _edgeAtOrdinal(orderedEdgeIds, entry.key);
      registry = registry.put(
        BoundaryHostedReference.wholeEdge(
          objectKey: _wallProfileKey(canonicalSpaceId, edgeId),
          objectKind: BoundaryHostedObjectKind.wallProfile,
          host: BoundaryEdgeHostRef(
            spaceId: canonicalSpaceId,
            edgeId: edgeId,
          ),
        ),
      );
    }

    for (final opening in openings) {
      if (opening.hostWall.spaceId != legacySpace.id) continue;
      final ordinal = opening.hostWall.wallIndex;
      if (ordinal == null) continue;
      final edgeId = _edgeAtOrdinal(orderedEdgeIds, ordinal);
      registry = registry.put(
        BoundaryHostedReference.interval(
          objectKey: _openingKey(opening.id, canonicalSpaceId),
          objectKind: BoundaryHostedObjectKind.opening,
          host: BoundaryEdgeHostRef(
            spaceId: canonicalSpaceId,
            edgeId: edgeId,
          ),
          startOffsetMm: opening.offsetFromStartMm,
          endOffsetMm: opening.endOffsetMm,
        ),
      );
    }

    for (final component in p2State.components) {
      final surface = component.surface;
      if (surface.spaceId != legacySpace.id ||
          surface.type != SurfacePlaneType.wall ||
          surface.wallIndex == null) {
        continue;
      }
      final edgeId = _edgeAtOrdinal(orderedEdgeIds, surface.wallIndex!);
      registry = registry.put(
        BoundaryHostedReference.point(
          objectKey: _componentKey(component.id),
          objectKind: BoundaryHostedObjectKind.component,
          host: BoundaryEdgeHostRef(
            spaceId: canonicalSpaceId,
            edgeId: edgeId,
          ),
          offsetMm: component.position.xMm,
        ),
      );
    }

    for (final route in p2State.routes) {
      for (var segmentIndex = 0;
          segmentIndex < route.segments.length;
          segmentIndex++) {
        final segment = route.segments[segmentIndex];
        final surface = segment.surface;
        if (surface.spaceId != legacySpace.id ||
            surface.type != SurfacePlaneType.wall ||
            surface.wallIndex == null ||
            segment.points.isEmpty) {
          continue;
        }
        final edgeId = _edgeAtOrdinal(orderedEdgeIds, surface.wallIndex!);
        for (var pointIndex = 0;
            pointIndex < segment.points.length;
            pointIndex++) {
          final isRouteStart = segmentIndex == 0 && pointIndex == 0;
          final isRouteEnd = segmentIndex == route.segments.length - 1 &&
              pointIndex == segment.points.length - 1;
          final kind = isRouteStart || isRouteEnd
              ? BoundaryHostedObjectKind.cableEndpoint
              : BoundaryHostedObjectKind.routeAnchor;
          final key = isRouteStart
              ? _cableSourceKey(route.id)
              : isRouteEnd
                  ? _cableTargetKey(route.id)
                  : _routeAnchorKey(route.id, segmentIndex, pointIndex);
          registry = registry.put(
            BoundaryHostedReference.point(
              objectKey: key,
              objectKind: kind,
              host: BoundaryEdgeHostRef(
                spaceId: canonicalSpaceId,
                edgeId: edgeId,
              ),
              offsetMm: segment.points[pointIndex].xMm,
            ),
          );
        }
      }
    }
    return registry;
  }

  static CanonicalBoundaryHostMaterialization materialize({
    required SpaceId canonicalSpaceId,
    required EngineeringSpace legacySpace,
    required List<BoundaryEdgeId> orderedEdgeIds,
    required BoundaryHostedObjectRegistry registry,
    required List<ArchitecturalOpening> openings,
    required EditorP2State p2State,
  }) {
    _requireAffinity(legacySpace, orderedEdgeIds);
    int ordinalFor(BoundaryHostedReference reference) {
      if (reference.host.spaceId != canonicalSpaceId) {
        throw StateError(
          'Hosted object ${reference.objectKey} belongs to '
          '${reference.host.spaceId}, expected $canonicalSpaceId.',
        );
      }
      final ordinal = orderedEdgeIds.indexOf(reference.host.edgeId);
      if (ordinal < 0) {
        throw StateError(
          'Hosted object ${reference.objectKey} references inactive edge '
          '${reference.host.edgeId}.',
        );
      }
      return ordinal;
    }

    final stableProfiles = <BoundaryEdgeId, dynamic>{
      ...legacySpace.boundaryEdgeWallProfiles,
    };
    for (final entry in legacySpace.wallProfiles.entries) {
      final edgeId = _edgeAtOrdinal(orderedEdgeIds, entry.key);
      stableProfiles[edgeId] = entry.value;
    }
    final materializedSpace = legacySpace.copyWith(
      boundaryEdgeWallProfiles: stableProfiles.cast(),
    );

    final nextOpenings = <ArchitecturalOpening>[
      for (final opening in openings)
        if (opening.hostWall.spaceId != legacySpace.id)
          opening
        else
          _materializeOpening(
            opening: opening,
            reference: registry[_openingKey(opening.id, canonicalSpaceId)],
            legacySpaceId: legacySpace.id,
            ordinalFor: ordinalFor,
          ),
    ];

    final nextComponents = <ElectricalComponentPlacement>[
      for (final component in p2State.components)
        _materializeComponent(
          component: component,
          reference: registry[_componentKey(component.id)],
          canonicalSpaceId: canonicalSpaceId,
          legacySpaceId: legacySpace.id,
          ordinalFor: ordinalFor,
        ),
    ];

    final nextRoutes = <ElectricalCableRoute>[
      for (final route in p2State.routes)
        _materializeRoute(
          route: route,
          canonicalSpaceId: canonicalSpaceId,
          legacySpaceId: legacySpace.id,
          registry: registry,
          ordinalFor: ordinalFor,
        ),
    ];

    return CanonicalBoundaryHostMaterialization(
      space: materializedSpace,
      openings: List.unmodifiable(nextOpenings),
      p2State: p2State.copyWith(
        components: List.unmodifiable(nextComponents),
        routes: List.unmodifiable(nextRoutes),
      ),
    );
  }

  static ArchitecturalOpening _materializeOpening({
    required ArchitecturalOpening opening,
    required BoundaryHostedReference? reference,
    required String legacySpaceId,
    required int Function(BoundaryHostedReference) ordinalFor,
  }) {
    if (reference == null) return opening;
    if (reference.objectKind != BoundaryHostedObjectKind.opening ||
        reference.geometryKind != BoundaryHostGeometryKind.interval) {
      throw StateError('Opening ${opening.id} has incompatible hosted metadata.');
    }
    final start = reference.startOffsetMm!;
    final end = reference.endOffsetMm!;
    return opening.copyWith(
      hostWall: RoomSurfaceRef.wall(legacySpaceId, ordinalFor(reference)),
      offsetFromStartMm: start,
      widthMm: end - start,
    );
  }

  static ElectricalComponentPlacement _materializeComponent({
    required ElectricalComponentPlacement component,
    required BoundaryHostedReference? reference,
    required SpaceId canonicalSpaceId,
    required String legacySpaceId,
    required int Function(BoundaryHostedReference) ordinalFor,
  }) {
    if (reference == null ||
        component.surface.spaceId != legacySpaceId ||
        component.surface.type != SurfacePlaneType.wall) {
      return component;
    }
    if (reference.objectKind != BoundaryHostedObjectKind.component ||
        reference.geometryKind != BoundaryHostGeometryKind.point ||
        reference.host.spaceId != canonicalSpaceId) {
      throw StateError(
        'Component ${component.id} has incompatible hosted metadata.',
      );
    }
    return component.copyWith(
      surface: RoomSurfaceRef.wall(legacySpaceId, ordinalFor(reference)),
      position: SurfacePointMm(
        reference.startOffsetMm!,
        component.position.yMm,
      ),
    );
  }

  static ElectricalCableRoute _materializeRoute({
    required ElectricalCableRoute route,
    required SpaceId canonicalSpaceId,
    required String legacySpaceId,
    required BoundaryHostedObjectRegistry registry,
    required int Function(BoundaryHostedReference) ordinalFor,
  }) {
    final segments = <ElectricalRouteSegment>[];
    for (var segmentIndex = 0;
        segmentIndex < route.segments.length;
        segmentIndex++) {
      final segment = route.segments[segmentIndex];
      if (segment.surface.spaceId != legacySpaceId ||
          segment.surface.type != SurfacePlaneType.wall ||
          segment.points.isEmpty) {
        segments.add(segment);
        continue;
      }
      final points = <SurfacePointMm>[];
      BoundaryHostedReference? surfaceReference;
      for (var pointIndex = 0;
          pointIndex < segment.points.length;
          pointIndex++) {
        final isRouteStart = segmentIndex == 0 && pointIndex == 0;
        final isRouteEnd = segmentIndex == route.segments.length - 1 &&
            pointIndex == segment.points.length - 1;
        final key = isRouteStart
            ? _cableSourceKey(route.id)
            : isRouteEnd
                ? _cableTargetKey(route.id)
                : _routeAnchorKey(route.id, segmentIndex, pointIndex);
        final reference = registry[key];
        if (reference == null) {
          points.add(segment.points[pointIndex]);
          continue;
        }
        if (reference.host.spaceId != canonicalSpaceId ||
            (reference.objectKind != BoundaryHostedObjectKind.routeAnchor &&
                reference.objectKind !=
                    BoundaryHostedObjectKind.cableEndpoint) ||
            reference.geometryKind != BoundaryHostGeometryKind.point) {
          throw StateError('Route $key has incompatible hosted metadata.');
        }
        surfaceReference ??= reference;
        if (surfaceReference.host.edgeId != reference.host.edgeId) {
          throw StateError(
            'Route segment ${route.id}:$segmentIndex spans multiple canonical '
            'boundary edges and must be split before legacy materialization.',
          );
        }
        points.add(
          SurfacePointMm(
            reference.startOffsetMm!,
            segment.points[pointIndex].yMm,
          ),
        );
      }
      final resolved = surfaceReference;
      if (resolved == null) {
        segments.add(segment);
      } else {
        segments.add(
          ElectricalRouteSegment(
            surface: RoomSurfaceRef.wall(
              legacySpaceId,
              ordinalFor(resolved),
            ),
            points: points,
          ),
        );
      }
    }
    return ElectricalCableRoute(
      id: route.id,
      source: route.source,
      target: route.target,
      segments: List.unmodifiable(segments),
      cableType: route.cableType,
      medium: route.medium,
      reservePercent: route.reservePercent,
    );
  }

  static void _requireAffinity(
    EngineeringSpace legacySpace,
    List<BoundaryEdgeId> orderedEdgeIds,
  ) {
    if (orderedEdgeIds.length != legacySpace.boundary.vertices.length) {
      throw StateError(
        'Canonical boundary edge count does not match legacy room geometry.',
      );
    }
  }

  static BoundaryEdgeId _edgeAtOrdinal(
    List<BoundaryEdgeId> orderedEdgeIds,
    int ordinal,
  ) {
    if (ordinal < 0 || ordinal >= orderedEdgeIds.length) {
      throw StateError('Legacy wall ordinal $ordinal is outside topology.');
    }
    return orderedEdgeIds[ordinal];
  }

  static String _openingKey(String openingId, SpaceId spaceId) =>
      'opening:$openingId:${spaceId.value}';
  static String _wallProfileKey(SpaceId spaceId, BoundaryEdgeId edgeId) =>
      'wall-profile:${spaceId.value}:${edgeId.value}';
  static String _componentKey(String componentId) => 'component:$componentId';
  static String _cableSourceKey(String routeId) => 'cable:$routeId:source';
  static String _cableTargetKey(String routeId) => 'cable:$routeId:target';
  static String _routeAnchorKey(
    String routeId,
    int segmentIndex,
    int pointIndex,
  ) =>
      'route:$routeId:segment:$segmentIndex:point:$pointIndex';
}

final class CanonicalBoundaryHostMaterialization {
  const CanonicalBoundaryHostMaterialization({
    required this.space,
    required this.openings,
    required this.p2State,
  });

  final EngineeringSpace space;
  final List<ArchitecturalOpening> openings;
  final EditorP2State p2State;
}
