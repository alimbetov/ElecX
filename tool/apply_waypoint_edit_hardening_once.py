from pathlib import Path

path = Path('lib/src/features/editor/surface_canvas.dart')
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one match, got {count}')
    text = text.replace(old, new, 1)


replace_once(
    """        if (ui.mode == CableRoutingMode.auto ||
            ui.isSegmentLocked(vertex.route.id, vertex.segmentIndex) ||
            ui.segmentHasWaypoints(vertex.route.id, vertex.segmentIndex)) {
          return false;
        }
        if (!controller.cableRouteEdit.start(
          route: vertex.route,
          segmentIndex: vertex.segmentIndex,
          context: _routeContext(projection),
          mode: ui.mode,
        )) {
""",
    """        if (ui.mode == CableRoutingMode.auto ||
            ui.isSegmentLocked(vertex.route.id, vertex.segmentIndex) ||
            ui.isWaypoint(
              vertex.route.id,
              vertex.segmentIndex,
              vertex.pointIndex,
            )) {
          return false;
        }
        if (!controller.cableRouteEdit.start(
          route: vertex.route,
          segmentIndex: vertex.segmentIndex,
          context: _routeContext(projection),
          mode: ui.mode,
          constraints: controller.p2.routeConstraintsFor(vertex.route.id),
        )) {
""",
    'vertex waypoint guard',
)

replace_once(
    """        if (ui.mode == CableRoutingMode.auto ||
            ui.isSegmentLocked(segment.route.id, segment.segmentIndex) ||
            ui.segmentHasWaypoints(segment.route.id, segment.segmentIndex)) {
          return false;
        }
        if (!controller.cableRouteEdit.start(
          route: segment.route,
          segmentIndex: segment.segmentIndex,
          context: _routeContext(projection),
          mode: ui.mode,
        )) {
""",
    """        if (ui.mode == CableRoutingMode.auto ||
            ui.isSegmentLocked(segment.route.id, segment.segmentIndex)) {
          return false;
        }
        if (!controller.cableRouteEdit.start(
          route: segment.route,
          segmentIndex: segment.segmentIndex,
          context: _routeContext(projection),
          mode: ui.mode,
          constraints: controller.p2.routeConstraintsFor(segment.route.id),
        )) {
""",
    'segment waypoint guard',
)

path.write_text(text)
