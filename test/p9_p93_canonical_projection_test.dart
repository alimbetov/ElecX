import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_canonical_projection.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/component_placement.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P9.3 canonical engineering projection', () {
    test('P9.3-Q01 selected production winner has canonical projection', () {
      final fixture = _projectFixture();
      final originalVersion = fixture.project.version;
      final originalStores = fixture.project.stores;

      final result = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );

      expect(result.accepted, isTrue);
      final set = result.candidateSet!;
      final projection = set.engineeringProjection;
      expect(projection.projectionVersion, apartmentProjectionVersion);
      expect(
        projection.selectedCandidateFingerprint,
        set.recommendedCandidate.candidateFingerprint,
      );
      expect(
        projection.geometryFingerprint,
        set.recommendedCandidate.rankedCandidate.candidate.geometryFingerprint,
      );
      expect(projection.graph.components, isNotEmpty);
      expect(
        projection.placements,
        hasLength(projection.graph.components.length),
      );
      expect(fixture.project.version, same(originalVersion));
      expect(fixture.project.stores, same(originalStores));
    });

    test('P9.3-Q02 repeated generation is byte-stable by fingerprints', () {
      final fixture = _projectFixture();
      const service = ApartmentCandidateSetService();

      final first = service.generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      final second = service.generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );

      expect(first.accepted, isTrue);
      expect(second.accepted, isTrue);
      final left = first.candidateSet!.engineeringProjection;
      final right = second.candidateSet!.engineeringProjection;
      expect(right.graphFingerprint, left.graphFingerprint);
      expect(right.placementFingerprint, left.placementFingerprint);
      expect(right.projectionFingerprint, left.projectionFingerprint);
      expect(
        right.graph.components.map((component) => component.id.value).toList(),
        left.graph.components.map((component) => component.id.value).toList(),
      );
      expect(
        right.graph.connections
            .map((connection) => connection.id.value)
            .toList(),
        left.graph.connections
            .map((connection) => connection.id.value)
            .toList(),
      );
    });

    test('P9.3-Q03 graph contains only proven spatial semantics', () {
      final projection = _projection();

      expect(
        EngineeringSystemPolicy.calculationFor(EngineeringSystemClass.custom),
        EngineeringCalculationKind.connectivityOnly,
      );
      for (final component in projection.graph.components) {
        expect(component.discipline, EngineeringDiscipline.architecture);
        expect(component.systemClass, EngineeringSystemClass.custom);
        expect(component.ratedPowerW, isNull);
        expect(component.voltageV, isNull);
        for (final port in component.ports) {
          expect(port.direction, EngineeringPortDirection.bidirectional);
          expect(
            port.allowedConnections,
            {EngineeringConnectionType.custom},
          );
        }
      }
      for (final connection in projection.graph.connections) {
        expect(connection.connectionType, EngineeringConnectionType.custom);
        expect(connection.systemClass, EngineeringSystemClass.custom);
        expect(
          connection.semanticTypeId,
          isIn(const [
            'apartment.access.door',
            'apartment.access.openPassage',
          ]),
        );
        expect(connection.circuitId, isNull);
        expect(connection.routeId, isNull);
      }
    });

    test('P9.3-Q04 every placement references exactly one graph component', () {
      final fixture = _projectFixture();
      final result = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );
      final projection = result.candidateSet!.engineeringProjection;
      final componentIds =
          projection.graph.components.map((component) => component.id).toSet();
      final placedIds = projection.placements
          .map((placement) => placement.componentId)
          .toList();

      expect(placedIds.toSet(), componentIds);
      expect(placedIds.toSet(), hasLength(placedIds.length));
      for (final placement in projection.placements) {
        expect(placement.host, isA<LevelComponentHost>());
        final host = placement.host as LevelComponentHost;
        expect(host.levelId, fixture.target.levelId);
        expect(placement.footprint.length, greaterThanOrEqualTo(4));
      }
    });

    test('P9.3-Q05 canonical graph has no dangling ports or components', () {
      final projection = _projection();

      for (final connection in projection.graph.connections) {
        final from = projection.graph.component(connection.fromComponentId);
        final to = projection.graph.component(connection.toComponentId);
        expect(from, isNotNull);
        expect(to, isNotNull);
        expect(from!.port(connection.fromPortId), isNotNull);
        expect(to!.port(connection.toPortId), isNotNull);
      }
    });

    test('P9.3-Q06 diagnostics and projection bind the same selected winner',
        () {
      final fixture = _projectFixture();
      final result = const ApartmentCandidateSetService().generate(
        input: _request(),
        target: fixture.target,
        project: fixture.project,
      );

      expect(result.accepted, isTrue);
      final set = result.candidateSet!;
      final selected = result.diagnostics!.selectedEntries.single;
      expect(
        set.engineeringProjection.selectedCandidateFingerprint,
        selected.candidateFingerprint,
      );
      expect(
        set.engineeringProjection.geometryFingerprint,
        selected.geometryFingerprint,
      );
    });
  });
}

ApartmentEngineeringProjection _projection() {
  final fixture = _projectFixture();
  final result = const ApartmentCandidateSetService().generate(
    input: _request(),
    target: fixture.target,
    project: fixture.project,
  );
  expect(result.accepted, isTrue);
  return result.candidateSet!.engineeringProjection;
}

ApartmentRequestInput _request() => const ApartmentRequestInput(
      habitableRoomCount: 3,
      approximateAreaDm2: 7800,
      bathroomCount: 1,
      separateWcCount: 0,
      balconyCount: 0,
      balconyKind: ApartmentBalconyKind.none,
      kitchenMode: ApartmentKitchenMode.separate,
      corridorMode: ApartmentCorridorMode.auto,
      exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
    );

final class _ProjectFixture {
  const _ProjectFixture({
    required this.project,
    required this.target,
  });

  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
}

_ProjectFixture _projectFixture() {
  final projectId = ProjectId('p93-projection-project');
  final siteId = SiteId('p93-projection-site');
  final buildingId = BuildingId('p93-projection-building');
  final levelId = LevelId('p93-projection-level');
  final version = LocalProjectVersion(8);

  final stores = ProjectEntityStores(
    sites: {
      siteId: ProjectSiteEntity(
        id: siteId,
        name: 'Site',
        buildingIds: {buildingId},
      ),
    },
    buildings: {
      buildingId: ProjectBuildingEntity(
        id: buildingId,
        siteId: siteId,
        name: 'Building',
        levelIds: {levelId},
      ),
    },
    levels: {
      levelId: ProjectLevelEntity(
        id: levelId,
        buildingId: buildingId,
        name: 'Level 1',
        levelNumber: 1,
        elevationMm: 3000,
        kind: ProjectLevelKind.residential,
      ),
    },
  );
  final project = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: version,
    stores: stores,
  );

  return _ProjectFixture(
    project: project,
    target: LevelWizardTarget(
      projectId: projectId,
      siteId: siteId,
      baseVersion: version,
      buildingId: buildingId,
      levelId: levelId,
    ),
  );
}
