from pathlib import Path

path = Path('lib/src/features/editor/surface_canvas.dart')
text = path.read_text()
old = """                child: CableRouteControls(
                  mode: controller.cableUi.mode,
                  onModeChanged: controller.cableUi.setMode,
                  segmentFocused: controller.cableUi.activeSegmentIndex != null,
                  segmentLocked: controller.cableUi.activeSegmentLocked,
                  onToggleSegmentLock:
                      controller.cableUi.toggleActiveSegmentLock,
                  pointFocused: controller.cableUi.activePointIndex != null,
                  pointIsWaypoint: controller.cableUi.activePointIsWaypoint,
                  onToggleWaypoint: _toggleActiveWaypoint,
                ),
"""
new = """                child: CableRouteControls(
                  mode: controller.cableUi.mode,
                  onModeChanged: controller.cableUi.setMode,
                  segmentFocused: controller.cableUi.activeSegmentIndex != null,
                  segmentLocked: controller.cableUi.activeSegmentLocked,
                  onToggleSegmentLock:
                      controller.cableUi.toggleActiveSegmentLock,
                  pointFocused: controller.cableUi.activePointIndex != null,
                  pointIsWaypoint: controller.cableUi.activePointIsWaypoint,
                  onToggleWaypoint: _toggleActiveWaypoint,
                  validation:
                      controller.cableEndpointTransform.previewState?.validation ??
                      controller.cableRouteEdit.previewState?.validation,
                  previewInvalid: controller.cableEndpointTransform.active &&
                      controller.cableEndpointTransform.previewState == null,
                ),
"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'Expected one CableRouteControls block, found {count}')
text = text.replace(old, new, 1)

old_vertex_guard = """        if (ui.mode == CableRoutingMode.auto ||
            ui.isSegmentLocked(vertex.route.id, vertex.segmentIndex) ||
            ui.isWaypoint(
                vertex.route.id, vertex.segmentIndex, vertex.pointIndex)) {
          return false;
        }
"""
new_vertex_guard = """        if (ui.mode == CableRoutingMode.auto ||
            ui.isSegmentLocked(vertex.route.id, vertex.segmentIndex) ||
            ui.segmentHasWaypoints(vertex.route.id, vertex.segmentIndex)) {
          return false;
        }
"""
count = text.count(old_vertex_guard)
if count != 1:
    raise SystemExit(f'Expected one vertex waypoint guard, found {count}')
text = text.replace(old_vertex_guard, new_vertex_guard, 1)
path.write_text(text)
