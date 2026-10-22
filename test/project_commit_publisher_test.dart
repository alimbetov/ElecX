import 'package:elecx/src/application/project/project_commit_publisher.dart';
import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('publishes exactly once for a successful canonical commit', () {
    final publisher = _RecordingPublisher();
    final session = PublishingProjectMutationSession(
      initial: _project(),
      publisher: publisher,
    );

    final result = session.commit(
      ProjectMutationRequest(
        expectedVersion: session.current.version,
        command: const _RenameSiteCommand('Renamed'),
      ),
    );

    expect(result, isNotNull);
    expect(publisher.events, hasLength(1));
    expect(publisher.events.single.project.version, LocalProjectVersion(5));
    expect(publisher.events.single.changeSet.updatedEntityIds, <EntityId>{
      SiteId('site-1'),
    });
  });

  test('does not publish preview, no-op or failed mutation', () {
    final publisher = _RecordingPublisher();
    final session = PublishingProjectMutationSession(
      initial: _project(),
      publisher: publisher,
    );

    session.preview(
      ProjectMutationRequest(
        expectedVersion: session.current.version,
        command: const _RenameSiteCommand('Preview'),
      ),
    );
    expect(publisher.events, isEmpty);

    final noOp = session.commit(
      ProjectMutationRequest(
        expectedVersion: session.current.version,
        command: const _RenameSiteCommand('Original Site'),
      ),
    );
    expect(noOp, isNull);
    expect(publisher.events, isEmpty);

    expect(
      () => session.commit(
        ProjectMutationRequest(
          expectedVersion: LocalProjectVersion(3),
          command: const _RenameSiteCommand('Stale'),
        ),
      ),
      throwsA(isA<StaleProjectMutationException>()),
    );
    expect(publisher.events, isEmpty);
  });

  test('publishes one event for undo and one for redo', () {
    final publisher = _RecordingPublisher();
    final session = PublishingProjectMutationSession(
      initial: _project(),
      publisher: publisher,
    );

    final committed = session.commit(
      ProjectMutationRequest(
        expectedVersion: session.current.version,
        command: const _RenameSiteCommand('Renamed'),
      ),
    )!;
    final undone = session.undo(committed.project.version)!;
    final redone = session.redo(undone.project.version)!;

    expect(redone.project.version, LocalProjectVersion(7));
    expect(publisher.events, hasLength(3));
    expect(publisher.events[0].changeSet.kind, ProjectChangeKind.command);
    expect(publisher.events[1].changeSet.kind, ProjectChangeKind.undo);
    expect(publisher.events[2].changeSet.kind, ProjectChangeKind.redo);
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

final class _RecordingPublisher implements ProjectCommitPublisher {
  final List<ProjectCommittedEvent> events = <ProjectCommittedEvent>[];

  @override
  void publish(ProjectCommittedEvent event) => events.add(event);
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
    );
  }
}
