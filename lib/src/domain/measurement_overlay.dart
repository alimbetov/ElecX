import 'surfaces.dart';

enum MeasurementAxis { horizontal, vertical }

enum MeasurementRole {
  clearanceLeft,
  clearanceRight,
  clearanceTop,
  clearanceBottom,
  objectWidth,
  objectHeight,
  structuralDepth,
}

final class MeasurementSpan {
  const MeasurementSpan({
    required this.axis,
    required this.role,
    required this.start,
    required this.end,
    required this.valueMm,
  });

  final MeasurementAxis axis;
  final MeasurementRole role;
  final SurfacePointMm start;
  final SurfacePointMm end;
  final int valueMm;
}

final class WallMeasurementSet {
  const WallMeasurementSet(this.spans);

  final List<MeasurementSpan> spans;
}

abstract final class WallMeasurementResolver {
  static WallMeasurementSet forOpening({
    required ArchitecturalOpening opening,
    required RoomWallSurface wall,
  }) {
    final left = opening.offsetFromStartMm;
    final right = wall.lengthMm.round() - opening.endOffsetMm;
    final bottom = opening.sillHeightMm;
    final top = wall.heightMm - opening.topMm;
    final centerX = opening.offsetFromStartMm + opening.widthMm ~/ 2;
    final centerY = opening.sillHeightMm + opening.heightMm ~/ 2;

    return WallMeasurementSet([
      MeasurementSpan(
        axis: MeasurementAxis.horizontal,
        role: MeasurementRole.clearanceLeft,
        start: SurfacePointMm(0, centerY),
        end: SurfacePointMm(opening.offsetFromStartMm, centerY),
        valueMm: left,
      ),
      MeasurementSpan(
        axis: MeasurementAxis.horizontal,
        role: MeasurementRole.clearanceRight,
        start: SurfacePointMm(opening.endOffsetMm, centerY),
        end: SurfacePointMm(wall.lengthMm.round(), centerY),
        valueMm: right,
      ),
      MeasurementSpan(
        axis: MeasurementAxis.vertical,
        role: MeasurementRole.clearanceBottom,
        start: SurfacePointMm(centerX, 0),
        end: SurfacePointMm(centerX, opening.sillHeightMm),
        valueMm: bottom,
      ),
      MeasurementSpan(
        axis: MeasurementAxis.vertical,
        role: MeasurementRole.clearanceTop,
        start: SurfacePointMm(centerX, opening.topMm),
        end: SurfacePointMm(centerX, wall.heightMm),
        valueMm: top,
      ),
      MeasurementSpan(
        axis: MeasurementAxis.horizontal,
        role: MeasurementRole.objectWidth,
        start: SurfacePointMm(opening.offsetFromStartMm, opening.sillHeightMm),
        end: SurfacePointMm(opening.endOffsetMm, opening.sillHeightMm),
        valueMm: opening.widthMm,
      ),
      MeasurementSpan(
        axis: MeasurementAxis.vertical,
        role: MeasurementRole.objectHeight,
        start: SurfacePointMm(opening.endOffsetMm, opening.sillHeightMm),
        end: SurfacePointMm(opening.endOffsetMm, opening.topMm),
        valueMm: opening.heightMm,
      ),
    ]);
  }

  static WallMeasurementSet forTopNotch({
    required int startMm,
    required int widthMm,
    required int depthMm,
    required RoomWallSurface wall,
  }) {
    final endMm = startMm + widthMm;
    final bottomY = wall.heightMm - depthMm;
    final centerX = startMm + widthMm ~/ 2;
    return WallMeasurementSet([
      MeasurementSpan(
        axis: MeasurementAxis.horizontal,
        role: MeasurementRole.clearanceLeft,
        start: SurfacePointMm(0, bottomY),
        end: SurfacePointMm(startMm, bottomY),
        valueMm: startMm,
      ),
      MeasurementSpan(
        axis: MeasurementAxis.horizontal,
        role: MeasurementRole.clearanceRight,
        start: SurfacePointMm(endMm, bottomY),
        end: SurfacePointMm(wall.lengthMm.round(), bottomY),
        valueMm: wall.lengthMm.round() - endMm,
      ),
      MeasurementSpan(
        axis: MeasurementAxis.horizontal,
        role: MeasurementRole.objectWidth,
        start: SurfacePointMm(startMm, bottomY),
        end: SurfacePointMm(endMm, bottomY),
        valueMm: widthMm,
      ),
      MeasurementSpan(
        axis: MeasurementAxis.vertical,
        role: MeasurementRole.structuralDepth,
        start: SurfacePointMm(centerX, bottomY),
        end: SurfacePointMm(centerX, wall.heightMm),
        valueMm: depthMm,
      ),
      MeasurementSpan(
        axis: MeasurementAxis.vertical,
        role: MeasurementRole.clearanceBottom,
        start: SurfacePointMm(centerX, 0),
        end: SurfacePointMm(centerX, bottomY),
        valueMm: bottomY,
      ),
    ]);
  }
}
