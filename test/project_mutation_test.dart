import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectMutationSession', () {
    test('commits one command as one version and one undo boundary', () {
      final session = ProjectMutationSession(_project());

      final result = session.commit(
        ProjectMutationRequest(
          expectedVersion: LocalProjectVersion(4),
          command: const _RenameSiteCommand('Renamed Site'),
        ),
      );

      expect(result.project.version, LocalProjectVersion(5));
      expect(result.project.index.site(SiteId('site-1'))?.name, 'Renamed Site');
      expect(result.changeSet.kind, ProjectChangeKind.command);
      expect(result.changeSet.beforeVersion, LocalProjectVersion(4));
      expect(result.changeSet.afterVersion, LocalProjectVersion(5));
      expect(result.changeSet.affectedEntityIds, contains(SiteId('site-1')));
      expect(session.undoDepth, 1);
      expect(session.redoDepth, 0);
    });

    test('preview validates candidate without mutating project or history', () {
      final initial = _project();
      final session = ProjectMutationSession(initial);

      final preview = session.preview(
        ProjectMutationRequest(
          expectedVersion: initial.version,
          command: const _RenameSiteCommand('Preview Site'),
        ),
      );

      expect(preview.candidate.version, initial.version);
      expect(
        preview.candidate.index.site(SiteId('site-1'))?.name,
        'Preview Site',
      );
      expect(session.current, same(initial));
      expect(session.current.index.site(SiteId('site-1'))?.name, 'Original Site');
      expect(session.undoDepth, 0);
      expect(session.redoDepth, 0);
    });

    test('stale command fails closed without changing state or history', () {
      final initial = _project();
      final session = ProjectMutationSession(initial);

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: LocalProjectVersion(3),
            command: const _RenameSiteCommand('Stale'),
          ),
        ),
        throwsA(isA<StaleProjectMutationException>()),
      );

      expect(session.current, same(initial));
      expect(session.current.version, LocalProjectVersion(4));
      expect(session.undoDepth, 0);
      expect(session.redoDepth, 0);
    });

    test('invalid candidate fails closed and does not advance version', () {
      final initial = _project();
      final session = ProjectMutationSession(initial);

      expect(
        () => session.commit(
          ProjectMutationRequest(
            expectedVersion: initial.version,
            command: const _AddUnexpectedSiteCommand(),
          ),
        ),
        throwsA(isA<ProjectCandidateValidationException>()),
      );

      expect(session.current, same(initial));
      expect(session.current.version, LocalProjectVersion(4));
      expect(session.undoDepth, 0);
    });

    test('undo and redo are monotonic canonical commits', () {
      final session = ProjectMutationSession(_project());
      final committed = session.commit(
        ProjectMutationRequest(
          expectedVersion: LocalProjectVersion(4),
          command: const _RenameSiteCommand('Renamed Site'),
        ),
      );

      final undone = session.undo(committed.project.version);
      expect(undone, isNotNull);
      expect(undone!.changeSet.kind, ProjectChangeKind.undo);
      expect(undone.project.version, LocalProjectVersion(6));
      expect(
        undone.project.index.site(SiteId('site-1'))?.name,
        'Original Site',
      );
      expect(session.undoDepth, 0);
      expect(session.redoDepth, 1);

      final redone = session.redo(undone.project.version);
      expect(redone, isNotNull);
      expect(redone!.changeSet.kind, ProjectChangeKind.redo);
      expect(redone.project.version, LocalProjectVersion(7));
      expect(
        redone.project.index.site(SiteId('site-1'))?.name,
        'Renamed Site',
      );
      expect(session.undoDepth, 1);
      expect(session.redoDepth, 0);
    });

    test('new command after undo clears redo history', () {
      final session = ProjectMutationSession(_project());
      final first = session.commit(
        ProjectMutationRequest(
          expectedVersion: LocalProjectVersion(4),
          command: const _RenameSiteCommand('First'),
        ),
      );
      final undone = session.undo(first.project.version)!;

      session.commit(
        ProjectMutationRequest(
          expectedVersion: undone.project.version,
          command: const _RenameSiteCommand('Second'),
        ),
      );

      expect(session.redoDepth, 0);
      expect(session.canRedo, isFalse);
      expect(session.current.version, LocalProjectVersion(7));
      expect(session.current.index.site(SiteId('site-1'))?.name, 'Second');
    });

    test('stale undo and redo requests do not consume history', () {
      final session = ProjectMutationSession(_project());
      final committed = session.commit(
        ProjectMutationRequest(
          expectedVersion: LocalProjectVersion(4),
          command: const _RenameSiteCommand('Renamed'),
        ),
      );

      expect(
        () => session.undo(LocalProjectVersion(4)),
        throwsA(isA<StaleProjectMutationException>()),
      );
      expect(session.undoDepth, 1);

      final undone = session.undo(committed.project.version)!;
      expect(
        () => session.redo(LocalProjectVersion(5)),
        throwsA(isA<StaleProjectMutationException>()),
      );
      expect(session.redoDepth, 1);
      expect(session.current.version, undone.project.version);
    });
  });

  test('ProjectChangeSet rejects version jumps', () {
    expect(
      () => ProjectChangeSet(
        kind: ProjectChangeKind.command,
        commandType: 'test.jump',
        beforeVersion: LocalProjectVersion(1),
        afterVersion: LocalProjectVersion(3),
      ),
      throwsArgumentError,
    );
  });
}

ProjectAggregateRoot _project() {
  final siteId = SiteId('site-1');
  return ProjectAggregateRoot(
    id: ProjectId('project-1'),
    siteId: siteId,
    version: LocalProjectVersion(4),
    stores: ProjectEntityStores(
      sites: <SiteId, ProjectSiteEntity>{
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'Original Site',
          buildingIds: const <BuildingId>[],
        ),
      },
    ),
  );
}

final class _RenameSiteCommand implements ProjectCommand {
  const _RenameSiteCommand(this.name);

  final String name;

  @override
  String get commandType => 'test.rename-site';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final site = current.index.site(current.siteId)!;
    final sites = Map<SiteId, ProjectSiteEntity>.from(current.stores.sites);
    sites[site.id] = ProjectSiteEntity(
      id: site.id,
      name: name,
      buildingIds: site.buildingIds,
    );

    return ProjectCommandCandidate(
      stores: ProjectEntityStores(
        sites: sites,
        buildings: current.stores.buildings,
        levels: current.stores.levels,
        zones: current.stores.zones,
        spaces: current.stores.spaces,
      ),
      affectedEntityIds: <EntityId>[site.id],
    );
  }
}

final class _AddUnexpectedSiteCommand implements ProjectCommand {
  const _AddUnexpectedSiteCommand();

  @override
  String get commandType => 'test.add-unexpected-site';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final sites = Map<SiteId, ProjectSiteEntity>.from(current.stores.sites);
    final unexpectedId = SiteId('site-2');
    sites[unexpectedId] = ProjectSiteEntity(
      id: unexpectedId,
      name: 'Unexpected Site',
      buildingIds: const <BuildingId>[],
    );

    return ProjectCommandCandidate(
      stores: ProjectEntityStores(
        sites: sites,
        buildings: current.stores.buildings,
        levels: current.stores.levels,
        zones: current.stores.zones,
        spaces: current.stores.spaces,
      ),
      affectedEntityIds: <EntityId>[unexpectedId],
    );
  }
}
