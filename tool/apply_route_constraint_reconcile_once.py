from pathlib import Path

path = Path('lib/src/features/editor/editor_p2_session.dart')
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one match, got {count}')
    text = text.replace(old, new, 1)


replace_once(
    """  bool replaceCableRoute(
    ElectricalCableRoute before,
    ElectricalCableRoute after,
  ) {
    if (before.id != after.id || layers.isLocked(EditorLayerId.cableRoutes)) {
      return false;
    }
    if (!routes.any((route) => route.id == before.id)) return false;
    if (!ElectricalConnectivityValidator.routeIsConnected(
      route: after,
      components: components,
    )) {
      return false;
    }
    history.execute(_ReplaceCableRouteCommand(before: before, after: after));
    notifyListeners();
    return true;
  }
""",
    """  bool replaceCableRoute(
    ElectricalCableRoute before,
    ElectricalCableRoute after,
  ) {
    if (before.id != after.id || layers.isLocked(EditorLayerId.cableRoutes)) {
      return false;
    }
    if (!routes.any((route) => route.id == before.id)) return false;
    if (!ElectricalConnectivityValidator.routeIsConnected(
      route: after,
      components: components,
    )) {
      return false;
    }
    final beforeConstraints = routeConstraintsFor(before.id);
    final afterConstraints = beforeConstraints.reconcile([
      for (final segment in after.segments) segment.points,
    ]);
    history.execute(
      _ReplaceCableRouteCommand(
        before: before,
        after: after,
        beforeConstraints: beforeConstraints,
        afterConstraints: afterConstraints,
      ),
    );
    notifyListeners();
    return true;
  }
""",
    'replaceCableRoute',
)

replace_once(
    """final class _ReplaceCableRouteCommand implements EditorCommand<EditorP2State> {
  const _ReplaceCableRouteCommand({required this.before, required this.after});

  final ElectricalCableRoute before;
  final ElectricalCableRoute after;

  @override
  String get label => 'Edit cable route';

  @override
  EditorP2State execute(EditorP2State state) =>
      _replace(state, before.id, after);

  @override
  EditorP2State undo(EditorP2State state) => _replace(state, after.id, before);

  static EditorP2State _replace(
    EditorP2State state,
    String routeId,
    ElectricalCableRoute replacement,
  ) =>
      state.copyWith(
        routes: [
          for (final route in state.routes)
            if (route.id == routeId) replacement else route,
        ],
      );
}
""",
    """final class _ReplaceCableRouteCommand implements EditorCommand<EditorP2State> {
  const _ReplaceCableRouteCommand({
    required this.before,
    required this.after,
    required this.beforeConstraints,
    required this.afterConstraints,
  });

  final ElectricalCableRoute before;
  final ElectricalCableRoute after;
  final CableRouteConstraints beforeConstraints;
  final CableRouteConstraints afterConstraints;

  @override
  String get label => 'Edit cable route';

  @override
  EditorP2State execute(EditorP2State state) => _replace(
        state,
        before.id,
        after,
        afterConstraints,
      );

  @override
  EditorP2State undo(EditorP2State state) => _replace(
        state,
        after.id,
        before,
        beforeConstraints,
      );

  static EditorP2State _replace(
    EditorP2State state,
    String routeId,
    ElectricalCableRoute replacement,
    CableRouteConstraints constraints,
  ) {
    final nextConstraints = Map<String, CableRouteConstraints>.of(
      state.routeConstraints,
    );
    if (constraints.isEmpty) {
      nextConstraints.remove(routeId);
    } else {
      nextConstraints[routeId] = constraints;
    }
    return state.copyWith(
      routes: [
        for (final route in state.routes)
          if (route.id == routeId) replacement else route,
      ],
      routeConstraints: Map.unmodifiable(nextConstraints),
    );
  }
}
""",
    'replace route command',
)

path.write_text(text)
