import 'package:flutter/foundation.dart';

import '../../domain/geometry.dart';
import '../../domain/project_model.dart';
import 'editor_building_workspace.dart';

enum SiteMapEntityKind { outdoorZone, building, lot, network }

final class SiteMapEntity {
  const SiteMapEntity({
    required this.id,
    required this.navigatorNodeId,
    required this.label,
    required this.kind,
    required this.boundary,
    this.targetId,
  });

  final String id;
  final String navigatorNodeId;
  final String label;
  final SiteMapEntityKind kind;
  final MmPolygon boundary;
  final String? targetId;

  bool contains(MmPoint point) => boundary.contains(point) || boundary.bounds.contains(point);
}

/// Shared transient interaction state between the hierarchical navigator and
/// the site-map projection. Domain selection remains in EditorBuildingWorkspace;
/// hover and map selection live here because they are presentation concerns.
final class SiteMapInteractionController extends ChangeNotifier {
  String? _hoveredNodeId;
  String? _selectedNodeId;

  String? get hoveredNodeId => _hoveredNodeId;
  String? get selectedNodeId => _selectedNodeId;

  void hover(String? nodeId) {
    if (_hoveredNodeId == nodeId) return;
    _hoveredNodeId = nodeId;
    notifyListeners();
  }

  void select(String? nodeId) {
    if (_selectedNodeId == nodeId) return;
    _selectedNodeId = nodeId;
    notifyListeners();
  }

  void clear() {
    if (_hoveredNodeId == null && _selectedNodeId == null) return;
    _hoveredNodeId = null;
    _selectedNodeId = null;
    notifyListeners();
  }
}

abstract final class SiteMapProjection {
  /// Builds the interactive site overview for the current tower workspace.
  /// Outdoor zones use their actual site polygons. Until explicit persisted
  /// building placement is introduced, the tower footprint is deterministically
  /// derived from a representative building level and kept in the same mm
  /// coordinate system.
  static List<SiteMapEntity> tower(EditorBuildingWorkspace workspace) {
    final result = <SiteMapEntity>[
      for (final zone in workspace.site.outdoorZones)
        SiteMapEntity(
          id: 'map:outdoor:${zone.id}',
          navigatorNodeId: 'outdoor:${zone.id}',
          label: zone.name,
          kind: SiteMapEntityKind.outdoorZone,
          boundary: zone.boundary,
          targetId: zone.id,
        ),
    ];

    final footprint = _buildingFootprint(workspace.building.building);
    if (footprint != null) {
      result.add(
        SiteMapEntity(
          id: 'map:building:${workspace.building.building.id}',
          navigatorNodeId: 'building:${workspace.building.building.id}',
          label: workspace.building.building.name,
          kind: SiteMapEntityKind.building,
          boundary: footprint,
          targetId: workspace.building.building.id,
        ),
      );
    }
    return result;
  }

  static MmPolygon? _buildingFootprint(Building building) {
    if (building.levels.isEmpty) return null;
    BuildingLevel? representative;
    for (final level in building.levels) {
      if (level.spaces.isNotEmpty) {
        representative = level;
        break;
      }
    }
    if (representative == null) return null;
    MmBounds? bounds;
    for (final space in representative.spaces) {
      bounds = bounds == null ? space.boundary.bounds : bounds.union(space.boundary.bounds);
    }
    final b = bounds;
    if (b == null || b.width == 0 || b.height == 0) return null;
    return MmPolygon.rectangle(
      MmPoint(b.left, b.bottom),
      MmPoint(b.right, b.top),
    );
  }
}
