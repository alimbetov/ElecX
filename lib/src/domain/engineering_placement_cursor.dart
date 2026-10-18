import 'electrical_placement.dart';
import 'surfaces.dart';

enum PlacementCursorSnapKind {
  none,
  grid,
  endpoint,
  midpoint,
  intersection,
  installationGuide,
  centerAxis,
}

/// Surface-local engineering placement cursor.
///
/// The cursor is independent from mouse pixels: its persisted position is
/// always expressed in millimetres on a concrete [RoomSurfaceRef]. This makes
/// the same placement workflow usable from mouse, keyboard, stylus and touch.
final class EngineeringPlacementCursorState {
  const EngineeringPlacementCursorState({
    required this.surface,
    required this.position,
    required this.componentType,
    this.snapKind = PlacementCursorSnapKind.none,
    this.snapLabel,
    this.isValid = true,
  });

  final RoomSurfaceRef surface;
  final SurfacePointMm position;
  final ElectricalComponentType componentType;
  final PlacementCursorSnapKind snapKind;
  final String? snapLabel;
  final bool isValid;

  EngineeringPlacementCursorState copyWith({
    RoomSurfaceRef? surface,
    SurfacePointMm? position,
    ElectricalComponentType? componentType,
    PlacementCursorSnapKind? snapKind,
    String? snapLabel,
    bool clearSnapLabel = false,
    bool? isValid,
  }) =>
      EngineeringPlacementCursorState(
        surface: surface ?? this.surface,
        position: position ?? this.position,
        componentType: componentType ?? this.componentType,
        snapKind: snapKind ?? this.snapKind,
        snapLabel: clearSnapLabel ? null : snapLabel ?? this.snapLabel,
        isValid: isValid ?? this.isValid,
      );

  String get coordinateLabel => 'X ${position.xMm} · Y ${position.yMm} mm';
}

/// Pure movement operations for the placement cursor.
abstract final class EngineeringPlacementCursor {
  static EngineeringPlacementCursorState moveTo(
    EngineeringPlacementCursorState state,
    SurfacePointMm position, {
    PlacementCursorSnapKind snapKind = PlacementCursorSnapKind.none,
    String? snapLabel,
    bool isValid = true,
  }) =>
      state.copyWith(
        position: position,
        snapKind: snapKind,
        snapLabel: snapLabel,
        clearSnapLabel: snapLabel == null,
        isValid: isValid,
      );

  static EngineeringPlacementCursorState nudge(
    EngineeringPlacementCursorState state, {
    required int dxMm,
    required int dyMm,
  }) =>
      state.copyWith(
        position: SurfacePointMm(
          state.position.xMm + dxMm,
          state.position.yMm + dyMm,
        ),
        snapKind: PlacementCursorSnapKind.grid,
        clearSnapLabel: true,
      );
}
