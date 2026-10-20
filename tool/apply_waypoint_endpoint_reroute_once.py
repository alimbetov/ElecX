from pathlib import Path

path = Path('lib/src/features/editor/surface_canvas.dart')
text = path.read_text()

old_guard = """        if (ui.isSegmentLocked(endpoint.route.id, endpoint.segmentIndex) ||
            ui.segmentHasWaypoints(endpoint.route.id, endpoint.segmentIndex)) {
          return false;
        }
"""
new_guard = """        if (ui.isSegmentLocked(endpoint.route.id, endpoint.segmentIndex)) {
          return false;
        }
"""
if text.count(old_guard) != 1:
    raise SystemExit('endpoint waypoint guard anchor mismatch')
text = text.replace(old_guard, new_guard, 1)

old_start = """          components: controller.p2.components,
          context: _routeContext(projection),
        )) {
"""
new_start = """          components: controller.p2.components,
          context: _routeContext(projection),
          constraints: controller.p2.routeConstraintsFor(endpoint.route.id),
        )) {
"""
if text.count(old_start) != 1:
    raise SystemExit('endpoint session start anchor mismatch')
text = text.replace(old_start, new_start, 1)

path.write_text(text)
