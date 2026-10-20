import 'package:flutter/foundation.dart';

import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import '../../domain/surface_navigation.dart';
import '../../domain/surface_routing.dart';
import '../../domain/surfaces.dart';
import '../../engine/normative_route_engine.dart';
import '../../engine/snap_engine.dart';

enum EditorTool { select, roomRectangle, guide, cableRoute }

enum EditorViewMode { plan, roomWorld, surface }

final class EditorController extends ChangeNotifier {
  EditorController.demo()
      : level = BuildingLevel(
          id: 'level-1',
          name: 'Этаж 1',
          elevationMm: 0,
          spaces: [
            _room(
              'room-101',
              'Комната 101',
              const MmPoint(1000, 1200),
              const MmPoint(5200, 4400),
            ),
            _room(
              'corridor-1',
              'Коридор',
              const MmPoint(1000, 4600),
              const MmPoint(9800, 5900),
              type: SpaceType.corridor,
            ),
          ],
        ) {
    selectedSpaceId = 'room-101';
    openings = [
      ArchitecturalOpening(
        id: 'door-101-a',
        hostWall: RoomSurfaceRef.wall('room-101', 0),
        type: ArchitecturalOpeningType.door,
        offsetFromStartMm: 650,
        widthMm: 900,
        heightMm: 2100,
        sillHeightMm: 0,
      ),
      ArchitecturalOpening(
        id: 'window-101-a',
        hostWall: RoomSurfaceRef.wall('room-101', 2),
        type: ArchitecturalOpeningType.window,
        offsetFromStartMm: 1150,
        widthMm: 1600,
        heightMm: 1400,
        sillHeightMm: 900,
      ),
    ];
  }

  EditorController.blank({
    String levelId = 'level-1',
    String levelName = 'Этаж 1',
  }) : level = BuildingLevel(
          id: levelId,
          name: levelName,
          elevationMm: 0,
          spaces: const [],
        ) {
    openings = <ArchitecturalOpening>[];
    roomSequence = 1;
    openingSequence = 1;
    selectedSpaceId = null;
    selectedOpeningId = null;
    activeSurface = null;
    viewMode = EditorViewMode.plan;
    tool = EditorTool.select;
  }

  EditorController.restored({
    required this.level,
    required List<ArchitecturalOpening> openings,
  }) {
    this.openings = List<ArchitecturalOpening>.of(openings);
  }

  void restoreResumeState({
    required String? selectedSpaceId,
    required String? selectedOpeningId,
    required RoomSurfaceRef? activeSurface,
    required EditorViewMode viewMode,
    required bool snapEnabled,
    required bool dimensionsVisible,
    required int floorGridMm,
    required double zoom,
    required int roomSequence,
    required int openingSequence,
  }) {
    if (selectedSpaceId != null &&
        !level.spaces.any((space) => space.id == selectedSpaceId)) {
      throw ArgumentError('Restored selected space does not exist.');
    }
    if (selectedOpeningId != null &&
        !openings.any((opening) => opening.id == selectedOpeningId)) {
      throw ArgumentError('Restored selected opening does not exist.');
    }
    if (activeSurface != null &&
        !level.spaces.any((space) => space.id == activeSurface.spaceId)) {
      throw ArgumentError('Restored active surface references unknown space.');
    }
    if (floorGridMm <= 0 || roomSequence <= 0 || openingSequence <= 0) {
      throw ArgumentError('Restored editor counters/grid are invalid.');
    }
    this.selectedSpaceId = selectedSpaceId;
    this.selectedOpeningId = selectedOpeningId;
    this.activeSurface = activeSurface;
    this.viewMode = viewMode;
    tool = EditorTool.select;
    draftStart = null;
    routeSegments.clear();
    this.snapEnabled = snapEnabled;
    this.dimensionsVisible = dimensionsVisible;
    this.floorGridMm = floorGridMm;
    this.zoom = zoom.clamp(0.35, 6.0).toDouble();
    this.roomSequence = roomSequence;
    this.openingSequence = openingSequence;
  }

  static EngineeringSpace _room(
    String id,
    String name,
    MmPoint a,
    MmPoint b, {
    SpaceType type = SpaceType.room,
  }) {
    final boundary = MmPolygon.rectangle(a, b);
    return EngineeringSpace(
      id: id,
      name: name,
      type: type,
      boundary: boundary,
      referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
    );
  }

  BuildingLevel level;
  late List<ArchitecturalOpening> openings;
  final List<SurfaceRouteSegmentDraft> routeSegments = [];
  EditorTool tool = EditorTool.select;
  EditorViewMode viewMode = EditorViewMode.plan;
  String? selectedSpaceId;
  String? selectedOpeningId;
  RoomSurfaceRef? activeSurface;
  MmPoint? draftStart;
  bool snapEnabled = true;
  bool dimensionsVisible = true;
  int floorGridMm = 500;
  int roomSequence = 102;
  int openingSequence = 1;
  double zoom = 1.0;
  final ValueNotifier<int> _editCancellationRevision = ValueNotifier<int>(0);

  ValueListenable<int> get editCancellationListenable =>
      _editCancellationRevision;

  void requestEditCancellation() {
    _editCancellationRevision.value++;
  }

  EngineeringSpace? get selectedSpace {
    for (final space in level.spaces) {
      if (space.id == selectedSpaceId) return space;
    }
    return null;
  }

  ArchitecturalOpening? get selectedOpening {
    final id = selectedOpeningId;
    if (id == null) return null;
    for (final opening in openings) {
      if (opening.id == id) return opening;
    }
    return null;
  }

  List<RoomWallSurface> get selectedWalls {
    final space = selectedSpace;
    if (space == null) return const [];
    return RoomSurfaceResolver.walls(space);
  }

  RoomWallSurface? get activeWall {
    final surface = activeSurface;
    final space = selectedSpace;
    if (surface == null ||
        space == null ||
        surface.type != SurfacePlaneType.wall ||
        surface.wallIndex == null) {
      return null;
    }
    return RoomSurfaceResolver.wall(space, surface.wallIndex!);
  }

  List<ArchitecturalOpening> get activeWallOpenings {
    final surface = activeSurface;
    if (surface == null) return const [];
    return openings
        .where((opening) => opening.hostWall == surface)
        .toList(growable: false);
  }

  RouteNormativeContext? routeNormativeContextFor(RoomSurfaceRef surface) {
    EngineeringSpace? space;
    for (final candidate in level.spaces) {
      if (candidate.id == surface.spaceId) {
        space = candidate;
        break;
      }
    }
    if (space == null) return null;

    if (surface.type == SurfacePlaneType.wall) {
      final wallIndex = surface.wallIndex;
      if (wallIndex == null) return null;
      final wall = RoomSurfaceResolver.wall(space, wallIndex);
      return RouteNormativeContext(
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
      );
    }

    final bounds = space.boundary.bounds;
    return RouteNormativeContext(
      surface: surface,
      widthMm: bounds.width,
      heightMm: bounds.height,
      edgeClearanceMm: 0,
      boundary: [
        for (final point in space.boundary.vertices)
          SurfacePointMm(point.x - bounds.left, point.y - bounds.bottom),
      ],
    );
  }

  SurfaceRouteSegmentDraft? get activeRouteSegment {
    final surface = activeSurface;
    if (surface == null || routeSegments.isEmpty) return null;
    final last = routeSegments.last;
    return last.surface == surface ? last : null;
  }

  SurfacePointMm? get routeDraftStart {
    final segment = activeRouteSegment;
    if (segment == null || segment.points.isEmpty) return null;
    return segment.points.last;
  }

  double get routeLengthMm =>
      routeSegments.fold(0.0, (sum, segment) => sum + segment.lengthMm);

  void setTool(EditorTool value) {
    requestEditCancellation();
    tool = value;
    draftStart = null;
    notifyListeners();
  }

  void selectSpace(String? id) {
    requestEditCancellation();
    selectedSpaceId = id;
    selectedOpeningId = null;
    if (id == null || activeSurface?.spaceId != id) {
      activeSurface = null;
      viewMode = EditorViewMode.plan;
    }
    notifyListeners();
  }

  void enterRoomWorld([String? spaceId]) {
    final id = spaceId ?? selectedSpaceId;
    if (id == null || !level.spaces.any((space) => space.id == id)) return;
    requestEditCancellation();
    selectedSpaceId = id;
    selectedOpeningId = null;
    activeSurface = null;
    viewMode = EditorViewMode.roomWorld;
    tool = EditorTool.select;
    notifyListeners();
  }

  void showRoomWorld() {
    if (selectedSpace == null) return;
    requestEditCancellation();
    selectedOpeningId = null;
    activeSurface = null;
    viewMode = EditorViewMode.roomWorld;
    notifyListeners();
  }

  void selectOpening(String? id) {
    requestEditCancellation();
    selectedOpeningId = id;
    final opening = selectedOpening;
    if (opening != null) {
      selectedSpaceId = opening.hostWall.spaceId;
      activeSurface = opening.hostWall;
      viewMode = EditorViewMode.surface;
      tool = EditorTool.select;
    }
    notifyListeners();
  }

  bool updateSelectedOpening({
    ArchitecturalOpeningType? type,
    int? offsetFromStartMm,
    int? widthMm,
    int? heightMm,
    int? sillHeightMm,
    required bool Function(ArchitecturalOpening candidate) canCommit,
  }) {
    final current = selectedOpening;
    final wall = activeWall;
    if (current == null || wall == null || current.hostWall != wall.ref) {
      return false;
    }

    ArchitecturalOpening candidate;
    try {
      candidate = current.copyWith(
        type: type,
        offsetFromStartMm: offsetFromStartMm,
        widthMm: widthMm,
        heightMm: heightMm,
        sillHeightMm: sillHeightMm,
      );
    } on ArgumentError {
      return false;
    }

    if (!RoomSurfaceResolver.openingFitsWall(opening: candidate, wall: wall) ||
        !canCommit(candidate)) {
      return false;
    }

    openings = [
      for (final opening in openings)
        if (opening.id == candidate.id) candidate else opening,
    ];
    notifyListeners();
    return true;
  }

  bool addOpening(
    ArchitecturalOpeningType type, {
    required bool Function(ArchitecturalOpening candidate) canCommit,
  }) {
    final wall = activeWall;
    if (wall == null) return false;

    final defaultWidth = type == ArchitecturalOpeningType.window ? 1200 : 900;
    final defaultHeight = type == ArchitecturalOpeningType.window ? 1400 : 2100;
    final sill = type == ArchitecturalOpeningType.window ? 900 : 0;
    final wallLength = wall.lengthMm.round();
    final width = defaultWidth.clamp(300, wallLength).toInt();
    final offset =
        ((wallLength - width) / 2).round().clamp(0, wallLength - width).toInt();
    final maxHeight = wall.heightMm - sill;
    if (maxHeight <= 0) return false;

    final opening = ArchitecturalOpening(
      id: 'opening-$openingSequence',
      hostWall: wall.ref,
      type: type,
      offsetFromStartMm: offset,
      widthMm: width,
      heightMm: defaultHeight.clamp(300, maxHeight).toInt(),
      sillHeightMm: sill,
    );
    if (!canCommit(opening)) return false;
    openingSequence++;
    openings = [...openings, opening];
    selectedOpeningId = opening.id;
    tool = EditorTool.select;
    notifyListeners();
    return true;
  }

  void deleteSelectedOpening() {
    final id = selectedOpeningId;
    if (id == null) return;
    openings = openings.where((opening) => opening.id != id).toList();
    selectedOpeningId = null;
    notifyListeners();
  }

  void setSnapEnabled(bool value) {
    snapEnabled = value;
    notifyListeners();
  }

  void setDimensionsVisible(bool value) {
    dimensionsVisible = value;
    notifyListeners();
  }

  void setZoom(double value) {
    zoom = value < 0.35
        ? 0.35
        : value > 6.0
            ? 6.0
            : value;
    notifyListeners();
  }

  void zoomIn() => setZoom(zoom * 1.25);

  void zoomOut() => setZoom(zoom / 1.25);

  void resetZoom() => setZoom(1.0);

  SnapCandidate? resolvePlanSnap(
    MmPoint point, {
    int? stepMm,
    double acquisitionRadiusMm = 80,
  }) {
    if (!snapEnabled) return null;
    if (acquisitionRadiusMm <= 0) {
      throw ArgumentError.value(
        acquisitionRadiusMm,
        'acquisitionRadiusMm',
        'Must be positive.',
      );
    }
    final step = stepMm ?? selectedSpace?.grid.minorStepMm ?? 100;
    final radius = acquisitionRadiusMm.ceil();
    final left = point.x - radius;
    final right = point.x + radius;
    final bottom = point.y - radius;
    final top = point.y + radius;
    final segments = <SnapSegment>[];
    for (final space in level.spaces) {
      final bounds = space.boundary.bounds;
      final outside = bounds.right < left ||
          bounds.left > right ||
          bounds.top < bottom ||
          bounds.bottom > top;
      if (outside) continue;
      final vertices = space.boundary.vertices;
      for (var i = 0; i < vertices.length; i++) {
        segments.add(
          SnapSegment(
            id: '${space.id}:edge:$i',
            a: vertices[i],
            b: vertices[(i + 1) % vertices.length],
          ),
        );
      }
    }
    return SnapEngine.resolve(
      SnapRequest(
        rawPoint: point,
        acquisitionRadiusMm: acquisitionRadiusMm,
        gridStepMm: step,
        segments: segments,
      ),
    );
  }

  MmPoint snap(MmPoint point, {int? stepMm, double acquisitionRadiusMm = 80}) {
    if (!snapEnabled) return point;
    return resolvePlanSnap(
          point,
          stepMm: stepMm,
          acquisitionRadiusMm: acquisitionRadiusMm,
        )?.point ??
        point;
  }

  SurfacePointMm snapSurfacePoint(SurfacePointMm point, {int? stepMm}) {
    if (!snapEnabled) return point;
    final step = stepMm ?? selectedSpace?.grid.minorStepMm ?? 100;
    int round(int value) => (value / step).round() * step;
    return SurfacePointMm(round(point.xMm), round(point.yMm));
  }

  void showPlan() {
    requestEditCancellation();
    viewMode = EditorViewMode.plan;
    activeSurface = null;
    selectedOpeningId = null;
    notifyListeners();
  }

  void showFloor() {
    final space = selectedSpace;
    if (space == null) return;
    _switchSurface(RoomSurfaceRef.floor(space.id));
  }

  void showCeiling() {
    final space = selectedSpace;
    if (space == null) return;
    _switchSurface(RoomSurfaceRef.ceiling(space.id));
  }

  void showWall(int wallIndex) {
    final space = selectedSpace;
    if (space == null ||
        wallIndex < 0 ||
        wallIndex >= space.boundary.vertices.length) {
      return;
    }
    _switchSurface(RoomSurfaceRef.wall(space.id, wallIndex));
  }

  void navigateWallEdge(WallNavigationEdge edge, SurfacePointMm point) {
    final space = selectedSpace;
    final wall = activeWall;
    if (space == null || wall == null) return;

    if (tool == EditorTool.cableRoute) {
      _appendRoutePoint(point);
    }
    final target = SurfaceNavigationResolver.targetForWallEdge(
      space: space,
      wallIndex: wall.ref.wallIndex!,
      edge: edge,
    );
    _switchSurface(target);
  }

  void navigateHorizontalBoundary(int boundaryEdgeIndex, SurfacePointMm point) {
    final space = selectedSpace;
    final surface = activeSurface;
    if (space == null ||
        surface == null ||
        surface.type == SurfacePlaneType.wall) {
      return;
    }

    if (tool == EditorTool.cableRoute) {
      _appendRoutePoint(point);
    }
    final target = SurfaceNavigationResolver.targetForHorizontalBoundary(
      space: space,
      boundaryEdgeIndex: boundaryEdgeIndex,
    );
    _switchSurface(target);
  }

  void _switchSurface(RoomSurfaceRef target) {
    final space = selectedSpace;
    if (space == null) return;
    requestEditCancellation();

    selectedOpeningId = null;
    if (tool == EditorTool.cableRoute &&
        activeSurface != null &&
        routeSegments.isNotEmpty) {
      final lastSegment = routeSegments.last;
      if (lastSegment.surface == activeSurface &&
          lastSegment.points.isNotEmpty) {
        final mapped = SurfaceTransitionResolver.mapPoint(
          space: space,
          from: activeSurface!,
          point: lastSegment.points.last,
          to: target,
        );
        if (mapped != null) {
          routeSegments.add(
            SurfaceRouteSegmentDraft(surface: target, points: [mapped]),
          );
        }
      }
    }

    viewMode = EditorViewMode.surface;
    activeSurface = target;
    notifyListeners();
  }

  void previousWall() {
    final space = selectedSpace;
    if (space == null) return;
    final count = space.boundary.vertices.length;
    final current = activeSurface?.wallIndex ?? 0;
    showWall((current - 1 + count) % count);
  }

  void nextWall() {
    final space = selectedSpace;
    if (space == null) return;
    final count = space.boundary.vertices.length;
    final current = activeSurface?.wallIndex ?? -1;
    showWall((current + 1) % count);
  }

  void canvasTap(MmPoint rawPoint, {double? snapRadiusMm}) {
    final point = snap(rawPoint, acquisitionRadiusMm: snapRadiusMm ?? 80);
    switch (tool) {
      case EditorTool.select:
        selectAt(point);
      case EditorTool.roomRectangle:
        if (draftStart == null) {
          draftStart = point;
          notifyListeners();
        } else {
          addRectangleRoom(draftStart!, point);
          draftStart = null;
          tool = EditorTool.select;
          notifyListeners();
        }
      case EditorTool.guide:
        draftStart = point;
        notifyListeners();
      case EditorTool.cableRoute:
        draftStart = point;
        notifyListeners();
    }
  }

  void surfaceTap(SurfacePointMm rawPoint) {
    final surface = activeSurface;
    if (tool != EditorTool.cableRoute || surface == null) return;
    _appendRoutePoint(snapSurfacePoint(rawPoint));
    notifyListeners();
  }

  void _appendRoutePoint(SurfacePointMm point) {
    final surface = activeSurface;
    if (surface == null) return;
    if (routeSegments.isEmpty || routeSegments.last.surface != surface) {
      routeSegments.add(
        SurfaceRouteSegmentDraft(surface: surface, points: [point]),
      );
    } else {
      routeSegments[routeSegments.length - 1] = routeSegments.last.append(
        point,
      );
    }
  }

  void clearRouteDraft() {
    routeSegments.clear();
    notifyListeners();
  }

  void selectAt(MmPoint point) {
    for (final space in level.spaces.reversed) {
      if (space.boundary.contains(point)) {
        selectSpace(space.id);
        return;
      }
    }
    selectSpace(null);
  }

  void addRectangleRoom(MmPoint a, MmPoint b) {
    if ((a.x - b.x).abs() < 300 || (a.y - b.y).abs() < 300) return;
    final boundary = MmPolygon.rectangle(a, b);
    final id = 'room-$roomSequence';
    final room = EngineeringSpace(
      id: id,
      name: 'Комната $roomSequence',
      type: SpaceType.room,
      boundary: boundary,
      referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
    );
    roomSequence += 1;
    level = level.copyWith(spaces: [...level.spaces, room]);
    selectedSpaceId = id;
  }

  void restoreDocumentArchitecture({
    required BuildingLevel level,
    required List<ArchitecturalOpening> openings,
    required int roomSequence,
    required int openingSequence,
    String? selectedSpaceId,
    String? selectedOpeningId,
  }) {
    requestEditCancellation();
    this.level = level;
    this.openings = List<ArchitecturalOpening>.of(openings);
    this.roomSequence = roomSequence;
    this.openingSequence = openingSequence;
    this.selectedSpaceId = selectedSpaceId != null &&
            level.spaces.any((space) => space.id == selectedSpaceId)
        ? selectedSpaceId
        : null;
    this.selectedOpeningId = selectedOpeningId != null &&
            this.openings.any((opening) => opening.id == selectedOpeningId)
        ? selectedOpeningId
        : null;
    activeSurface = null;
    viewMode = EditorViewMode.plan;
    tool = EditorTool.select;
    draftStart = null;
    routeSegments.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _editCancellationRevision.dispose();
    super.dispose();
  }

  void updateSelectedGrid(int minorStepMm) {
    final selected = selectedSpace;
    if (selected == null) return;
    level = level.copyWith(
      spaces: [
        for (final space in level.spaces)
          if (space.id == selected.id)
            space.copyWith(grid: space.grid.copyWith(minorStepMm: minorStepMm))
          else
            space,
      ],
    );
    notifyListeners();
  }
}
