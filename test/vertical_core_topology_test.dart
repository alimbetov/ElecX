import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectVerticalCore', () {
    test('riser keeps stable building, level and plan identity', () {
      final level1 = LevelId('L1');
      final level2 = LevelId('L2');
      final core = ProjectVerticalCore(
        id: VerticalCoreId('VC-01'),
        buildingId: BuildingId('B1'),
        kind: VerticalCoreKind.riser,
        levelIds: [level1, level2],
        footprint: const [
          BoundaryPointMm(xMm: 1000, yMm: 1000),
          BoundaryPointMm(xMm: 1400, yMm: 1000),
          BoundaryPointMm(xMm: 1400, yMm: 1400),
          BoundaryPointMm(xMm: 1000, yMm: 1400),
        ],
        name: 'Power riser',
      );

      expect(core.id, VerticalCoreId('VC-01'));
      expect(core.buildingId, BuildingId('B1'));
      expect(core.kind, VerticalCoreKind.riser);
      expect(core.servesLevel(level1), isTrue);
      expect(core.servesLevel(level2), isTrue);
      expect(core.servesLevel(LevelId('L3')), isFalse);
      expect(core.footprint, hasLength(4));
    });

    test('vertical core requires at least two canonical levels', () {
      expect(
        () => ProjectVerticalCore(
          id: VerticalCoreId('VC-01'),
          buildingId: BuildingId('B1'),
          kind: VerticalCoreKind.riser,
          levelIds: [LevelId('L1')],
          footprint: const [
            BoundaryPointMm(xMm: 0, yMm: 0),
            BoundaryPointMm(xMm: 100, yMm: 0),
            BoundaryPointMm(xMm: 100, yMm: 100),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('vertical core requires non-zero physical footprint', () {
      expect(
        () => ProjectVerticalCore(
          id: VerticalCoreId('VC-01'),
          buildingId: BuildingId('B1'),
          kind: VerticalCoreKind.shaft,
          levelIds: [LevelId('L1'), LevelId('L2')],
          footprint: const [
            BoundaryPointMm(xMm: 0, yMm: 0),
            BoundaryPointMm(xMm: 100, yMm: 0),
            BoundaryPointMm(xMm: 200, yMm: 0),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('empty display name is rejected', () {
      expect(
        () => ProjectVerticalCore(
          id: VerticalCoreId('VC-01'),
          buildingId: BuildingId('B1'),
          kind: VerticalCoreKind.serviceShaft,
          levelIds: [LevelId('L1'), LevelId('L2')],
          footprint: const [
            BoundaryPointMm(xMm: 0, yMm: 0),
            BoundaryPointMm(xMm: 100, yMm: 0),
            BoundaryPointMm(xMm: 100, yMm: 100),
          ],
          name: '   ',
        ),
        throwsArgumentError,
      );
    });
  });

  test('topology validator rejects store-key identity drift', () {
    final core = ProjectVerticalCore(
      id: VerticalCoreId('VC-01'),
      buildingId: BuildingId('B1'),
      kind: VerticalCoreKind.riser,
      levelIds: [LevelId('L1'), LevelId('L2')],
      footprint: const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 100, yMm: 0),
        BoundaryPointMm(xMm: 100, yMm: 100),
      ],
    );

    final issues = VerticalCoreTopologyValidator.validate({
      VerticalCoreId('wrong-key'): core,
    });

    expect(issues, hasLength(1));
    expect(
      issues.single.code,
      VerticalCoreTopologyIssueCode.storeKeyIdMismatch,
    );
    expect(issues.single.verticalCoreId, core.id);
  });
}
