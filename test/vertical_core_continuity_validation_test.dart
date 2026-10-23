import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/vertical_core.dart';
import 'package:elecx/src/domain/vertical_core_continuity_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final buildingId = BuildingId('B-1');
  final coreId = VerticalCoreId('VC-1');
  final l1 = LevelId('L1');
  final l2 = LevelId('L2');
  final core = ProjectVerticalCore(
    id: coreId,
    buildingId: buildingId,
    kind: VerticalCoreKind.riser,
    levelIds: [l1, l2],
    footprint: const [
      BoundaryPointMm(xMm: 0, yMm: 0),
      BoundaryPointMm(xMm: 100, yMm: 0),
      BoundaryPointMm(xMm: 100, yMm: 100),
      BoundaryPointMm(xMm: 0, yMm: 100),
    ],
  );

  test('missing building level topology fails closed', () {
    final issues = VerticalCoreContinuityValidator.validate(
      verticalCores: {coreId: core},
      buildingLevelIdsResolver: (_) => null,
      levelPlacementResolver: (_) => null,
    );

    expect(issues, hasLength(1));
    expect(
      issues.single.code,
      VerticalCoreContinuityIssueCode.unresolvedPhysicalTopology,
    );
  });

  test('missing canonical level placement fails closed', () {
    final issues = VerticalCoreContinuityValidator.validate(
      verticalCores: {coreId: core},
      buildingLevelIdsResolver: (_) => [l1, l2],
      levelPlacementResolver: (_) => null,
    );

    expect(issues, hasLength(1));
    expect(
      issues.single.code,
      VerticalCoreContinuityIssueCode.unresolvedPhysicalTopology,
    );
  });
}
