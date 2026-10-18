import '../domain/geometry.dart';

abstract interface class SpatialIndexItem {
  String get spatialId;
  MmBounds get spatialBounds;
}

/// Uniform-grid index tuned for CAD scenes expressed in integer millimetres.
///
/// Query cost depends primarily on visible cells rather than total scene size.
/// Large objects may occupy several cells; result ids are de-duplicated.
final class SpatialHashIndex<T extends SpatialIndexItem> {
  SpatialHashIndex({this.cellSizeMm = 5000}) {
    if (cellSizeMm <= 0) {
      throw ArgumentError.value(cellSizeMm, 'cellSizeMm', 'Must be positive.');
    }
  }

  final int cellSizeMm;
  final Map<int, Set<String>> _cells = {};
  final Map<String, T> _items = {};
  final Map<String, List<int>> _itemCells = {};

  int get length => _items.length;

  void clear() {
    _cells.clear();
    _items.clear();
    _itemCells.clear();
  }

  void upsert(T item) {
    remove(item.spatialId);
    final keys = _cellKeys(item.spatialBounds);
    _items[item.spatialId] = item;
    _itemCells[item.spatialId] = keys;
    for (final key in keys) {
      (_cells[key] ??= <String>{}).add(item.spatialId);
    }
  }

  bool remove(String id) {
    final keys = _itemCells.remove(id);
    final removed = _items.remove(id) != null;
    if (keys == null) return removed;
    for (final key in keys) {
      final bucket = _cells[key];
      if (bucket == null) continue;
      bucket.remove(id);
      if (bucket.isEmpty) _cells.remove(key);
    }
    return removed;
  }

  List<T> query(MmBounds bounds) {
    final ids = <String>{};
    for (final key in _cellKeys(bounds)) {
      final bucket = _cells[key];
      if (bucket != null) ids.addAll(bucket);
    }
    return [
      for (final id in ids)
        if (_items[id] case final item?)
          if (item.spatialBounds.intersects(bounds)) item,
    ];
  }

  List<int> _cellKeys(MmBounds bounds) {
    final minX = _floorDiv(bounds.left, cellSizeMm);
    final maxX = _floorDiv(bounds.right, cellSizeMm);
    final minY = _floorDiv(bounds.bottom, cellSizeMm);
    final maxY = _floorDiv(bounds.top, cellSizeMm);
    return [
      for (var y = minY; y <= maxY; y++)
        for (var x = minX; x <= maxX; x++) _pack(x, y),
    ];
  }

  int _floorDiv(int value, int divisor) {
    final q = value ~/ divisor;
    final r = value % divisor;
    return value < 0 && r != 0 ? q - 1 : q;
  }

  int _pack(int x, int y) => Object.hash(x, y);
}
