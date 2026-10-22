import 'package:elecx/src/domain/boundary_wall_profile_migration.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/wall_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-5 wall profile migration', () {
    final source = BoundaryEdgeId('source');
    final left = BoundaryEdgeId('left');
    final right = BoundaryEdgeId('right');
    final merged = BoundaryEdgeId('merged');

    test('split transforms rectangle into exact child profiles', () {
      final result = BoundaryWallProfileMigration.split(
        sourceEdgeId: source,
        firstResultEdgeId: left,
        secondResultEdgeId: right,
        sourceLengthMm: 4000,
        splitOffsetMm: 1500,
        profiles: {
          source: WallProfile.rectangle(widthMm: 4000, heightMm: 3000),
        },
      );

      expect(result.containsKey(source), isFalse);
      expect(result[left]!.maxX, 1500);
      expect(result[right]!.maxX, 2500);
      expect(result[left]!.maxY, 3000);
      expect(result[right]!.maxY, 3000);
    });

    test('split preserves notch geometry on the correct child', () {
      final profile = WallProfile.rectangle(widthMm: 4000, heightMm: 3000)
          .withTopNotch(startMm: 2500, widthMm: 700, depthMm: 400);

      final result = BoundaryWallProfileMigration.split(
        sourceEdgeId: source,
        firstResultEdgeId: left,
        secondResultEdgeId: right,
        sourceLengthMm: 4000,
        splitOffsetMm: 2000,
        profiles: {source: profile},
      );

      expect(result[left]!.maxX, 2000);
      expect(result[right]!.maxX, 2000);
      expect(result[left]!.containsPoint(1000, 2900), isTrue);
      expect(result[right]!.containsPoint(700, 2800), isFalse);
      expect(result[right]!.containsPoint(1500, 2800), isTrue);
    });

    test('merge combines equal-height rectangles losslessly', () {
      final result = BoundaryWallProfileMigration.merge(
        firstSourceEdgeId: left,
        secondSourceEdgeId: right,
        resultEdgeId: merged,
        firstLengthMm: 1500,
        secondLengthMm: 2500,
        profiles: {
          left: WallProfile.rectangle(widthMm: 1500, heightMm: 3000),
          right: WallProfile.rectangle(widthMm: 2500, heightMm: 3000),
        },
      );

      expect(result.keys, {merged});
      expect(result[merged]!.maxX, 4000);
      expect(result[merged]!.maxY, 3000);
    });

    test('merge of shaped profiles remains fail closed', () {
      final shaped = WallProfile.rectangle(widthMm: 1500, heightMm: 3000)
          .withTopNotch(startMm: 400, widthMm: 400, depthMm: 300);

      expect(
        () => BoundaryWallProfileMigration.merge(
          firstSourceEdgeId: left,
          secondSourceEdgeId: right,
          resultEdgeId: merged,
          firstLengthMm: 1500,
          secondLengthMm: 2500,
          profiles: {
            left: shaped,
            right: WallProfile.rectangle(widthMm: 2500, heightMm: 3000),
          },
        ),
        throwsA(
          isA<BoundaryWallProfileMigrationException>().having(
            (error) => error.code,
            'code',
            BoundaryWallProfileMigrationIssueCode.mergeProfileShapeUnsupported,
          ),
        ),
      );
    });

    test('profile width mismatch is rejected before transform', () {
      expect(
        () => BoundaryWallProfileMigration.split(
          sourceEdgeId: source,
          firstResultEdgeId: left,
          secondResultEdgeId: right,
          sourceLengthMm: 4000,
          splitOffsetMm: 2000,
          profiles: {
            source: WallProfile.rectangle(widthMm: 3900, heightMm: 3000),
          },
        ),
        throwsA(
          isA<BoundaryWallProfileMigrationException>().having(
            (error) => error.code,
            'code',
            BoundaryWallProfileMigrationIssueCode.profileWidthMismatch,
          ),
        ),
      );
    });
  });
}
