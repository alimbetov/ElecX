from pathlib import Path

p = Path('lib/src/features/editor/editor_p2_session.dart')
text = p.read_text()
text = text.replace(
    """      final rerouted = _rerouteForMovedComponent(
        route: route,
        movedComponent: moved,
        role: isSource ? CableEndpointRole.source : CableEndpointRole.target,
        constraints: originState.routeConstraints[route.id] ??
            CableRouteConstraints.empty,
      );""",
    """      final rerouted = _rerouteForMovedComponent(
        route: route,
        movedComponent: moved,
        isSource: isSource,
        constraints: originState.routeConstraints[route.id] ??
            CableRouteConstraints.empty,
      );""",
)
text = text.replace(
    """    final after = state;
    _clearMoveTransaction();
    if (origin == null || componentId == null || !_movePreviewValidState(after)) {
      if (origin != null) _replaceState(origin);
      return false;
    }""",
    """    final after = state;
    final previewValid = _movePreviewValid && _movePreviewValidState(after);
    _clearMoveTransaction();
    if (origin == null || componentId == null || !previewValid) {
      if (origin != null) _replaceState(origin);
      return false;
    }""",
)
text = text.replace(
    """    required ElectricalComponentPlacement movedComponent,
    required CableEndpointRole role,
    required CableRouteConstraints constraints,
  }) {
    if (route.segments.isEmpty) return null;
    final segmentIndex =
        role == CableEndpointRole.source ? 0 : route.segments.length - 1;""",
    """    required ElectricalComponentPlacement movedComponent,
    required bool isSource,
    required CableRouteConstraints constraints,
  }) {
    if (route.segments.isEmpty) return null;
    final segmentIndex = isSource ? 0 : route.segments.length - 1;""",
)
text = text.replace(
    """      if (role == CableEndpointRole.source) {
        points[0] = movedComponent.position;
      } else {""",
    """      if (isSource) {
        points[0] = movedComponent.position;
      } else {""",
)
text = text.replace(
    """    if (role == CableEndpointRole.source) {
      anchors.add(movedComponent.position);""",
    """    if (isSource) {
      anchors.add(movedComponent.position);""",
)
text = text.replace(
    """  bool _movePreviewValidState(EditorP2State preview) {
    if (!_movePreviewValid) return false;
    for (final route in preview.routes) {""",
    """  bool _movePreviewValidState(EditorP2State preview) {
    for (final route in preview.routes) {""",
)
if 'CableEndpointRole' in text:
    raise RuntimeError('CableEndpointRole dependency remains in EditorP2Session')
p.write_text(text)

# Avoid duplicate imports introduced by the staged regression patch.
p = Path('test/component_transform_session_test.dart')
text = p.read_text()
seen = set()
lines = []
for line in text.splitlines():
    if line.startswith('import '):
      if line in seen:
        continue
      seen.add(line)
    lines.append(line)
p.write_text('\n'.join(lines) + '\n')
