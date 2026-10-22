import 'dart:math' as math;

import '../../domain/boundary_host_migration.dart';
import '../../domain/boundary_host_registry.dart';
import '../../domain/boundary_topology.dart';
import '../../domain/boundary_wall_profile_registry.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/geometry.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import '../../domain/wall_profile.dart';
import 'cable_route_constraints.dart';
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

    for (final opening in openings) {
      final surface = opening.hostWall;
      if (surface.spaceId != legacySpace.id ||
          surface.type != SurfacePlaneType.wall) {
        continue;
      }
      final edgeId = _edgeForSurface(surface, orderedEdgeIds);
      final openingId = OpeningId(opening.id);
      registry = registry.putOpening(
        openingId: openingId,
        host: BoundaryEdgeHostRef(
          spaceId: canonicalSpaceId,
          edgeId: edgeId,
        ),
        startOffsetMm: opening.offsetFromStartMm,
        endOffsetMm: opening.endOffsetMm,
      );
    }

    for (final component in p2State.components) {
      final surface = component.surface;
      if (surface.spaceId != legacySpace.id ||
          surface.type != SurfacePlaneType.wall) {
        continue;
      }
      final edgeId = _edgeForSurface(surface, orderedEdgeIds);
      registry = registry.put(
        BoundaryHostedReference.point(
          objectKey:
              BoundaryHostedObjectRegistry.componentObjectKey(component.id),
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
            segment.points.isEmpty) {
          continue;
        }
        final edgeId = _edgeForSurface(surface, orderedEdgeIds);
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
              ? BoundaryHostedObjectRegistry.cableSourceObjectKey(route.id)
              : isRouteEnd
                  ? BoundaryHostedObjectRegistry.cableTargetObjectKey(route.id)
                  : _routeAnchorKey(
                      route.id,
                      _requireRouteAnchorId(
                        route.id,
                        segmentIndex,
                        pointIndex,
                        segment,
                      ),
                    );
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

  static BoundaryWallProfileRegistry captureWallProfiles({
    required SpaceId canonicalSpaceId,
    required EngineeringSpace legacySpace,
    required List<BoundaryEdgeId> orderedEdgeIds,
    BoundaryWallProfileRegistry base =
        const BoundaryWallProfileRegistry.empty(),
  }) {
    _requireAffinity(legacySpace, orderedEdgeIds);
    var registry = base;
    for (final entry in legacySpace.wallProfiles.entries) {
      final edgeId = _edgeAtOrdinal(orderedEdgeIds, entry.key);
      registry = registry.put(
        BoundaryEdgeHostRef(spaceId: canonicalSpaceId, edgeId: edgeId),
        entry.value,
      );
    }
    for (final entry in legacySpace.boundaryEdgeWallProfiles.entries) {
      if (!orderedEdgeIds.contains(entry.key)) {
        throw StateError(
          'Stable wall profile references inactive edge ${entry.key}.',
        );
      }
      registry = registry.put(
        BoundaryEdgeHostRef(
          spaceId: canonicalSpaceId,
          edgeId: entry.key,
        ),
        entry.value,
      );
    }
    return registry;
  }

  /// Reconstructs the transitional room polygon from the current canonical
  /// topology before projecting hosted objects back to legacy wall ordinals.
  /// This is the required path after split/merge because the wall count may
  /// differ from the pre-mutation legacy polygon.
  static CanonicalBoundaryHostMaterialization materializeTopology({
    required SpaceId canonicalSpaceId,
    required EngineeringSpace legacySpace,
    required SpaceBoundaryTopology topology,
    required BoundaryHostedObjectRegistry registry,
    required BoundaryWallProfileRegistry wallProfiles,
    required List<ArchitecturalOpening> openings,
    required EditorP2State p2State,
  }) {
    if (topology.spaceId != canonicalSpaceId) {
      throw StateError(
        'Canonical topology belongs to ${topology.spaceId}, expected '
        '$canonicalSpaceId.',
      );
    }
    topology.validateOrThrow();
    final reconstructed = legacySpace.copyWith(
      boundary: MmPolygon(<MmPoint>[
        for (final edgeId in topology.orderedEdgeIds)
          MmPoint(
            topology.edges[edgeId]!.start.xMm,
            topology.edges[edgeId]!.start.yMm,
          ),
      ]),
    );
    return materialize(
      canonicalSpaceId: canonicalSpaceId,
      legacySpace: reconstructed,
      orderedEdgeIds: topology.orderedEdgeIds,
      registry: registry,
      wallProfiles: wallProfiles,
      openings: openings,
      p2State: p2State,
    );
  }

  static CanonicalBoundaryHostMaterialization materialize({
    required SpaceId canonicalSpaceId,
    required EngineeringSpace legacySpace,
    required List<BoundaryEdgeId> orderedEdgeIds,
    required BoundaryHostedObjectRegistry registry,
    BoundaryWallProfileRegistry wallProfiles =
        const BoundaryWallProfileRegistry.empty(),
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

    final stableProfiles = wallProfiles.forSpace(canonicalSpaceId);
    final ordinalProfiles = <int, WallProfile>{};
    for (final entry in stableProfiles.entries) {
      final ordinal = orderedEdgeIds.indexOf(entry.key);
      if (ordinal < 0) {
        throw StateError(
          'Wall profile references inactive edge ${entry.key}.',
        );
      }
      ordinalProfiles[ordinal] = entry.value;
    }
    final materializedSpace = legacySpace.copyWith(
      wallProfiles: Map.unmodifiable(ordinalProfiles),
      boundaryEdgeWallProfiles: Map.unmodifiable(stableProfiles),
    );

    final nextOpenings = <ArchitecturalOpening>[
      for (final opening in openings)
        if (opening.hostWall.spaceId != legacySpace.id)
          opening
        else
          _materializeOpening(
            opening: opening,
            reference: registry.openingHost(
              OpeningId(opening.id),
              canonicalSpaceId,
            ),
            legacySpaceId: legacySpace.id,
            ordinalFor: ordinalFor,
          ),
    ];

    final nextComponents = <ElectricalComponentPlacement>[
      for (final component in p2State.components)
        _materializeComponent(
          component: component,
          reference: registry[
              BoundaryHostedObjectRegistry.componentObjectKey(component.id)],
          canonicalSpaceId: canonicalSpaceId,
          legacySpaceId: legacySpace.id,
          ordinalFor: ordinalFor,
        ),
    ];

    final nextRoutes = <ElectricalCableRoute>[];
    final nextConstraints = Map<String, CableRouteConstraints>.of(
      p2State.routeConstraints,
    );
    for (final route in p2State.routes) {
      final materialized = _materializeRoute(
        route: route,
        constraints: p2State.routeConstraints[route.id] ??
            CableRouteConstraints.empty,
        canonicalSpaceId: canonicalSpaceId,
        legacySpace: legacySpace,
        orderedEdgeIds: orderedEdgeIds,
        registry: registry,
        ordinalFor: ordinalFor,
      );
      nextRoutes.add(materialized.route);
      if (materialized.constraints.isEmpty) {
        nextConstraints.remove(route.id);
      } else {
        nextConstraints[route.id] = materialized.constraints;
      }
    }

    return CanonicalBoundaryHostMaterialization(
      space: materializedSpace,
      openings: List.unmodifiable(nextOpenings),
      p2State: p2State.copyWith(
        components: List.unmodifiable(nextComponents),
        routes: List.unmodifiable(nextRoutes),
        routeConstraints: Map.unmodifiable(nextConstraints),
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

  static _RouteMaterialization _materializeRoute({
    required ElectricalCableRoute route,
    required CableRouteConstraints constraints,
    required SpaceId canonicalSpaceId,
    required EngineeringSpace legacySpace,
    required List<BoundaryEdgeId> orderedEdgeIds,
    required BoundaryHostedObjectRegistry registry,
    required int Function(BoundaryHostedReference) ordinalFor,
  }) {
    final segments = <ElectricalRouteSegment>[];
    final oldSegmentToNew = <int, List<int>>{};
    final oldPointToNew = <String, _RoutePointLocation>{};

    for (var segmentIndex = 0;
        segmentIndex < route.segments.length;
        segmentIndex++) {
      final segment = route.segments[segmentIndex];
      if (segment.surface.spaceId != legacySpace.id ||
          segment.surface.type != SurfacePlaneType.wall ||
          segment.points.isEmpty) {
        final newIndex = segments.length;
        segments.add(segment);
        oldSegmentToNew[segmentIndex] = [newIndex];
        for (var pointIndex = 0;
            pointIndex < segment.points.length;
            pointIndex++) {
          oldPointToNew['$segmentIndex:$pointIndex'] =
              _RoutePointLocation(newIndex, pointIndex);
        }
        continue;
      }

      final resolved = <_HostedRoutePoint>[];
      for (var pointIndex = 0;
          pointIndex < segment.points.length;
          pointIndex++) {
        final isRouteStart = segmentIndex == 0 && pointIndex == 0;
        final isRouteEnd = segmentIndex == route.segments.length - 1 &&
            pointIndex == segment.points.length - 1;
        final anchorId = isRouteStart
            ? _endpointAnchorId(route, source: true)
            : isRouteEnd
                ? _endpointAnchorId(route, source: false)
                : _requireRouteAnchorId(
                    route.id,
                    segmentIndex,
                    pointIndex,
                    segment,
                  );
        final key = isRouteStart
            ? BoundaryHostedObjectRegistry.cableSourceObjectKey(route.id)
            : isRouteEnd
                ? BoundaryHostedObjectRegistry.cableTargetObjectKey(route.id)
                : _routeAnchorKey(route.id, anchorId);
        final reference = registry[key];
        if (reference == null) {
          throw StateError(
            'Route $key has no canonical hosted reference during P7A-5 '
            'materialization.',
          );
        }
        if (reference.host.spaceId != canonicalSpaceId ||
            (reference.objectKind != BoundaryHostedObjectKind.routeAnchor &&
                reference.objectKind !=
                    BoundaryHostedObjectKind.cableEndpoint) ||
            reference.geometryKind != BoundaryHostGeometryKind.point) {
          throw StateError('Route $key has incompatible hosted metadata.');
        }
        resolved.add(
          _HostedRoutePoint(
            sourceSegmentIndex: segmentIndex,
            sourcePointIndex: pointIndex,
            sourcePoint: segment.points[pointIndex],
            anchorId: anchorId,
            reference: reference,
          ),
        );
      }

      final produced = <int>[];
      var currentEdgeId = resolved.first.reference.host.edgeId;
      var currentOrdinal = ordinalFor(resolved.first.reference);
      var currentPoints = <SurfacePointMm>[];
      var currentAnchorIds = <RouteAnchorId>[];
      var pendingSourceLocations = <_HostedRoutePoint>[];

      void appendSourcePoint(_HostedRoutePoint point) {
        currentPoints.add(
          SurfacePointMm(
            point.reference.startOffsetMm!,
            point.sourcePoint.yMm,
          ),
        );
        currentAnchorIds.add(point.anchorId);
        pendingSourceLocations.add(point);
      }

      void finishSegment() {
        final newIndex = segments.length;
        segments.add(
          ElectricalRouteSegment(
            surface: RoomSurfaceRef.wall(legacySpace.id, currentOrdinal),
            points: List.unmodifiable(currentPoints),
            anchorIds: List.unmodifiable(currentAnchorIds),
          ),
        );
        produced.add(newIndex);
        for (var index = 0; index < pendingSourceLocations.length; index++) {
          final source = pendingSourceLocations[index];
          final anchorIndex = currentAnchorIds.indexOf(source.anchorId);
          oldPointToNew[
            '${source.sourceSegmentIndex}:${source.sourcePointIndex}'
          ] = _RoutePointLocation(newIndex, anchorIndex);
        }
        currentPoints = <SurfacePointMm>[];
        currentAnchorIds = <RouteAnchorId>[];
        pendingSourceLocations = <_HostedRoutePoint>[];
      }

      appendSourcePoint(resolved.first);
      for (var index = 1; index < resolved.length; index++) {
        final previous = resolved[index - 1];
        final point = resolved[index];
        final nextEdgeId = point.reference.host.edgeId;
        if (nextEdgeId == currentEdgeId) {
          appendSourcePoint(point);
          continue;
        }

        final nextOrdinal = ordinalFor(point.reference);
        if (!_isLosslessCollinearTransition(
          legacySpace.boundary,
          currentOrdinal,
          nextOrdinal,
        )) {
          throw StateError(
            'Route ${route.id} crosses canonical edges $currentEdgeId and '
            '$nextEdgeId without a lossless collinear wall transition.',
          );
        }
        if (previous.sourcePoint.yMm != point.sourcePoint.yMm) {
          throw StateError(
            'Route ${route.id} changes height while crossing a split boundary; '
            'explicit reroute is required.',
          );
        }

        final transitionY = point.sourcePoint.yMm;
        final transitionId = _transitionAnchorId(
          routeId: route.id,
          fromEdgeId: currentEdgeId,
          toEdgeId: nextEdgeId,
          leftAnchorId: previous.anchorId,
          rightAnchorId: point.anchorId,
        );
        final wallLength = _wallLengthMm(legacySpace.boundary, currentOrdinal);
        currentPoints.add(SurfacePointMm(wallLength, transitionY));
        currentAnchorIds.add(transitionId);
        finishSegment();

        currentEdgeId = nextEdgeId;
        currentOrdinal = nextOrdinal;
        currentPoints.add(SurfacePointMm(0, transitionY));
        currentAnchorIds.add(transitionId);
        appendSourcePoint(point);
      }
      finishSegment();
      oldSegmentToNew[segmentIndex] = List.unmodifiable(produced);
    }

    final nextConstraints = _remapConstraints(
      constraints: constraints,
      sourceRoute: route,
      resultSegments: segments,
      oldSegmentToNew: oldSegmentToNew,
      oldPointToNew: oldPointToNew,
    );
    return _RouteMaterialization(
      route: ElectricalCableRoute(
        id: route.id,
        source: route.source,
        target: route.target,
        segments: List.unmodifiable(segments),
        cableType: route.cableType,
        medium: route.medium,
        reservePercent: route.reservePercent,
      ),
      constraints: nextConstraints,
    );
  }

  static CableRouteConstraints _remapConstraints({
    required CableRouteConstraints constraints,
    required ElectricalCableRoute sourceRoute,
    required List<ElectricalRouteSegment> resultSegments,
    required Map<int, List<int>> oldSegmentToNew,
    required Map<String, _RoutePointLocation> oldPointToNew,
  }) {
    if (constraints.isEmpty) return constraints;
    final locks = <int>{};
    for (final sourceIndex in constraints.lockedSegments) {
      locks.addAll(oldSegmentToNew[sourceIndex] ?? const <int>[]);
    }
    final waypoints = <CableMandatoryWaypoint>[];
    for (final waypoint in constraints.mandatoryWaypoints) {
      if (waypoint.segmentIndex >= sourceRoute.segments.length) continue;
      final location = oldPointToNew[
        '${waypoint.segmentIndex}:${waypoint.pointIndex}'
      ];
      if (location == null || location.segmentIndex >= resultSegments.length) {
        throw StateError(
          'Mandatory waypoint could not be rebound through P7A-5 route split.',
        );
      }
      final points = resultSegments[location.segmentIndex].points;
      if (location.pointIndex >= points.length) {
        throw StateError('Rebound route waypoint index is invalid.');
      }
      waypoints.add(
        CableMandatoryWaypoint(
          segmentIndex: location.segmentIndex,
          pointIndex: location.pointIndex,
          point: points[location.pointIndex],
        ),
      );
    }
    return CableRouteConstraints(
      lockedSegments: locks,
      mandatoryWaypoints: waypoints,
    );
  }

  static RouteAnchorId _requireRouteAnchorId(
    String routeId,
    int segmentIndex,
    int pointIndex,
    ElectricalRouteSegment segment,
  ) {
    final anchorId = segment.anchorIdAt(pointIndex);
    if (anchorId == null) {
      throw StateError(
        'Route $routeId segment $segmentIndex point $pointIndex has no stable '
        'RouteAnchorId. P7A-5 refuses to persist route anchors by list index.',
      );
    }
    return anchorId;
  }

  static RouteAnchorId _endpointAnchorId(
    ElectricalCableRoute route, {
    required bool source,
  }) =>
      RouteAnchorId(
        source
            ? 'p7a-endpoint:${route.id}:source:${route.source.componentId}:${route.source.portId}'
            : 'p7a-endpoint:${route.id}:target:${route.target.componentId}:${route.target.portId}',
      );

  static RouteAnchorId _transitionAnchorId({
    required String routeId,
    required BoundaryEdgeId fromEdgeId,
    required BoundaryEdgeId toEdgeId,
    required RouteAnchorId leftAnchorId,
    required RouteAnchorId rightAnchorId,
  }) =>
      RouteAnchorId(
        'p7a-transition:$routeId:${fromEdgeId.value}:${toEdgeId.value}:'
        '${leftAnchorId.value}:${rightAnchorId.value}',
      );

  static bool _isLosslessCollinearTransition(
    MmPolygon boundary,
    int fromOrdinal,
    int toOrdinal,
  ) {
    final count = boundary.vertices.length;
    if (count < 3 || toOrdinal != (fromOrdinal + 1) % count) return false;
    final a = boundary.vertices[fromOrdinal];
    final b = boundary.vertices[(fromOrdinal + 1) % count];
    final c = boundary.vertices[(toOrdinal + 1) % count];
    final firstDx = b.x - a.x;
    final firstDy = b.y - a.y;
    final secondDx = c.x - b.x;
    final secondDy = c.y - b.y;
    final cross = firstDx * secondDy - firstDy * secondDx;
    final dot = firstDx * secondDx + firstDy * secondDy;
    return cross == 0 && dot > 0;
  }

  static int _wallLengthMm(MmPolygon boundary, int ordinal) {
    final a = boundary.vertices[ordinal];
    final b = boundary.vertices[(ordinal + 1) % boundary.vertices.length];
    final dx = (b.x - a.x).toDouble();
    final dy = (b.y - a.y).toDouble();
    return math.sqrt(dx * dx + dy * dy).round();
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

  static BoundaryEdgeId _edgeForSurface(
    RoomSurfaceRef surface,
    List<BoundaryEdgeId> orderedEdgeIds,
  ) {
    final stableId = surface.boundaryEdgeId;
    if (stableId != null) {
      if (!orderedEdgeIds.contains(stableId)) {
        throw StateError(
          'Canonical wall surface references inactive edge $stableId.',
        );
      }
      return stableId;
    }
    final ordinal = surface.wallIndex;
    if (ordinal == null) {
      throw StateError('Wall surface has neither BoundaryEdgeId nor wallIndex.');
    }
    return _edgeAtOrdinal(orderedEdgeIds, ordinal);
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

  static String _routeAnchorKey(String routeId, RouteAnchorId anchorId) =>
      'route:$routeId:anchor:${anchorId.value}';
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

final class _HostedRoutePoint {
  const _HostedRoutePoint({
    required this.sourceSegmentIndex,
    required this.sourcePointIndex,
    required this.sourcePoint,
    required this.anchorId,
    required this.reference,
  });

  final int sourceSegmentIndex;
  final int sourcePointIndex;
  final SurfacePointMm sourcePoint;
  final RouteAnchorId anchorId;
  final BoundaryHostedReference reference;
}

final class _RoutePointLocation {
  const _RoutePointLocation(this.segmentIndex, this.pointIndex);

  final int segmentIndex;
  final int pointIndex;
}

final class _RouteMaterialization {
  const _RouteMaterialization({
    required this.route,
    required this.constraints,
  });

  final ElectricalCableRoute route;
  final CableRouteConstraints constraints;
}
