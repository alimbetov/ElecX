import '../domain/geometry.dart';
import '../domain/project_model.dart';
import 'spatial_index.dart';

final class IndexedSpace implements SpatialIndexItem {
  const IndexedSpace(this.space);

  final EngineeringSpace space;

  @override
  String get spatialId => space.id;

  @override
  MmBounds get spatialBounds => space.boundary.bounds;
}

/// Projected spatial index used by the plan renderer and hit-testing.
/// Rebuild is deterministic and separated from paint; later this class can own
/// independent indexes for openings, electrical devices, routes and guides.
final class SpatialSceneIndex {
  SpatialSceneIndex({int cellSizeMm = 5000})
    : spaces = SpatialHashIndex<IndexedSpace>(cellSizeMm: cellSizeMm);

  final SpatialHashIndex<IndexedSpace> spaces;
  int _revision = 0;

  int get revision => _revision;

  void rebuildSpaces(Iterable<EngineeringSpace> source) {
    spaces.clear();
    for (final space in source) {
      spaces.upsert(IndexedSpace(space));
    }
    _revision++;
  }

  List<EngineeringSpace> visibleSpaces(MmBounds bounds) =>
      spaces.query(bounds).map((item) => item.space).toList(growable: false);
}
