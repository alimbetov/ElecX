import 'package:flutter/foundation.dart';

import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import '../../domain/surface_routing.dart';
import '../../domain/surfaces.dart';

enum EditorTool { select, roomRectangle, guide, cableRoute }

enum EditorViewMode { plan, surface }

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
  RoomSurfaceRef? activeSurface;
  MmPoint? draftStart;
  bool snapEnabled = true;
  bool dimensionsVisible = true;
  int floorGridMm = 500;
  int roomSequence = 102;
  double zoom = 1.0;

  EngineeringSpace? get selectedSpace {
    for (final space in level.spaces) {
      if (space.id == selectedSpaceId) return space;
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

  SurfaceRouteSegmentDraft? get activeRouteSegment {
    final surface = activeSurface;
    if (surface == null || routeSegments.isEmpty) return null;
    final last = routeSegments.last;
    return last.surface == surface ? last : null;
  }

  double get routeLengthMm => routeSegments.fold(
        0.0,
        (sum, segment) => sum + segment.lengthMm,
      );

  void setTool(EditorTool value) {
    tool = value;
    draftStart = null;
    notifyListeners();
  }

  void selectSpace(String? id) {
    selectedSpaceId = id;
    if (id == null || activeSurface?.spaceId != id) {
      activeSurface = null;
      viewMode = EditorViewMode.plan;
    }
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

  MmPoint snap(MmPoint point, {int? stepMm}) {
    if (!snapEnabled) return point;
    final step = stepMm ?? selectedSpace?.grid.minorStepMm ?? 100;
    int round(int value) => (value / step).round() * step;
    return MmPoint(round(point.x), round(point.y));
  }

  SurfacePointMm snapSurfacePoint(SurfacePointMm point, {int? stepMm}) {
    if (!snapEnabled) return point;
    final step = stepMm ?? selectedSpace?.grid.minorStepMm ?? 100;
    int round(int value) => (value / step).round() * step;
    return SurfacePointMm(round(point.xMm), round(point.yMm));
  }

  void showPlan() {
    viewMode = EditorViewMode.plan;
    activeSurface = null;
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

  void _switchSurface(RoomSurfaceRef target) {
    final space = selectedSpace;
    if (space == null) return;

    if (tool == EditorTool.cableRoute &&
        activeSurface != null &&
        routeSegments.isNotEmpty) {
      final lastSegment = routeSegments.last;
      if (lastSegment.surface == activeSurface && lastSegment.points.isNotEmpty) {
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

  void canvasTap(MmPoint rawPoint) {
    final point = snap(rawPoint);
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
    final point = snapSurfacePoint(rawPoint);

    if (routeSegments.isEmpty || routeSegments.last.surface != surface) {
      routeSegments.add(
        SurfaceRouteSegmentDraft(surface: surface, points: [point]),
      );
    } else {
      routeSegments[routeSegments.length - 1] = routeSegments.last.append(point);
    }
    notifyListeners();
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

  void updateSelectedGrid(int minorStepMm) {
    final selected = selectedSpace;
    if (selected == null) return;
    level = level.copyWith(
      spaces: [
        for (final space in level.spaces)
          if (space.id == selected.id)
            space.copyWith(
              grid: space.grid.copyWith(minorStepMm: minorStepMm),
            )
          else
            space,
      ],
    );
    notifyListeners();
  }
}
