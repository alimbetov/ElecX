import '../domain/geometry.dart';

enum SelectionMode { replace, add, toggle, subtract }

enum SelectionKind { room, opening, electricalComponent, route, guide, handle }

final class SelectableBounds {
  const SelectableBounds({
    required this.id,
    required this.kind,
    required this.bounds,
  });

  final String id;
  final SelectionKind kind;
  final MmBounds bounds;
}

final class SelectionState {
  const SelectionState({this.ids = const <String>{}, this.primaryId});

  final Set<String> ids;
  final String? primaryId;

  bool contains(String id) => ids.contains(id);
}

abstract final class SelectionEngine {
  static SelectionState apply(
    SelectionState current,
    String id,
    SelectionMode mode,
  ) {
    final next = <String>{...current.ids};
    switch (mode) {
      case SelectionMode.replace:
        next
          ..clear()
          ..add(id);
      case SelectionMode.add:
        next.add(id);
      case SelectionMode.toggle:
        next.contains(id) ? next.remove(id) : next.add(id);
      case SelectionMode.subtract:
        next.remove(id);
    }
    return SelectionState(
      ids: Set.unmodifiable(next),
      primaryId: next.contains(id)
          ? id
          : next.isEmpty
          ? null
          : current.primaryId != null && next.contains(current.primaryId)
          ? current.primaryId
          : next.first,
    );
  }

  static SelectionState boxSelect({
    required Iterable<SelectableBounds> objects,
    required MmBounds box,
    SelectionState current = const SelectionState(),
    SelectionMode mode = SelectionMode.replace,
    Set<SelectionKind>? allowedKinds,
  }) {
    final hits = objects
        .where(
          (object) =>
              (allowedKinds == null || allowedKinds.contains(object.kind)) &&
              _intersects(object.bounds, box),
        )
        .map((object) => object.id)
        .toSet();

    final next = switch (mode) {
      SelectionMode.replace => hits,
      SelectionMode.add => <String>{...current.ids, ...hits},
      SelectionMode.toggle => <String>{
        ...current.ids.where((id) => !hits.contains(id)),
        ...hits.where((id) => !current.ids.contains(id)),
      },
      SelectionMode.subtract => <String>{
        ...current.ids.where((id) => !hits.contains(id)),
      },
    };
    return SelectionState(
      ids: Set.unmodifiable(next),
      primaryId: next.isEmpty ? null : next.first,
    );
  }

  static bool _intersects(MmBounds a, MmBounds b) =>
      a.left <= b.right &&
      a.right >= b.left &&
      a.bottom <= b.top &&
      a.top >= b.bottom;
}
