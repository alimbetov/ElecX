from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'anchor not found in {path}: {old[:120]!r}')
    text = text.replace(old, new, 1)
    p.write_text(text)


# F10: catalog placement must obey the electrical layer policy.
replace_once(
    'lib/src/features/editor/catalog_component_placement.dart',
    "import '../../engine/command_history.dart';\n",
    "import '../../engine/command_history.dart';\nimport '../../engine/editor_layers.dart';\n",
)
replace_once(
    'lib/src/features/editor/catalog_component_placement.dart',
    "  }) {\n    if (!entry.canPlaceOn(surface)) {\n",
    "  }) {\n    if (!layers.isVisible(EditorLayerId.electrical) ||\n        layers.isLocked(EditorLayerId.electrical)) {\n      throw StateError('Electrical layer is not editable.');\n    }\n    if (!entry.canPlaceOn(surface)) {\n",
)

replace_once(
    'lib/src/features/editor/engineering_placement_cursor_session.dart',
    "import '../../domain/surfaces.dart';\n",
    "import '../../domain/surfaces.dart';\nimport '../../engine/editor_layers.dart';\n",
)
replace_once(
    'lib/src/features/editor/engineering_placement_cursor_session.dart',
    "  bool confirm() {\n    final current = ensure();\n    if (current == null || !current.isValid) return false;\n",
    "  bool confirm() {\n    final current = ensure();\n    if (current == null || !current.isValid) return false;\n    if (!controller.p2.layers.isVisible(EditorLayerId.electrical) ||\n        controller.p2.layers.isLocked(EditorLayerId.electrical)) {\n      return false;\n    }\n",
)

replace_once(
    'lib/src/features/editor/editor_p2_session.dart',
    "  bool beginMoveSelectedComponent() {\n    final component = selectedComponent;\n    if (component == null ||\n        layers.isLocked(EditorLayerId.electrical) ||\n        _moveOriginState != null) {\n",
    "  bool beginMoveSelectedComponent() {\n    final component = selectedComponent;\n    if (component == null ||\n        layers.isLocked(EditorLayerId.electrical) ||\n        (layers.isLocked(EditorLayerId.cableRoutes) &&\n            _componentHasConnectedRoutes(component.id)) ||\n        _moveOriginState != null) {\n",
)
replace_once(
    'lib/src/features/editor/editor_p2_session.dart',
    "  bool toggleRouteSegmentLock(String routeId, int segmentIndex) {\n    final route = _routeForId(routeId);\n",
    "  bool toggleRouteSegmentLock(String routeId, int segmentIndex) {\n    if (layers.isLocked(EditorLayerId.cableRoutes)) return false;\n    final route = _routeForId(routeId);\n",
)
replace_once(
    'lib/src/features/editor/editor_p2_session.dart',
    "  bool toggleRouteWaypoint({\n    required String routeId,\n",
    "  bool toggleRouteWaypoint({\n    required String routeId,\n",
)
replace_once(
    'lib/src/features/editor/editor_p2_session.dart',
    "  }) {\n    final route = _routeForId(routeId);\n    if (route == null ||\n        segmentIndex < 0 ||\n        segmentIndex >= route.segments.length) {\n      return false;\n    }\n    final points = route.segments[segmentIndex].points;\n",
    "  }) {\n    if (layers.isLocked(EditorLayerId.cableRoutes)) return false;\n    final route = _routeForId(routeId);\n    if (route == null ||\n        segmentIndex < 0 ||\n        segmentIndex >= route.segments.length) {\n      return false;\n    }\n    final points = route.segments[segmentIndex].points;\n",
)
replace_once(
    'lib/src/features/editor/editor_p2_session.dart',
    "  bool moveSelectedComponent(SurfacePointMm point) {\n    final component = selectedComponent;\n    if (component == null || layers.isLocked(EditorLayerId.electrical)) {\n      return false;\n    }\n",
    "  bool moveSelectedComponent(SurfacePointMm point) {\n    final component = selectedComponent;\n    if (component == null ||\n        layers.isLocked(EditorLayerId.electrical) ||\n        (layers.isLocked(EditorLayerId.cableRoutes) &&\n            _componentHasConnectedRoutes(component.id))) {\n      return false;\n    }\n",
)
replace_once(
    'lib/src/features/editor/editor_p2_session.dart',
    "    final removedRouteIds = <String>{\n      for (final route in routes)\n        if (ids.contains(route.source.componentId) ||\n            ids.contains(route.target.componentId))\n          route.id,\n    };\n",
    "    final removedRouteIds = <String>{\n      for (final route in routes)\n        if (ids.contains(route.source.componentId) ||\n            ids.contains(route.target.componentId))\n          route.id,\n    };\n    if (removedRouteIds.isNotEmpty &&\n        layers.isLocked(EditorLayerId.cableRoutes)) {\n      return false;\n    }\n",
)
replace_once(
    'lib/src/features/editor/editor_p2_session.dart',
    "  bool _addRouteSegments({\n    required ElectricalEndpointRef source,\n",
    "  bool addManualRouteSegments({\n    required ElectricalEndpointRef source,\n    required ElectricalEndpointRef target,\n    required List<ElectricalRouteSegment> segments,\n    String? cableType,\n  }) {\n    if (!layers.isVisible(EditorLayerId.cableRoutes) ||\n        layers.isLocked(EditorLayerId.cableRoutes)) {\n      return false;\n    }\n    return _addRouteSegments(\n      source: source,\n      target: target,\n      segments: segments,\n      cableType: cableType,\n    );\n  }\n\n  bool _addRouteSegments({\n    required ElectricalEndpointRef source,\n",
)
replace_once(
    'lib/src/features/editor/editor_p2_session.dart',
    "  ElectricalCableRoute? _routeForId(String routeId) {\n",
    "  bool _componentHasConnectedRoutes(String componentId) => routes.any(\n        (route) =>\n            route.source.componentId == componentId ||\n            route.target.componentId == componentId,\n      );\n\n  ElectricalCableRoute? _routeForId(String routeId) {\n",
)

# F11: canonical persistent finish/cancel for the legacy manual surface draft.
manual_path = Path('lib/src/features/editor/manual_cable_draft_persistence.dart')
manual_path.write_text(r'''import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/surfaces.dart';
import '../../engine/port_snap_resolver.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

final class _ManualEndpoint {
  const _ManualEndpoint(this.component, this.port);

  final ElectricalComponentPlacement component;
  final ElectricalPortDefinition port;
}

extension ManualCableDraftPersistence on EditorController {
  bool finishManualCableDraft({int endpointSnapRadiusMm = 180}) {
    if (tool != EditorTool.cableRoute ||
        routeSegments.isEmpty ||
        endpointSnapRadiusMm <= 0 ||
        !p2.layers.isVisible(EditorLayerId.cableRoutes) ||
        p2.layers.isLocked(EditorLayerId.cableRoutes)) {
      return false;
    }
    if (routeSegments.any((segment) => segment.points.length < 2)) {
      return false;
    }

    final firstDraft = routeSegments.first;
    final lastDraft = routeSegments.last;
    final source = _nearestManualEndpoint(
      components: p2.components,
      surface: firstDraft.surface,
      point: firstDraft.points.first,
      role: CableEndpointRole.source,
      radiusMm: endpointSnapRadiusMm,
    );
    if (source == null) return false;
    final target = _nearestManualEndpoint(
      components: p2.components,
      surface: lastDraft.surface,
      point: lastDraft.points.last,
      role: CableEndpointRole.target,
      radiusMm: endpointSnapRadiusMm,
      excludeComponentId: source.component.id,
      counterpartKind: source.port.kind,
    );
    if (target == null) return false;

    final segments = <ElectricalRouteSegment>[];
    for (var i = 0; i < routeSegments.length; i++) {
      final draft = routeSegments[i];
      final points = List<SurfacePointMm>.of(draft.points);
      if (i == 0) points[0] = source.component.position;
      if (i == routeSegments.length - 1) {
        points[points.length - 1] = target.component.position;
      }
      segments.add(
        ElectricalRouteSegment(
          surface: draft.surface,
          points: List.unmodifiable(points),
        ),
      );
    }

    final committed = p2.addManualRouteSegments(
      source: ElectricalEndpointRef(
        componentId: source.component.id,
        portId: source.port.id,
      ),
      target: ElectricalEndpointRef(
        componentId: target.component.id,
        portId: target.port.id,
      ),
      segments: List.unmodifiable(segments),
    );
    if (!committed) return false;
    clearRouteDraft();
    setTool(EditorTool.select);
    return true;
  }

  void cancelManualCableDraft({bool exitTool = false}) {
    if (routeSegments.isNotEmpty) clearRouteDraft();
    if (exitTool && tool == EditorTool.cableRoute) {
      setTool(EditorTool.select);
    }
  }
}

_ManualEndpoint? _nearestManualEndpoint({
  required Iterable<ElectricalComponentPlacement> components,
  required RoomSurfaceRef surface,
  required SurfacePointMm point,
  required CableEndpointRole role,
  required int radiusMm,
  String? excludeComponentId,
  ElectricalPortKind? counterpartKind,
}) {
  _ManualEndpoint? best;
  var bestDistanceSquared = radiusMm * radiusMm + 1;
  for (final component in components) {
    if (component.surface != surface || component.id == excludeComponentId) {
      continue;
    }
    final dx = component.position.xMm - point.xMm;
    final dy = component.position.yMm - point.yMm;
    final distanceSquared = dx * dx + dy * dy;
    if (distanceSquared > radiusMm * radiusMm ||
        distanceSquared >= bestDistanceSquared) {
      continue;
    }
    for (final port in component.ports) {
      final roleCompatible = switch (role) {
        CableEndpointRole.source =>
          port.kind == ElectricalPortKind.powerOut ||
              port.kind == ElectricalPortKind.controlOut,
        CableEndpointRole.target =>
          port.kind == ElectricalPortKind.powerIn ||
              port.kind == ElectricalPortKind.controlIn,
      };
      if (!roleCompatible) continue;
      if (counterpartKind != null) {
        final compatible = role == CableEndpointRole.source
            ? ElectricalPortCompatibility.areCompatible(
                port.kind,
                counterpartKind,
              )
            : ElectricalPortCompatibility.areCompatible(
                counterpartKind,
                port.kind,
              );
        if (!compatible) continue;
      }
      best = _ManualEndpoint(component, port);
      bestDistanceSquared = distanceSquared;
      break;
    }
  }
  return best;
}
''')

replace_once(
    'lib/src/features/editor/editor_keyboard_scope.dart',
    "import 'engineering_placement_cursor_session.dart';\n",
    "import 'engineering_placement_cursor_session.dart';\nimport 'manual_cable_draft_persistence.dart';\n",
)
replace_once(
    'lib/src/features/editor/editor_keyboard_scope.dart',
    "    } else if (controller.placementCursor.active) {\n      controller.placementCursor.cancel();\n    } else {\n      controller.setTool(EditorTool.select);\n    }\n",
    "    } else if (controller.placementCursor.active) {\n      controller.placementCursor.cancel();\n    } else if (controller.tool == EditorTool.cableRoute &&\n        controller.routeSegments.isNotEmpty) {\n      controller.cancelManualCableDraft();\n    } else {\n      controller.setTool(EditorTool.select);\n    }\n",
)
replace_once(
    'lib/src/features/editor/editor_keyboard_scope.dart',
    "    } else if (controller.placementCursor.active) {\n      controller.placementCursor.confirm();\n    }\n",
    "    } else if (controller.placementCursor.active) {\n      controller.placementCursor.confirm();\n    } else if (controller.tool == EditorTool.cableRoute &&\n        controller.routeSegments.isNotEmpty) {\n      controller.finishManualCableDraft();\n    }\n",
)

# F10/F11/F13 SurfaceCanvas interaction + feedback.
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "import 'hosted_route_session.dart';\n",
    "import 'hosted_route_session.dart';\nimport 'manual_cable_draft_persistence.dart';\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "  ElectricalComponentPlacement? _componentForHandle(\n    SurfacePointMm point,\n    _SurfaceProjection projection,\n  ) {\n    final radiusMm = math.max(80.0, projection.camera.mmPerPixel * 18);\n",
    "  ElectricalComponentPlacement? _componentForHandle(\n    SurfacePointMm point,\n    _SurfaceProjection projection,\n  ) {\n    if (!controller.p2.layers.isVisible(EditorLayerId.electrical)) return null;\n    final radiusMm = math.max(80.0, projection.camera.mmPerPixel * 18);\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "  CableCanvasHit? _cableHitAt(\n    SurfacePointMm point,\n    _SurfaceProjection projection,\n    PointerDeviceKind kind,\n  ) {\n    final route = controller.routeSelection.selectedRoute;\n",
    "  CableCanvasHit? _cableHitAt(\n    SurfacePointMm point,\n    _SurfaceProjection projection,\n    PointerDeviceKind kind,\n  ) {\n    if (!controller.p2.layers.isVisible(EditorLayerId.cableRoutes) ||\n        controller.p2.layers.isLocked(EditorLayerId.cableRoutes)) {\n      return null;\n    }\n    final route = controller.routeSelection.selectedRoute;\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "    final placementType = controller.p2.placementType;\n    if (placementType != null) {\n      controller.p2.placeComponent(\n",
    "    final placementType = controller.p2.placementType;\n    if (placementType != null) {\n      if (!controller.p2.layers.isVisible(EditorLayerId.electrical) ||\n          controller.p2.layers.isLocked(EditorLayerId.electrical)) {\n        return;\n      }\n      controller.p2.placeComponent(\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "      final explicitTransition = _explicitTransitionAt(raw, projection);\n      if (explicitTransition != null) {\n        _followTransition(explicitTransition, surface);\n        return;\n      }\n      final legacyTarget = _legacyTransitionTargetAt(raw, projection);\n      if (legacyTarget != null) {\n        _navigateToSurface(legacyTarget);\n        return;\n      }\n\n      final hit = RouteInteractionEngine.hitTestHosted(\n        routes: _allHostedRoutes(),\n        host: RouteHostRef.indoor(surface),\n        xMm: raw.xMm.toDouble(),\n        yMm: raw.yMm.toDouble(),\n        radiusMm: math.max(70.0, projection.camera.mmPerPixel * 12),\n      );\n      if (hit != null) {\n        controller.routeSelection.select(hit.routeId);\n        return;\n      }\n",
    "      if (controller.p2.layers.isVisible(EditorLayerId.cableRoutes)) {\n        final explicitTransition = _explicitTransitionAt(raw, projection);\n        if (explicitTransition != null) {\n          _followTransition(explicitTransition, surface);\n          return;\n        }\n        final legacyTarget = _legacyTransitionTargetAt(raw, projection);\n        if (legacyTarget != null) {\n          _navigateToSurface(legacyTarget);\n          return;\n        }\n\n        final hit = RouteInteractionEngine.hitTestHosted(\n          routes: _allHostedRoutes(),\n          host: RouteHostRef.indoor(surface),\n          xMm: raw.xMm.toDouble(),\n          yMm: raw.yMm.toDouble(),\n          radiusMm: math.max(70.0, projection.camera.mmPerPixel * 12),\n        );\n        if (hit != null) {\n          controller.routeSelection.select(hit.routeId);\n          return;\n        }\n      }\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "  void _commitMarquee(_SurfaceProjection projection) {\n    final rect = _marqueeRect;\n",
    "  void _commitMarquee(_SurfaceProjection projection) {\n    if (!controller.p2.layers.isVisible(EditorLayerId.electrical)) return;\n    final rect = _marqueeRect;\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "        final bottomEditorVisible = surface.type == SurfacePlaneType.wall &&\n            controller.boundaryEditing.active &&\n            controller.boundaryEditing.profile != BoundaryEditProfile.wall;\n",
    "        final bottomEditorVisible = surface.type == SurfacePlaneType.wall &&\n            controller.boundaryEditing.active &&\n            controller.boundaryEditing.profile != BoundaryEditProfile.wall;\n        final electricalVisible =\n            controller.p2.layers.isVisible(EditorLayerId.electrical);\n        final cableRoutesVisible =\n            controller.p2.layers.isVisible(EditorLayerId.cableRoutes);\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "            if (controller.p2.selectedComponent case final component?)\n",
    "            if (electricalVisible &&\n                controller.p2.selectedComponent case final component?)\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "            if (controller.routeSelection.selectedRouteId case final routeId?)\n",
    "            if (cableRoutesVisible &&\n                controller.routeSelection.selectedRouteId case final routeId?)\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "            if (controller.routeSelection.selectedRouteId != null)\n",
    "            if (cableRoutesVisible &&\n                controller.routeSelection.selectedRouteId != null)\n",
)
# Manual draft explicit finish/cancel HUD.
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "            if (surface.type == SurfacePlaneType.wall)\n              Positioned(\n                left: compact ? 8 : 12,\n                right: compact ? 8 : 12,\n                bottom: 0,\n",
    "            if (cableRoutesVisible &&\n                controller.tool == EditorTool.cableRoute &&\n                controller.routeSegments.isNotEmpty)\n              Positioned(\n                right: compact ? 8 : 12,\n                bottom: bottomEditorVisible ? 148 : 12,\n                child: Card(\n                  child: Padding(\n                    padding: const EdgeInsets.symmetric(\n                      horizontal: 8,\n                      vertical: 6,\n                    ),\n                    child: Row(\n                      mainAxisSize: MainAxisSize.min,\n                      children: [\n                        TextButton.icon(\n                          key: const ValueKey('manual-cable-cancel'),\n                          onPressed: controller.cancelManualCableDraft,\n                          icon: const Icon(Icons.close, size: 16),\n                          label: const Text('Отмена'),\n                        ),\n                        const SizedBox(width: 4),\n                        FilledButton.icon(\n                          key: const ValueKey('manual-cable-finish'),\n                          onPressed: controller.finishManualCableDraft,\n                          icon: const Icon(Icons.check, size: 16),\n                          label: const Text('Завершить'),\n                        ),\n                      ],\n                    ),\n                  ),\n                ),\n              ),\n            if (controller.componentTransform.previewState case final preview?\n                when !preview.isValid)\n              Positioned(\n                left: compact ? 8 : 12,\n                top: compact ? 104 : 108,\n                child: Chip(\n                  key: const ValueKey('component-preview-invalid'),\n                  avatar: Icon(Icons.error_outline, color: scheme.error, size: 18),\n                  label: const Text('Невалидная позиция · commit запрещён'),\n                ),\n              ),\n            if (surface.type == SurfacePlaneType.wall)\n              Positioned(\n                left: compact ? 8 : 12,\n                right: compact ? 8 : 12,\n                bottom: 0,\n",
)
# Painter must repaint and draw the invalid target as a red ghost.
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "        selectionFingerprint = Object.hashAll(controller.p2.selection.ids),\n        snapFingerprint = controller.p2.activeSnap == null\n",
    "        selectionFingerprint = Object.hashAll(controller.p2.selection.ids),\n        transformPreviewFingerprint = controller.componentTransform.previewState == null\n            ? 0\n            : Object.hash(\n                controller.componentTransform.previewState!.componentId,\n                controller.componentTransform.previewState!.position.xMm,\n                controller.componentTransform.previewState!.position.yMm,\n                controller.componentTransform.previewState!.isValid,\n              ),\n        snapFingerprint = controller.p2.activeSnap == null\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "  final int selectionFingerprint;\n  final int snapFingerprint;\n",
    "  final int selectionFingerprint;\n  final int transformPreviewFingerprint;\n  final int snapFingerprint;\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "    for (final component in controller.p2.components) {\n      if (component.surface != surface) continue;\n      final center = projection.surfaceToViewport(component.position);\n      final selected = controller.p2.selection.contains(component.id);\n      _drawComponentSymbol(canvas, component.type, center, selected);\n    }\n    final snap = controller.p2.activeSnap;\n",
    "    for (final component in controller.p2.components) {\n      if (component.surface != surface) continue;\n      final center = projection.surfaceToViewport(component.position);\n      final selected = controller.p2.selection.contains(component.id);\n      _drawComponentSymbol(canvas, component.type, center, selected);\n    }\n    final transformPreview = controller.componentTransform.previewState;\n    if (transformPreview != null &&\n        !transformPreview.isValid &&\n        transformPreview.surface == surface) {\n      ElectricalComponentPlacement? previewComponent;\n      for (final component in controller.p2.components) {\n        if (component.id == transformPreview.componentId) {\n          previewComponent = component;\n          break;\n        }\n      }\n      if (previewComponent != null) {\n        _drawComponentSymbol(\n          canvas,\n          previewComponent.type,\n          projection.surfaceToViewport(transformPreview.position),\n          true,\n          strokeColor: scheme.error,\n          fillColor: scheme.errorContainer.withValues(alpha: 0.55),\n        );\n      }\n    }\n    final snap = controller.p2.activeSnap;\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "  void _drawComponentSymbol(\n    Canvas canvas,\n    ElectricalComponentType type,\n    Offset center,\n    bool selected,\n  ) {\n",
    "  void _drawComponentSymbol(\n    Canvas canvas,\n    ElectricalComponentType type,\n    Offset center,\n    bool selected, {\n    Color? strokeColor,\n    Color? fillColor,\n  }) {\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "      ..color = selected\n          ? CadVisualTokens.selectedGeometry(scheme)\n          : scheme.onSurface;\n",
    "      ..color = strokeColor ??\n          (selected ? CadVisualTokens.selectedGeometry(scheme) : scheme.onSurface);\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "      ..color = selected\n          ? CadVisualTokens.selectedFill(scheme)\n          : scheme.surfaceContainerLowest;\n",
    "      ..color = fillColor ??\n          (selected\n              ? CadVisualTokens.selectedFill(scheme)\n              : scheme.surfaceContainerLowest);\n",
)
replace_once(
    'lib/src/features/editor/surface_canvas.dart',
    "      oldDelegate.selectionFingerprint != selectionFingerprint ||\n      oldDelegate.snapFingerprint != snapFingerprint ||\n",
    "      oldDelegate.selectionFingerprint != selectionFingerprint ||\n      oldDelegate.transformPreviewFingerprint != transformPreviewFingerprint ||\n      oldDelegate.snapFingerprint != snapFingerprint ||\n",
)

# Regression coverage for all three findings.
Path('test/f10_f11_f13_acceptance_test.dart').write_text(r'''import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/editor_layers.dart';
import 'package:elecx/src/features/editor/component_catalog_session.dart';
import 'package:elecx/src/features/editor/component_transform_session.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_keyboard_scope.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/engineering_placement_cursor_session.dart';
import 'package:elecx/src/features/editor/manual_cable_draft_persistence.dart';
import 'package:elecx/src/features/editor/surface_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('F10 locked electrical layer blocks catalog cursor placement', () {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final entry = controller.componentCatalog
        .forSurface(SurfacePlaneType.wall)
        .first;
    controller.p2.setLayerLocked(EditorLayerId.electrical, true);
    controller.placementCursor.beginCatalogPlacement(entry.id);

    expect(controller.placementCursor.confirm(), isFalse);
    expect(controller.p2.components, isEmpty);
  });

  test('F10 cable layer lock protects connected route and route metadata', () {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final surface = controller.activeSurface!;
    final board = controller.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: surface,
      position: const SurfacePointMm(200, 1000),
    );
    final load = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2800, 1000),
    );
    controller.p2.select(board.id);
    controller.p2.select(load.id, mode: SelectionMode.add);
    expect(
      controller.p2.autoRouteSelectedPair(space: controller.selectedSpace),
      isTrue,
    );
    final route = controller.p2.routes.single;
    controller.p2.setLayerLocked(EditorLayerId.cableRoutes, true);

    expect(controller.p2.toggleRouteSegmentLock(route.id, 0), isFalse);
    controller.p2.select(load.id);
    expect(controller.p2.deleteSelection(), isFalse);
    expect(controller.p2.routes.single.id, route.id);
    expect(controller.p2.components.any((item) => item.id == load.id), isTrue);
  });

  test('F11 manual draft finishes into persistent ElectricalCableRoute', () {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final surface = controller.activeSurface!;
    final board = controller.p2.placeComponent(
      type: ElectricalComponentType.distributionBoard,
      surface: surface,
      position: const SurfacePointMm(200, 1000),
    );
    final load = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(2800, 1000),
    );
    controller.setTool(EditorTool.cableRoute);
    controller.surfaceTap(board.position);
    controller.surfaceTap(const SurfacePointMm(1500, 1000));
    controller.surfaceTap(load.position);

    expect(controller.finishManualCableDraft(endpointSnapRadiusMm: 20), isTrue);
    expect(controller.routeSegments, isEmpty);
    expect(controller.tool, EditorTool.select);
    expect(controller.p2.routes, hasLength(1));
    expect(controller.p2.routes.single.source.componentId, board.id);
    expect(controller.p2.routes.single.target.componentId, load.id);
  });

  testWidgets('F11 first Escape clears manual draft, second exits tool',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    controller.setTool(EditorTool.cableRoute);
    controller.surfaceTap(const SurfacePointMm(200, 1000));
    controller.surfaceTap(const SurfacePointMm(800, 1000));
    await tester.pumpWidget(
      MaterialApp(
        home: EditorKeyboardScope(
          controller: controller,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(controller.routeSegments, isEmpty);
    expect(controller.tool, EditorTool.cableRoute);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(controller.tool, EditorTool.select);
  });

  testWidgets('F13 invalid component target remains visible and uncommitted',
      (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    controller.showWall(1);
    final component = controller.p2.placeComponent(
      type: ElectricalComponentType.socketOutlet,
      surface: controller.activeSurface!,
      position: const SurfacePointMm(1000, 500),
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SurfaceCanvas(controller: controller))),
    );
    await tester.pump();

    expect(controller.componentTransform.begin(), isTrue);
    expect(
      controller.componentTransform.preview(
        const SurfacePointMm(5000, 500),
        isValid: false,
      ),
      isFalse,
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('component-preview-invalid')), findsOneWidget);
    expect(controller.componentTransform.previewState!.position,
        const SurfacePointMm(5000, 500));
    expect(
      controller.p2.components.singleWhere((item) => item.id == component.id).position,
      component.position,
    );
    expect(controller.componentTransform.commit(), isFalse);
    controller.componentTransform.cancel();
    expect(
      controller.p2.components.singleWhere((item) => item.id == component.id).position,
      component.position,
    );
  });
}
''')
