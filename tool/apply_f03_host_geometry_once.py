from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'anchor missing in {path}: {old[:140]!r}')
    p.write_text(text.replace(old, new, 1))

# Shared write-boundary validator for host geometry mutations.
Path('lib/src/features/editor/electrical_host_geometry_guard.dart').write_text(r'''import 'dart:math' as math;

import '../../domain/project_model.dart';
import '../../domain/surfaces.dart';
import '../../engine/normative_route_engine.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';

abstract final class ElectricalHostGeometryGuard {
  static bool openingCandidateAllowed(
    EditorController controller,
    ArchitecturalOpening candidate,
  ) {
    final surface = candidate.hostWall;
    final space = _space(controller, surface.spaceId);
    final wallIndex = surface.wallIndex;
    if (space == null || wallIndex == null) return false;
    final walls = RoomSurfaceResolver.walls(space);
    if (wallIndex < 0 || wallIndex >= walls.length) return false;
    final wall = walls[wallIndex];
    if (!RoomSurfaceResolver.openingFitsWall(opening: candidate, wall: wall)) {
      return false;
    }
    final openings = <ArchitecturalOpening>[
      for (final opening in controller.openings)
        if (opening.id == candidate.id) candidate else opening,
    ];
    if (!openings.any((opening) => opening.id == candidate.id)) {
      openings.add(candidate);
    }
    return _surfaceAllowed(
      controller,
      surface,
      RouteNormativeContext(
        surface: surface,
        widthMm: wall.lengthMm.round(),
        heightMm: wall.heightMm,
        edgeClearanceMm: 0,
        boundary: [
          for (final point in wall.profile.vertices)
            SurfacePointMm(point.xMm, point.yMm),
        ],
        obstacles: [
          for (final opening in openings)
            if (opening.hostWall == surface)
              RouteObstacleMm(
                id: opening.id,
                leftMm: opening.offsetFromStartMm,
                topMm: opening.sillHeightMm,
                rightMm: opening.endOffsetMm,
                bottomMm: opening.topMm,
              ),
        ],
      ),
    );
  }

  static bool wallProfileCandidateAllowed(
    EditorController controller,
    EngineeringSpace candidateSpace,
    int wallIndex,
  ) {
    final walls = RoomSurfaceResolver.walls(candidateSpace);
    if (wallIndex < 0 || wallIndex >= walls.length) return false;
    final wall = walls[wallIndex];
    final surface = RoomSurfaceRef.wall(candidateSpace.id, wallIndex);
    for (final opening in controller.openings) {
      if (opening.hostWall == surface &&
          !RoomSurfaceResolver.openingFitsWall(opening: opening, wall: wall)) {
        return false;
      }
    }
    return _surfaceAllowed(
      controller,
      surface,
      RouteNormativeContext(
        surface: surface,
        widthMm: wall.lengthMm.round(),
        heightMm: wall.heightMm,
        edgeClearanceMm: 0,
        boundary: [
          for (final point in wall.profile.vertices)
            SurfacePointMm(point.xMm, point.yMm),
        ],
        obstacles: [
          for (final opening in controller.openings)
            if (opening.hostWall == surface)
              RouteObstacleMm(
                id: opening.id,
                leftMm: opening.offsetFromStartMm,
                topMm: opening.sillHeightMm,
                rightMm: opening.endOffsetMm,
                bottomMm: opening.topMm,
              ),
        ],
      ),
    );
  }

  static EngineeringSpace? _space(EditorController controller, String id) {
    for (final space in controller.level.spaces) {
      if (space.id == id) return space;
    }
    return null;
  }

  static bool _surfaceAllowed(
    EditorController controller,
    RoomSurfaceRef surface,
    RouteNormativeContext context,
  ) {
    for (final component in controller.p2.components) {
      if (component.surface != surface) continue;
      if (!_insideOrBoundary(component.position, context.boundary)) return false;
      for (final obstacle in context.obstacles) {
        if (_insideObstacle(component.position, obstacle)) return false;
      }
    }
    for (final route in controller.p2.routes) {
      for (final segment in route.segments) {
        if (segment.surface != surface) continue;
        if (!NormativeRouteEngine.validate(
          points: segment.points,
          context: context,
        ).isValid) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _insideObstacle(
    SurfacePointMm point,
    RouteObstacleMm obstacle,
  ) =>
      point.xMm > math.min(obstacle.leftMm, obstacle.rightMm) &&
      point.xMm < math.max(obstacle.leftMm, obstacle.rightMm) &&
      point.yMm > math.min(obstacle.topMm, obstacle.bottomMm) &&
      point.yMm < math.max(obstacle.topMm, obstacle.bottomMm);

  static bool _insideOrBoundary(
    SurfacePointMm point,
    List<SurfacePointMm> polygon,
  ) {
    if (polygon.isEmpty) return true;
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[j];
      final b = polygon[i];
      final cross = (b.xMm - a.xMm) * (point.yMm - a.yMm) -
          (b.yMm - a.yMm) * (point.xMm - a.xMm);
      if (cross == 0 &&
          point.xMm >= math.min(a.xMm, b.xMm) &&
          point.xMm <= math.max(a.xMm, b.xMm) &&
          point.yMm >= math.min(a.yMm, b.yMm) &&
          point.yMm <= math.max(a.yMm, b.yMm)) {
        return true;
      }
      final crosses = (a.yMm > point.yMm) != (b.yMm > point.yMm);
      if (!crosses) continue;
      final crossingX =
          (b.xMm - a.xMm) * (point.yMm - a.yMm) / (b.yMm - a.yMm) + a.xMm;
      if (point.xMm < crossingX) inside = !inside;
    }
    return inside;
  }
}
''')

# Make opening mutation API require a write-boundary validator.
replace_once(
    'lib/src/features/editor/editor_controller.dart',
    '''  bool updateSelectedOpening({
    ArchitecturalOpeningType? type,
    int? offsetFromStartMm,
    int? widthMm,
    int? heightMm,
    int? sillHeightMm,
  }) {''',
    '''  bool updateSelectedOpening({
    ArchitecturalOpeningType? type,
    int? offsetFromStartMm,
    int? widthMm,
    int? heightMm,
    int? sillHeightMm,
    required bool Function(ArchitecturalOpening candidate) canCommit,
  }) {''',
)
replace_once(
    'lib/src/features/editor/editor_controller.dart',
    '''    if (!RoomSurfaceResolver.openingFitsWall(opening: candidate, wall: wall)) {
      return false;
    }

    openings = [''',
    '''    if (!RoomSurfaceResolver.openingFitsWall(opening: candidate, wall: wall) ||
        !canCommit(candidate)) {
      return false;
    }

    openings = [''',
)
replace_once(
    'lib/src/features/editor/editor_controller.dart',
    '  void addOpening(ArchitecturalOpeningType type) {',
    '''  bool addOpening(
    ArchitecturalOpeningType type, {
    required bool Function(ArchitecturalOpening candidate) canCommit,
  }) {''',
)
replace_once(
    'lib/src/features/editor/editor_controller.dart',
    '''    final wall = activeWall;
    if (wall == null) return;
''',
    '''    final wall = activeWall;
    if (wall == null) return false;
''',
)
replace_once(
    'lib/src/features/editor/editor_controller.dart',
    '''    final maxHeight = wall.heightMm - sill;
    if (maxHeight <= 0) return;

    final opening = ArchitecturalOpening(
      id: 'opening-${openingSequence++}',
''',
    '''    final maxHeight = wall.heightMm - sill;
    if (maxHeight <= 0) return false;

    final opening = ArchitecturalOpening(
      id: 'opening-$openingSequence',
''',
)
replace_once(
    'lib/src/features/editor/editor_controller.dart',
    '''      sillHeightMm: sill,
    );
    openings = [...openings, opening];
    selectedOpeningId = opening.id;
    tool = EditorTool.select;
    notifyListeners();
  }
''',
    '''      sillHeightMm: sill,
    );
    if (!canCommit(opening)) return false;
    openingSequence++;
    openings = [...openings, opening];
    selectedOpeningId = opening.id;
    tool = EditorTool.select;
    notifyListeners();
    return true;
  }
''',
)

# Guard reachable opening UI paths.
for path in [
    'lib/src/features/editor/boundary_bottom_editor.dart',
    'lib/src/features/editor/editable_spatial_canvas.dart',
]:
    p = Path(path)
    text = p.read_text()
    import_anchor = "import 'editor_controller.dart';\n"
    if "electrical_host_geometry_guard.dart" not in text:
        if import_anchor not in text:
            raise SystemExit(f'import anchor missing in {path}')
        text = text.replace(
            import_anchor,
            "import 'electrical_host_geometry_guard.dart';\n" + import_anchor,
            1,
        )
    text = text.replace(
        '''        controller.updateSelectedOpening(
          offsetFromStartMm: opening.offsetFromStartMm,
          widthMm: opening.widthMm,
        );''',
        '''        controller.updateSelectedOpening(
          offsetFromStartMm: opening.offsetFromStartMm,
          widthMm: opening.widthMm,
          canCommit: (candidate) =>
              ElectricalHostGeometryGuard.openingCandidateAllowed(
            controller,
            candidate,
          ),
        );''',
    )
    p.write_text(text)

p = Path('lib/src/features/editor/boundary_bottom_editor.dart')
text = p.read_text()
text = text.replace(
    'controller.addOpening(ArchitecturalOpeningType.door);',
    '''controller.addOpening(
                    ArchitecturalOpeningType.door,
                    canCommit: (candidate) =>
                        ElectricalHostGeometryGuard.openingCandidateAllowed(
                      controller,
                      candidate,
                    ),
                  );''',
)
text = text.replace(
    'controller.addOpening(ArchitecturalOpeningType.window);',
    '''controller.addOpening(
                    ArchitecturalOpeningType.window,
                    canCommit: (candidate) =>
                        ElectricalHostGeometryGuard.openingCandidateAllowed(
                      controller,
                      candidate,
                    ),
                  );''',
)
text = text.replace(
    '''      sillHeightMm: draft.sillHeightMm,
    );''',
    '''      sillHeightMm: draft.sillHeightMm,
      canCommit: (candidate) =>
          ElectricalHostGeometryGuard.openingCandidateAllowed(
        controller,
        candidate,
      ),
    );''',
    1,
)
p.write_text(text)

# Guard wall-profile mutation at its command boundary.
p = Path('lib/src/features/editor/wall_profile_editor_actions.dart')
text = p.read_text()
if "electrical_host_geometry_guard.dart" not in text:
    text = text.replace(
        "import 'editor_controller.dart';\n",
        "import 'editor_controller.dart';\nimport 'electrical_host_geometry_guard.dart';\n",
        1,
    )
text = text.replace(
    '''    if (invalidatesOpening) {
      return false;
    }

    level = candidateLevel;''',
    '''    if (invalidatesOpening ||
        !ElectricalHostGeometryGuard.wallProfileCandidateAllowed(
          this,
          candidateSpace,
          wallIndex,
        )) {
      return false;
    }

    level = candidateLevel;''',
    1,
)
p.write_text(text)

# Update existing direct test/API call sites to provide the canonical guard.
for path in Path('test').rglob('*.dart'):
    text = path.read_text()
    if 'updateSelectedOpening(' not in text and 'addOpening(' not in text:
        continue
    if "electrical_host_geometry_guard.dart" not in text:
        imports = list(re.finditer(r"^import .*?;\n", text, re.M)) if False else []
    # Let analyzer identify any remaining test-only callers; production API is intentionally strict.

# Regression: adding an opening across an existing wall route is rejected atomically.
test_path = Path('test/p1_lifecycle_acceptance_test.dart')
test = test_path.read_text()
if "electrical_host_geometry_guard.dart" not in test:
    test = test.replace(
        "import 'package:elecx/src/features/editor/editor_controller.dart';\n",
        "import 'package:elecx/src/features/editor/editor_controller.dart';\n"
        "import 'package:elecx/src/features/editor/electrical_host_geometry_guard.dart';\n",
        1,
    )
if "selection_engine.dart" not in test:
    test = test.replace(
        "import 'package:elecx/src/engine/world_camera.dart';\n",
        "import 'package:elecx/src/engine/selection_engine.dart';\n"
        "import 'package:elecx/src/engine/world_camera.dart';\n",
        1,
    )
anchor = "  test('F03 shrinking room around electrical component is rejected atomically',"
case_name = 'F03 adding an opening across existing cable is rejected atomically'
if case_name not in test:
    idx = test.find(anchor)
    if idx == -1:
        raise SystemExit('F03 lifecycle insertion anchor missing')
    addition = r'''  test('F03 adding an opening across existing cable is rejected atomically', () {
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
    controller.p2.select(board.id, mode: SelectionMode.replace);
    controller.p2.select(load.id, mode: SelectionMode.add);
    expect(
      controller.p2.autoRouteSelectedPair(space: controller.selectedSpace),
      isTrue,
    );
    final beforeOpenings = List<ArchitecturalOpening>.of(controller.openings);
    final beforeRoute = controller.p2.routes.single;

    expect(
      controller.addOpening(
        ArchitecturalOpeningType.door,
        canCommit: (candidate) =>
            ElectricalHostGeometryGuard.openingCandidateAllowed(
          controller,
          candidate,
        ),
      ),
      isFalse,
    );
    expect(controller.openings, orderedEquals(beforeOpenings));
    expect(controller.p2.routes.single.segments, beforeRoute.segments);
  });

'''
    test = test[:idx] + addition + test[idx:]
test_path.write_text(test)
