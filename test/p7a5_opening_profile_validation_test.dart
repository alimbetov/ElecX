import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/boundary_host_registry.dart';
import 'package:elecx/src/domain/boundary_opening_profile_validation.dart';
import 'package:elecx/src/domain/boundary_wall_profile_registry.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:elecx/src/domain/wall_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-5 opening × wall-profile precommit validation', () {
    final spaceId = SpaceId('space-a');
    final edgeId = BoundaryEdgeId('edge-a');
    final host = BoundaryEdgeHostRef(spaceId: spaceId, edgeId: edgeId);

    ProjectOpeningEntity opening({
      int widthMm = 900,
      int heightMm = 2100,
      int baseElevationMm = 0,
    }) =>
        ProjectOpeningEntity(
          id: OpeningId('door-1'),
          levelId: LevelId('level-1'),
          kind: OpeningKind.door,
          connectedSpaceIds: [spaceId],
          widthMm: widthMm,
          heightMm: heightMm,
          baseElevationMm: baseElevationMm,
        );

    BoundaryHostedObjectRegistry hosted({
      int startMm = 1000,
      int endMm = 1900,
    }) =>
        const BoundaryHostedObjectRegistry.empty().putOpening(
          openingId: OpeningId('door-1'),
          host: host,
          startOffsetMm: startMm,
          endOffsetMm: endMm,
        );

    test('typed opening host fits rectangular profile', () {
      final profiles = BoundaryWallProfileRegistry({
        host: WallProfile.rectangle(widthMm: 4000, heightMm: 3000),
      });

      expect(
        () => BoundaryOpeningProfileValidator.validateSpace(
          spaceId: spaceId,
          openings: [opening()],
          hostedObjects: hosted(),
          wallProfiles: profiles,
        ),
        returnsNormally,
      );
    });

    test('opening under transformed notch fails before commit', () {
      final profiles = BoundaryWallProfileRegistry({
        host: WallProfile.rectangle(widthMm: 4000, heightMm: 3000)
            .withTopNotch(startMm: 900, widthMm: 1400, depthMm: 800),
      });

      expect(
        () => BoundaryOpeningProfileValidator.validateSpace(
          spaceId: spaceId,
          openings: [opening(heightMm: 2500)],
          hostedObjects: hosted(),
          wallProfiles: profiles,
        ),
        throwsA(
          isA<BoundaryOpeningProfileException>().having(
            (error) => error.code,
            'code',
            BoundaryOpeningProfileIssueCode.profileRejectsOpening,
          ),
        ),
      );
    });

    test('semantic opening width must equal hosted interval width', () {
      expect(
        () => BoundaryOpeningProfileValidator.validateSpace(
          spaceId: spaceId,
          openings: [opening(widthMm: 1000)],
          hostedObjects: hosted(),
          wallProfiles: const BoundaryWallProfileRegistry.empty(),
        ),
        throwsA(
          isA<BoundaryOpeningProfileException>().having(
            (error) => error.code,
            'code',
            BoundaryOpeningProfileIssueCode.intervalWidthMismatch,
          ),
        ),
      );
    });

    test('wall opening without stable BoundaryEdgeId host fails closed', () {
      expect(
        () => BoundaryOpeningProfileValidator.validateSpace(
          spaceId: spaceId,
          openings: [opening()],
          hostedObjects: const BoundaryHostedObjectRegistry.empty(),
          wallProfiles: const BoundaryWallProfileRegistry.empty(),
        ),
        throwsA(
          isA<BoundaryOpeningProfileException>().having(
            (error) => error.code,
            'code',
            BoundaryOpeningProfileIssueCode.missingHostedReference,
          ),
        ),
      );
    });

    test('hatch is not incorrectly forced onto a wall boundary', () {
      final hatch = ProjectOpeningEntity(
        id: OpeningId('hatch-1'),
        levelId: LevelId('level-1'),
        kind: OpeningKind.hatch,
        connectedSpaceIds: [spaceId],
        widthMm: 800,
        heightMm: 800,
      );

      expect(
        () => BoundaryOpeningProfileValidator.validateSpace(
          spaceId: spaceId,
          openings: [hatch],
          hostedObjects: const BoundaryHostedObjectRegistry.empty(),
          wallProfiles: const BoundaryWallProfileRegistry.empty(),
        ),
        returnsNormally,
      );
    });
  });
}
