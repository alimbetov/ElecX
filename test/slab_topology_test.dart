import 'dart:math';

import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/slab_topology.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SlabId', () {
    test('secure factory allocates stable slab identity type', () {
      final factory = SecureRandomEntityIdFactory(random: Random(91));

      final first = factory.newSlabId();
      final second = factory.newSlabId();

      expect(first, isA<SlabId>());
      expect(second, isA<SlabId>());
      expect(first, isNot(second));
      expect(first.value, isNotEmpty);
      expect(second.value, isNotEmpty);
    });
  });

  group('ProjectSlab', () {
    test('inter-level slab owns one physical boundary between two levels', () {
      final slab = ProjectSlab(
        id: SlabId('slab-01-02'),
        buildingId: BuildingId('building-a'),
        kind: SlabKind.interLevel,
        belowLevelId: LevelId('level-01'),
        aboveLevelId: LevelId('level-02'),
        elevationMm: 3200,
        thicknessMm: 200,
        materialId: 'reinforced-concrete',
        footprint: _rectangle,
      );

      expect(slab.id, SlabId('slab-01-02'));
      expect(slab.belowLevelId, LevelId('level-01'));
      expect(slab.aboveLevelId, LevelId('level-02'));
      expect(slab.thicknessMm, 200);
    });

    test('foundation and roof have exactly one exterior side', () {
      final foundation = ProjectSlab(
        id: SlabId('foundation'),
        buildingId: BuildingId('building-a'),
        kind: SlabKind.foundation,
        aboveLevelId: LevelId('level-01'),
        elevationMm: 0,
        thicknessMm: 300,
        materialId: 'reinforced-concrete',
        footprint: _rectangle,
      );
      final roof = ProjectSlab(
        id: SlabId('roof'),
        buildingId: BuildingId('building-a'),
        kind: SlabKind.roof,
        belowLevelId: LevelId('level-03'),
        elevationMm: 9600,
        thicknessMm: 220,
        materialId: 'reinforced-concrete',
        footprint: _rectangle,
      );

      expect(foundation.belowLevelId, isNull);
      expect(roof.aboveLevelId, isNull);
    });

    test('rejects zero-area footprint and invalid level-side semantics', () {
      expect(
        () => ProjectSlab(
          id: SlabId('zero-area'),
          buildingId: BuildingId('building-a'),
          kind: SlabKind.interLevel,
          belowLevelId: LevelId('level-01'),
          aboveLevelId: LevelId('level-02'),
          elevationMm: 3200,
          thicknessMm: 200,
          materialId: 'reinforced-concrete',
          footprint: const [
            BoundaryPointMm(xMm: 0, yMm: 0),
            BoundaryPointMm(xMm: 1000, yMm: 0),
            BoundaryPointMm(xMm: 2000, yMm: 0),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => ProjectSlab(
          id: SlabId('bad-roof'),
          buildingId: BuildingId('building-a'),
          kind: SlabKind.roof,
          aboveLevelId: LevelId('level-03'),
          elevationMm: 9600,
          thicknessMm: 220,
          materialId: 'reinforced-concrete',
          footprint: _rectangle,
        ),
        throwsArgumentError,
      );
    });
  });

  group('SlabTopologyValidator', () {
    test('rejects duplicate physical level pair', () {
      final first = _interLevelSlab('slab-a');
      final second = _interLevelSlab('slab-b');

      final issues = SlabTopologyValidator.validate({
        first.id: first,
        second.id: second,
      });

      expect(issues, hasLength(1));
      expect(issues.single.code, SlabTopologyIssueCode.duplicateLevelPair);
    });

    test('rejects store key identity mismatch', () {
      final slab = _interLevelSlab('slab-a');

      final issues = SlabTopologyValidator.validate({SlabId('wrong-key'): slab});

      expect(
        issues.map((issue) => issue.code),
        contains(SlabTopologyIssueCode.storeKeyIdMismatch),
      );
    });
  });
}

ProjectSlab _interLevelSlab(String id) => ProjectSlab(
      id: SlabId(id),
      buildingId: BuildingId('building-a'),
      kind: SlabKind.interLevel,
      belowLevelId: LevelId('level-01'),
      aboveLevelId: LevelId('level-02'),
      elevationMm: 3200,
      thicknessMm: 200,
      materialId: 'reinforced-concrete',
      footprint: _rectangle,
    );

const _rectangle = <BoundaryPointMm>[
  BoundaryPointMm(xMm: 0, yMm: 0),
  BoundaryPointMm(xMm: 6000, yMm: 0),
  BoundaryPointMm(xMm: 6000, yMm: 4000),
  BoundaryPointMm(xMm: 0, yMm: 4000),
];
