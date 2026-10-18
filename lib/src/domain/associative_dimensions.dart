enum AssociativeDimensionKind {
  roomWidth,
  roomHeight,
}

final class AssociativeDimension {
  const AssociativeDimension({
    required this.id,
    required this.kind,
    required this.ownerId,
    required this.valueMm,
    required this.editable,
  });

  final String id;
  final AssociativeDimensionKind kind;
  final String ownerId;
  final int valueMm;
  final bool editable;

  String get label => '$valueMm mm';
}

sealed class DimensionEditResult {
  const DimensionEditResult();
}

final class DimensionEditSuccess extends DimensionEditResult {
  const DimensionEditSuccess(this.dimension);

  final AssociativeDimension dimension;
}

final class DimensionEditFailure extends DimensionEditResult {
  const DimensionEditFailure(this.message);

  final String message;
}
