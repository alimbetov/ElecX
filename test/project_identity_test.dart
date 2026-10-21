import 'dart:math';

import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('typed entity identities', () {
    test('preserve legacy non-empty values without changing identity text', () {
      final projectId = ProjectId('legacy-project-42');
      final siteId = SiteId('site-legacy-project-42');

      expect(projectId.value, 'legacy-project-42');
      expect(siteId.value, 'site-legacy-project-42');
      expect(projectId.toString(), 'legacy-project-42');
    });

    test('reject empty and whitespace-only values', () {
      expect(() => ProjectId(''), throwsArgumentError);
      expect(() => LevelId('   '), throwsArgumentError);
    });

    test('equality is value based but remains type safe', () {
      expect(ProjectId('same'), ProjectId('same'));
      expect(ProjectId('same').hashCode, ProjectId('same').hashCode);
      expect(ProjectId('same'), isNot(SiteId('same')));
      expect(LevelId('same'), isNot(BuildingId('same')));
    });
  });

  group('SecureRandomEntityIdFactory', () {
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('allocates RFC 4122 variant UUID v4 values for persistent ids', () {
      final factory = SecureRandomEntityIdFactory(random: Random(20261021));
      final ids = <EntityId>[
        factory.newProjectId(),
        factory.newSiteId(),
        factory.newBuildingId(),
        factory.newLevelId(),
        factory.newZoneId(),
        factory.newSpaceId(),
        factory.newOpeningId(),
        factory.newBoundaryEdgeId(),
        factory.newVerticalCoreId(),
        factory.newServiceEntryId(),
        factory.newComponentId(),
        factory.newPortId(),
        factory.newCircuitId(),
        factory.newRouteId(),
        factory.newGenerationId(),
        factory.newTemplateId(),
        factory.newTypicalFloorDefinitionId(),
        factory.newEngineeringConnectionId(),
      ];

      expect(ids.every((id) => uuidV4.hasMatch(id.value)), isTrue);
      expect(ids.map((id) => id.value).toSet().length, ids.length);
    });

    test('does not encode display numbers or collection positions', () {
      final factory = SecureRandomEntityIdFactory(random: Random(7));
      final first = factory.newLevelId();
      final second = factory.newLevelId();

      expect(first, isNot(second));
      expect(first.value, isNot(contains('1')));
      expect(second.value, isNot(contains('2')));
    });
  });
}
