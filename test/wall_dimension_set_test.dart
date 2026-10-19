import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/project_model.dart';
import 'package:elecx/src/engine/wall_dimension_set.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wall dimensions resolve L D H without inventing thickness', () {
    final boundary = MmPolygon.rectangle(
      const MmPoint(0, 0),
      const MmPoint(4200, 3200),
    );
    final space = EngineeringSpace(
      id: 'room',
      name: 'Room',
      type: SpaceType.room,
      boundary: boundary,
      referenceFrame: RoomReferenceFrame(origin: boundary.bounds.center),
    );

    final horizontal = WallDimensionResolver.resolve(
      space: space,
      wallIndex: 0,
    );
    expect(horizontal.lengthMm, 4200);
    expect(horizontal.depthMm, 3200);
    expect(horizontal.heightMm, 3000);
    expect(horizontal.lengthLabel, 'L 4200 mm');
    expect(horizontal.depthLabel, 'D 3200 mm');
    expect(horizontal.heightLabel, 'H 3000 mm');

    final vertical = WallDimensionResolver.resolve(
      space: space,
      wallIndex: 1,
    );
    expect(vertical.lengthMm, 3200);
    expect(vertical.depthMm, 4200);
    expect(vertical.heightMm, 3000);
  });
}
