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
path.write_text(text.replace(old, new, 1))
