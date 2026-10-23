import 'package:elecx/src/domain/physical_level_order.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final buildingId = BuildingId('B-1');
  final l1 = LevelId('L1');
  final l2 = LevelId('L2');
  final l3 = LevelId('L3');

  PhysicalLevelPlacement level(LevelId id, int elevationMm) =>
      PhysicalLevelPlacement(
        levelId: id,
        buildingId: buildingId,
        elevationMm: elevationMm,
      );

  test('strict elevation order is independent from insertion order', () {
    final ordered = PhysicalLevelOrder.tryResolve([
      level(l3, 6000),
      level(l1, 0),
      level(l2, 3000),
    ]);

    expect(ordered!.map((value) => value.levelId), [l1, l2, l3]);
  });

  test('canonical slab adjacency disambiguates equal elevation', () {
    final ordered = PhysicalLevelOrder.tryResolve(
      [level(l2, 0), level(l1, 0), level(l3, 3000)],
      adjacencies: [
        PhysicalLevelAdjacency(
          buildingId: buildingId,
          belowLevelId: l1,
          aboveLevelId: l2,
        ),
      ],
    );

    expect(ordered!.map((value) => value.levelId), [l1, l2, l3]);
  });

  test('equal elevation without topology fails closed', () {
    expect(
      PhysicalLevelOrder.tryResolve([level(l1, 0), level(l2, 0)]),
      isNull,
    );
  });

  test('slab topology contradicting strict elevation fails closed', () {
    expect(
      PhysicalLevelOrder.tryResolve(
        [level(l1, 0), level(l2, 3000)],
        adjacencies: [
          PhysicalLevelAdjacency(
            buildingId: buildingId,
            belowLevelId: l2,
            aboveLevelId: l1,
          ),
        ],
      ),
      isNull,
    );
  });
}
