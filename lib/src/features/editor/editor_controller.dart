import 'package:flutter/foundation.dart';

import '../../domain/geometry.dart';
import '../../domain/project_model.dart';

enum EditorTool { select, roomRectangle, guide }

final class EditorController extends ChangeNotifier {
  EditorController.demo()
      : level = BuildingLevel(
          id: 'level-1',
          name: 'Этаж 1',
          elevationMm: 0,
          spaces: [
            _room('room-101', 'Комната 101', const MmPoint(1000, 1200), const MmPoint(5200, 4400)),
            _room('corridor-1', 'Коридор', const MmPoint(1000, 4600), const MmPoint(9800, 5900), type: SpaceType.corridor),
          ],
        ) {
    selectedSpaceId = 'room-101';
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
  EditorTool tool = EditorTool.select;
  String? selectedSpaceId;
  MmPoint? draftStart;
  bool snapEnabled = true;
  int floorGridMm = 500;
  int roomSequence = 102;

  EngineeringSpace? get selectedSpace {
    for (final space in level.spaces) {
      if (space.id == selectedSpaceId) return space;
    }
    return null;
  }

  void setTool(EditorTool value) {
    tool = value;
    draftStart = null;
    notifyListeners();
  }

  void setSnapEnabled(bool value) {
    snapEnabled = value;
    notifyListeners();
  }

  MmPoint snap(MmPoint point, {int? stepMm}) {
    if (!snapEnabled) return point;
    final step = stepMm ?? selectedSpace?.grid.minorStepMm ?? 100;
    int round(int value) => (value / step).round() * step;
    return MmPoint(round(point.x), round(point.y));
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
        // Reserved for persistent user guides in the next editor increment.
        draftStart = point;
        notifyListeners();
    }
  }

  void selectAt(MmPoint point) {
    for (final space in level.spaces.reversed) {
      if (space.boundary.contains(point)) {
        selectedSpaceId = space.id;
        notifyListeners();
        return;
      }
    }
    selectedSpaceId = null;
    notifyListeners();
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
            space.copyWith(grid: space.grid.copyWith(minorStepMm: minorStepMm))
          else
            space,
      ],
    );
    notifyListeners();
  }
}
