import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/snap_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = SnapEngine();

  test('endpoint wins over nearby grid when inside acquisition radius', () {
    final result = engine.resolve(
      const MmPoint(995, 1008),
      const SnapContext(
        gridStepMm: 100,
        endpoints: [MmPoint(1010, 1010)],
      ),
    );

    expect(result.snapped, isTrue);
    expect(result.point, const MmPoint(1010, 1010));
    expect(result.candidate!.kind, SnapKind.endpoint);
  });

  test('grid snap remains available without geometry candidates', () {
    final result = engine.resolve(
      const MmPoint(1041, 1064),
      const SnapContext(gridStepMm: 100),
    );

    expect(result.point, const MmPoint(1000, 1100));
    expect(result.candidate!.kind, SnapKind.grid);
  });
}
