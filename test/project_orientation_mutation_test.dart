import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_orientation_commands.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_orientation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P5D Project North mutation', () {
    test('metadata-only set is a first-class canonical commit', () {
      final session = ProjectMutationSession(_project());
      final north = ProjectEngineeringNorth.fromDegrees(32.5);

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: SetProjectNorthCommand(north),
        ),
      )!;

      expect(result.project.version, LocalProjectVersion(5));
      expect(result.project.engineeringMetadata.projectNorth, north);
      expect(result.changeSet.entityDiff.isEmpty, isTrue);
      expect(result.changeSet.affectedEntityIds, isEmpty);
      expect(result.changeSet.hasRootMetadataChanges, isTrue);
      expect(
        result.changeSet.engineeringMetadataDiff.beforeProjectNorth,
        isNull,
      );
      expect(
        result.changeSet.engineeringMetadataDiff.afterProjectNorth,
        north,
      );
      expect(session.undoDepth, 1);
    });

    test('setting same normalized Project North is a semantic no-op', () {
      final north = ProjectEngineeringNorth.fromDegrees(90);
      final session = ProjectMutationSession(_project(north: north));

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: SetProjectNorthCommand(
            ProjectEngineeringNorth.fromDegrees(450),
          ),
        ),
      );

      expect(result, isNull);
      expect(session.current.version, LocalProjectVersion(4));
      expect(session.undoDepth, 0);
      expect(session.redoDepth, 0);
    });

    test('clearing unspecified Project North is a semantic no-op', () {
      final session = ProjectMutationSession(_project());

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: const ClearProjectNorthCommand(),
        ),
      );

      expect(result, isNull);
      expect(session.current.version, LocalProjectVersion(4));
      expect(session.undoDepth, 0);
    });

    test('stale metadata command fails closed without changing state', () {
      final initial = _project();
      final session = ProjectMutationSession(initial);

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: LocalProjectVersion(3),
            command: SetProjectNorthCommand(
              ProjectEngineeringNorth.fromDegrees(15),
            ),
          ),
        ),
        throwsA(isA<StaleProjectMutationException>()),
      );

      expect(session.current, same(initial));
      expect(session.undoDepth, 0);
      expect(session.redoDepth, 0);
    });

    test('undo and redo restore exact engineering metadata monotonically', () {
      final session = ProjectMutationSession(_project());
      final north = ProjectEngineeringNorth.fromDegrees(271.125);

      final committed = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: SetProjectNorthCommand(north),
        ),
      )!;
      final undone = session.undo(committed.project.version)!;
      final redone = session.redo(undone.project.version)!;

      expect(undone.project.version, LocalProjectVersion(6));
      expect(undone.project.engineeringMetadata.projectNorth, isNull);
      expect(undone.changeSet.entityDiff.isEmpty, isTrue);
      expect(
        undone.changeSet.engineeringMetadataDiff.beforeProjectNorth,
        north,
      );
      expect(
        undone.changeSet.engineeringMetadataDiff.afterProjectNorth,
        isNull,
      );

      expect(redone.project.version, LocalProjectVersion(7));
      expect(redone.project.engineeringMetadata.projectNorth, north);
      expect(redone.changeSet.entityDiff.isEmpty, isTrue);
      expect(
        redone.changeSet.engineeringMetadataDiff.beforeProjectNorth,
        isNull,
      );
      expect(
        redone.changeSet.engineeringMetadataDiff.afterProjectNorth,
        north,
      );
    });

    test('clear restores explicit unspecified state as a metadata commit', () {
      final north = ProjectEngineeringNorth.fromDegrees(180);
      final session = ProjectMutationSession(_project(north: north));

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: const ClearProjectNorthCommand(),
        ),
      )!;

      expect(result.project.engineeringMetadata.projectNorth, isNull);
      expect(result.changeSet.entityDiff.isEmpty, isTrue);
      expect(
        result.changeSet.engineeringMetadataDiff.beforeProjectNorth,
        north,
      );
      expect(
        result.changeSet.engineeringMetadataDiff.afterProjectNorth,
        isNull,
      );
    });

    test('preview exposes metadata diff without mutating live state', () {
      final initial = _project();
      final session = ProjectMutationSession(initial);
      final north = ProjectEngineeringNorth.fromDegrees(15);

      final preview = session.preview(
        ProjectMutationRequest(
          expectedVersion: initial.version,
          command: SetProjectNorthCommand(north),
        ),
      );

      expect(preview.hasChanges, isTrue);
      expect(preview.entityDiff.isEmpty, isTrue);
      expect(preview.affectedEntityIds, isEmpty);
      expect(preview.candidate.version, initial.version);
      expect(preview.candidate.engineeringMetadata.projectNorth, north);
      expect(session.current, same(initial));
      expect(session.current.engineeringMetadata.projectNorth, isNull);
    });

    test('mixed entity and metadata command produces one combined change set',
        () {
      final session = ProjectMutationSession(_project());
      final north = ProjectEngineeringNorth.fromDegrees(45);

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: session.current.version,
          command: _RenameSiteAndSetNorthCommand('Renamed Site', north),
        ),
      )!;

      expect(result.project.version, LocalProjectVersion(5));
      expect(result.project.index.site(SiteId('site-1'))?.name, 'Renamed Site');
      expect(result.project.engineeringMetadata.projectNorth, north);
      expect(result.changeSet.updatedEntityIds, <EntityId>{SiteId('site-1')});
      expect(
          result.changeSet.engineeringMetadataDiff.beforeProjectNorth, isNull);
      expect(result.changeSet.engineeringMetadataDiff.afterProjectNorth, north);
      expect(session.undoDepth, 1);

      final undone = session.undo(result.project.version)!;
      expect(undone.project.index.site(SiteId('site-1'))?.name, 'Site');
      expect(undone.project.engineeringMetadata.projectNorth, isNull);
    });
  });
}

ProjectAggregateRoot _project({ProjectEngineeringNorth? north}) {
  final siteId = SiteId('site-1');
  return ProjectAggregateRoot(
    id: ProjectId('project-1'),
    siteId: siteId,
    version: LocalProjectVersion(4),
    engineeringMetadata: ProjectEngineeringMetadata(projectNorth: north),
    stores: ProjectEntityStores(
      sites: <SiteId, ProjectSiteEntity>{
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Site',
          buildingIds: const <BuildingId>[],
        ),
      },
    ),
  );
}

final class _RenameSiteAndSetNorthCommand implements ProjectCommand {
  const _RenameSiteAndSetNorthCommand(this.name, this.north);

  final String name;
  final ProjectEngineeringNorth north;

  @override
  String get commandType => 'test.rename-site-and-set-project-north';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final site = current.index.site(current.siteId)!;
    final sites = Map<SiteId, ProjectSiteEntity>.from(current.stores.sites);
    sites[site.id] = ProjectSiteEntity(
      id: site.id,
      name: name,
      buildingIds: site.buildingIds,
    );

    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata:
            current.engineeringMetadata.withProjectNorth(north),
        stores: ProjectEntityStores(
          sites: sites,
          buildings: current.stores.buildings,
          levels: current.stores.levels,
          zones: current.stores.zones,
          spaces: current.stores.spaces,
        ),
      ),
    );
  }
}
