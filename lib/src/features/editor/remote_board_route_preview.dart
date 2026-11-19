import 'package:flutter/material.dart';

import '../../domain/cable_identity.dart';
import '../../domain/circuit_cable_registry.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_model.dart';
import '../../engine/adjacent_room_cable_router.dart';
import '../../engine/command_history.dart';
import '../../engine/editor_layers.dart';
import '../../engine/plan_cable_route_projector.dart';
import 'canonical_room_boundary_projection.dart';
import 'canonical_room_surface_runtime_registry.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

/// One frozen physical proposal, using existing route/cable/circuit aggregates.
/// No persistent state changes before the explicit Apply action.
final class RemoteBoardRoutePreview {
  RemoteBoardRoutePreview._(
      {required this.controller,
      required this.route,
      required this.bundle,
      required this.edgeOrder,
      required this.level,
      required this.p2Revision,
      required this.projectVersion,
      required this.canonicalSession});

  final EditorController controller;
  final ElectricalCableRoute route;
  final CircuitCableBundle bundle;
  final Map<String, List<BoundaryEdgeId>> edgeOrder;
  final BuildingLevel level;
  final int p2Revision;
  final int projectVersion;
  final Object canonicalSession;
  bool _consumed = false;

  static RemoteBoardRoutePreview create(
      {required EditorController controller,
      required ElectricalComponentPlacement board,
      required ElectricalComponentPlacement load,
      CircuitRef? assignedCircuit}) {
    final context =
        CanonicalRoomSurfaceRuntimeRegistry.physicalRoutingContextFor(
            controller);
    final coordinator =
        CanonicalRoomSurfaceRuntimeRegistry.coordinatorFor(controller);
    if (context == null || coordinator == null) {
      throw StateError('Канонический проект недоступен для построения трассы.');
    }
    if (controller.p2.circuitBundleForLoad(load.id) != null) {
      throw StateError(
          'Нагрузка уже подключена. Выберите её существующий кабель.');
    }
    final edgeOrder = <String, List<BoundaryEdgeId>>{};
    for (final space in controller.level.spaces) {
      final id = context.canonicalSpaceIdForLegacy(space.id);
      if (id == null) continue;
      final canonicalSpace = context.project.index.space(id);
      final topology = context.project.index.boundary(id);
      if (canonicalSpace == null ||
          topology == null ||
          context.binding.legacyLevelIds[canonicalSpace.levelId] !=
              controller.level.id) {
        continue;
      }
      final projection = CanonicalRoomBoundaryProjection.build(
          canonicalSpaceId: id,
          legacySpaceId: space.id,
          canonicalTopology: topology,
          legacySpace: space);
      edgeOrder[space.id] = projection.orderedEdgeIds;
    }
    final factory = SecureRandomEntityIdFactory();
    final route = AdjacentRoomCableRouter.build(
        level: controller.level,
        source: board,
        target: load,
        routeId: factory.newRouteId().value,
        edgeOrderBySpace: edgeOrder,
        canonicalSpaceIdResolver: context.canonicalSpaceIdForLegacy,
        constructions: context.constructions,
        identityFactory: factory,
        openings: controller.openings);
    final circuit = assignedCircuit ??
        CircuitRef(
            id: factory.newCircuitId().value,
            name: 'Группа · ${load.label}',
            boardId: board.id);
    if (circuit.boardId != board.id || circuit.protectiveDeviceId != null) {
      throw StateError(
          'Группа должна принадлежать выбранному щиту без неподтверждённой защиты.');
    }
    final cable = CableIdentity(
        id: 'cable-${route.id}',
        routeId: route.id,
        circuitId: circuit.id,
        designation: 'CAB-${route.id.substring(0, 8)}',
        endA: CableTerminationRef(componentId: board.id, portId: 'power-out'),
        endB: CableTerminationRef(componentId: load.id, portId: 'power-in'));
    return RemoteBoardRoutePreview._(
        controller: controller,
        route: route,
        bundle: CircuitCableBundle(circuit: circuit, cable: cable),
        edgeOrder: Map.unmodifiable(edgeOrder),
        level: controller.level,
        p2Revision: controller.p2.history.mutationRevision,
        projectVersion: context.project.version.value,
        canonicalSession: coordinator.session);
  }

  bool get canApply {
    final p2 = controller.p2;
    final current =
        CanonicalRoomSurfaceRuntimeRegistry.coordinatorFor(controller);
    return !_consumed &&
        current != null &&
        identical(current.session, canonicalSession) &&
        current.session.project.version.value == projectVersion &&
        identical(level, controller.level) &&
        p2.history.mutationRevision == p2Revision &&
        p2.layers.isVisible(EditorLayerId.cableRoutes) &&
        p2.layers.isVisible(EditorLayerId.electrical) &&
        !p2.layers.isLocked(EditorLayerId.cableRoutes) &&
        !p2.layers.isLocked(EditorLayerId.electrical) &&
        !p2.routes.any((r) => r.id == route.id) &&
        p2.circuitBundleForLoad(route.target.componentId) == null;
  }

  void discard() {
    _consumed = true;
  }

  bool apply() => applyAll([this]);

  /// One existing P2 history transaction owns every route and bundle. Failed
  /// validation never partially publishes a subset of the frozen proposal.
  static bool applyAll(List<RemoteBoardRoutePreview> previews) {
    if (previews.isEmpty) return false;
    final controller = previews.first.controller;
    final p2 = controller.p2;
    if (previews
            .any((p) => !identical(p.controller, controller) || !p.canApply) ||
        previews.map((p) => p.route.id).toSet().length != previews.length ||
        previews.map((p) => p.route.target.componentId).toSet().length !=
            previews.length) {
      return false;
    }
    final registry = CircuitCableRegistry();
    try {
      for (final assigned in p2.state.circuitBundles) {
        final existing =
            p2.routes.where((r) => r.id == assigned.cable.routeId).firstOrNull;
        if (existing == null) return false;
        registry.registerBundle(
            route: existing,
            circuit: assigned.circuit,
            cable: assigned.cable,
            protectiveDevice: assigned.protectiveDevice);
      }
      for (final preview in previews) {
        registry.registerBundle(
            route: preview.route,
            circuit: preview.bundle.circuit,
            cable: preview.bundle.cable);
        if (!ElectricalConnectivityValidator.routeIsConnected(
                route: preview.route, components: p2.components) ||
            !ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
                route: preview.route, components: p2.components)) {
          return false;
        }
      }
    } on ArgumentError {
      return false;
    } on StateError {
      return false;
    }
    final before = p2.state;
    final after = before.copyWith(
        routes: List.unmodifiable(
            [...before.routes, for (final p in previews) p.route]),
        circuitBundles: List.unmodifiable(
            [...before.circuitBundles, for (final p in previews) p.bundle]));
    p2.history.execute(_ApplyRoute(before, after));
    for (final preview in previews) {
      preview._consumed = true;
    }
    p2.setPlacementType(p2.placementType);
    return true;
  }
}

final class _ApplyRoute implements EditorCommand<EditorP2State> {
  const _ApplyRoute(this.before, this.after);
  final EditorP2State before;
  final EditorP2State after;
  @override
  String get label => 'Apply physical board route proposal';
  @override
  EditorP2State execute(EditorP2State state) => after;
  @override
  EditorP2State undo(EditorP2State state) => before;
}

Future<void> showRemoteBoardRoutePreview(
  BuildContext context, {
  required EditorController controller,
  required ElectricalComponentPlacement board,
  required ElectricalComponentPlacement load,
}) async {
  RemoteBoardRoutePreview? proposal;
  String? error;
  try {
    proposal = RemoteBoardRoutePreview.create(
        controller: controller, board: board, load: load);
  } on StateError catch (e) {
    error = e.message;
  } on ArgumentError catch (e) {
    error = e.message.toString();
  } on CanonicalRoomBoundaryProjectionException catch (e) {
    error = e.message;
  }
  final preview = proposal;
  await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
            key: const ValueKey('remote-board-route-preview'),
            title: const Text('Предпросмотр трассы'),
            content: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${board.label} → ${load.label}'),
                    if (error != null)
                      Text(error,
                          key: const ValueKey('remote-board-route-blocked')),
                    if (preview != null) ...[
                      SizedBox(
                          height: 280,
                          width: 650,
                          child: CustomPaint(
                              key: const ValueKey('remote-board-route-plan'),
                              painter: PhysicalRoutePlanPainter(
                                  level: preview.level,
                                  routes: [preview.route],
                                  edgeOrder: preview.edgeOrder,
                                  scheme: Theme.of(context).colorScheme))),
                      Text(
                          'Длина: ${(preview.route.geometricLengthMm / 1000).toStringAsFixed(2)} м; '
                          'с резервом: ${(preview.route.installationLengthMm / 1000).toStringAsFixed(2)} м'),
                      for (final hole in preview.route.penetrations)
                        Text(
                            'Проходка: ${hole.hostThicknessMm} мм · ${hole.materialId}'),
                      Text('Diff: +1 трасса, +1 кабель, +1 группа, '
                          '+${preview.route.penetrations.length} проходка. До Apply проект не изменён.'),
                    ],
                    const SizedBox(height: 8),
                    const Text('NOT QUALIFIED — сечение, защита и схема L/N/PE '
                        'не подтверждены. Геометрическая трасса не является готовым электропроектом.'),
                  ],
                ))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Отмена')),
              if (preview != null)
                FilledButton(
                    key: const ValueKey('remote-board-route-apply'),
                    onPressed: () {
                      final applied = preview.apply();
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(applied
                              ? 'Трасса применена. Инженерная квалификация не завершена.'
                              : 'Проект изменился. Постройте новый предпросмотр.')));
                      if (applied) controller.showPlan();
                    },
                    child: const Text('Применить трассу')),
            ],
          ));
  preview?.discard();
}

final class PhysicalRoutePlanPainter extends CustomPainter {
  const PhysicalRoutePlanPainter(
      {required this.level,
      required this.routes,
      required this.edgeOrder,
      required this.scheme});
  final BuildingLevel level;
  final List<ElectricalCableRoute> routes;
  final Map<String, List<BoundaryEdgeId>> edgeOrder;
  final ColorScheme scheme;
  @override
  void paint(Canvas canvas, Size size) {
    final rooms = level.spaces;
    if (rooms.isEmpty) return;
    var left = rooms.first.boundary.bounds.left;
    var bottom = rooms.first.boundary.bounds.bottom;
    var right = rooms.first.boundary.bounds.right;
    var top = rooms.first.boundary.bounds.top;
    for (final room in rooms) {
      final b = room.boundary.bounds;
      if (b.left < left) left = b.left;
      if (b.bottom < bottom) bottom = b.bottom;
      if (b.right > right) right = b.right;
      if (b.top > top) top = b.top;
    }
    final xScale = (size.width - 32) / (right - left);
    final yScale = (size.height - 32) / (top - bottom);
    final scale = xScale < yScale ? xScale : yScale;
    Offset p(int x, int y) => Offset(
        16 + (x - left) * scale, size.height - 16 - (y - bottom) * scale);
    for (final room in rooms) {
      final path = Path();
      final vertices = room.boundary.vertices;
      path.moveTo(p(vertices.first.x, vertices.first.y).dx,
          p(vertices.first.x, vertices.first.y).dy);
      for (final vertex in vertices.skip(1)) {
        final v = p(vertex.x, vertex.y);
        path.lineTo(v.dx, v.dy);
      }
      path.close();
      canvas.drawPath(
          path,
          Paint()
            ..color = scheme.outline
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }
    final projection = PlanCableRouteProjector.project(
        level: level, routes: routes, boundaryEdgeOrderBySpace: edgeOrder);
    for (final segment in projection.segments) {
      for (var i = 1; i < segment.points.length; i++) {
        final a = segment.points[i - 1];
        final b = segment.points[i];
        canvas.drawLine(
            p(a.x, a.y),
            p(b.x, b.y),
            Paint()
              ..color = scheme.primary
              ..strokeWidth = 3);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PhysicalRoutePlanPainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.routes != routes ||
      oldDelegate.edgeOrder != edgeOrder ||
      oldDelegate.scheme != scheme;
}
