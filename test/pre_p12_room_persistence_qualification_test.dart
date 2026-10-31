import 'dart:convert';
import 'dart:io';

import 'package:elecx/src/application/project/project_room_rectangle_authoring.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/features/editor/canonical_editor_production_bootstrap.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/initial_editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/engineering_state_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PRE-P12 PQ09/PQ10 room persistence qualification', () {
    test(
      'PQ09 fresh repository and production handle reopen exact room topology',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'elecx-pre-p12-pq09-',
        );
        addTearDown(() async {
          if (await root.exists()) await root.delete(recursive: true);
        });

        final legacy = _initial('pre-p12-pq09', 'PRE-P12 PQ09');
        final first = await CanonicalEditorProductionHandle.loadOrBootstrap(
          legacyDocument: legacy,
          repository: _repository(root),
        );
        final levelId = first.session.navigation.activeLevelId!;
        final authored = RoomRectangleAuthoringService(
          session: first.session,
          mutations: first.wizardMutations,
        ).commit(
          RoomRectangleAuthoringIntent(
            levelId: levelId,
            first: const BoundaryPointMm(xMm: 1200, yMm: 1800),
            second: const BoundaryPointMm(xMm: 5600, yMm: 4900),
            name: 'PQ09 Room',
          ),
        );

        first.runtimeConfig.onCanonicalMutationCommitted!(
          first.session,
          authored.commit.mutation,
        );
        await first.saveCanonical();

        final committed = first.owner.project;
        final committedFingerprint = _fingerprint(committed);
        final committedTopology = committed.index.boundary(authored.spaceId)!;
        final committedEdgeIds = committedTopology.orderedEdgeIds
            .map((id) => id.value)
            .toList(growable: false);
        final committedVersion = committed.version;
        final persistedFile = _projectFile(root);
        final persistedJson = await persistedFile.readAsString();
        final envelope = jsonDecode(persistedJson) as Map<String, dynamic>;
        expect(envelope['schemaVersion'], 20);

        final reopened = await CanonicalEditorProductionHandle.loadOrBootstrap(
          legacyDocument: legacy,
          repository: _repository(root),
        );
        final reopenedRoom =
            reopened.owner.project.index.space(authored.spaceId);
        final reopenedTopology =
            reopened.owner.project.index.boundary(authored.spaceId);

        expect(reopenedRoom, isNotNull);
        expect(reopenedRoom!.levelId, levelId);
        expect(reopenedRoom.name, 'PQ09 Room');
        expect(reopenedTopology, isNotNull);
        expect(
          reopenedTopology!.orderedEdgeIds.map((id) => id.value).toList(),
          committedEdgeIds,
        );
        expect(reopenedTopology.validate(), isEmpty);
        expect(reopened.owner.project.version, committedVersion);
        expect(_fingerprint(reopened.owner.project), committedFingerprint);
      },
    );

    test(
      'PQ10 repeated save and fresh reopen stays byte and identity stable',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'elecx-pre-p12-pq10-',
        );
        addTearDown(() async {
          if (await root.exists()) await root.delete(recursive: true);
        });

        final legacy = _initial('pre-p12-pq10', 'PRE-P12 PQ10');
        var handle = await CanonicalEditorProductionHandle.loadOrBootstrap(
          legacyDocument: legacy,
          repository: _repository(root),
        );
        final levelId = handle.session.navigation.activeLevelId!;
        final authored = RoomRectangleAuthoringService(
          session: handle.session,
          mutations: handle.wizardMutations,
        ).commit(
          RoomRectangleAuthoringIntent(
            levelId: levelId,
            first: const BoundaryPointMm(xMm: -2500, yMm: 750),
            second: const BoundaryPointMm(xMm: 3250, yMm: 5150),
            name: 'PQ10 Stable Room',
          ),
        );
        handle.runtimeConfig.onCanonicalMutationCommitted!(
          handle.session,
          authored.commit.mutation,
        );
        await handle.saveCanonical();

        final baselineFingerprint = _fingerprint(handle.owner.project);
        final baselineVersion = handle.owner.version;
        final baselineSpaceCount = handle.owner.project.stores.spaces.length;
        final baselineBoundaryCount =
            handle.owner.project.stores.boundaries.length;
        final baselineBytes = await _projectFile(root).readAsString();
        final baselineEdgeIds = handle.owner.project.index
            .boundary(authored.spaceId)!
            .orderedEdgeIds
            .map((id) => id.value)
            .toList(growable: false);

        for (var cycle = 1; cycle <= 3; cycle++) {
          handle = await CanonicalEditorProductionHandle.loadOrBootstrap(
            legacyDocument: legacy,
            repository: _repository(root),
          );

          expect(handle.owner.version, baselineVersion, reason: 'cycle $cycle');
          expect(
            handle.owner.project.stores.spaces.length,
            baselineSpaceCount,
            reason: 'cycle $cycle',
          );
          expect(
            handle.owner.project.stores.boundaries.length,
            baselineBoundaryCount,
            reason: 'cycle $cycle',
          );
          expect(
            _fingerprint(handle.owner.project),
            baselineFingerprint,
            reason: 'cycle $cycle',
          );
          expect(
            handle.owner.project.index
                .boundary(authored.spaceId)!
                .orderedEdgeIds
                .map((id) => id.value)
                .toList(),
            baselineEdgeIds,
            reason: 'cycle $cycle',
          );

          await handle.saveCanonical();
          expect(
            await _projectFile(root).readAsString(),
            baselineBytes,
            reason: 'cycle $cycle',
          );
        }
      },
    );
  });
}

JsonProjectRepository _repository(Directory root) => JsonProjectRepository(
      rootDirectory: root,
      codec: const EngineeringStateAwareCanonicalProjectDocumentCodec(),
    );

EditorProjectDocument _initial(String projectId, String projectName) =>
    createInitialEditorProjectDocument(
      EditorProjectMetadata.create(
        projectName: projectName,
        projectId: projectId,
        now: DateTime.utc(2026, 10, 31, 12),
      ),
    );

File _projectFile(Directory root) =>
    root.listSync().whereType<File>().singleWhere(
          (file) => file.path.endsWith('.elecx.project.json'),
        );

String _fingerprint(ProjectAggregateRoot project) {
  final sites = project.stores.sites.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value));
  final buildings = project.stores.buildings.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value));
  final levels = project.stores.levels.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value));
  final spaces = project.stores.spaces.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value));
  final boundaries = project.stores.boundaries.entries.toList()
    ..sort((a, b) => a.key.value.compareTo(b.key.value));

  return <String>[
    'P|${project.id.value}|${project.siteId.value}|${project.version.value}',
    for (final site in sites)
      'S|${site.id.value}|${site.name}|'
          '${site.buildingIds.map((id) => id.value).join(',')}',
    for (final building in buildings)
      'B|${building.id.value}|${building.siteId.value}|${building.name}|'
          '${building.levelIds.map((id) => id.value).join(',')}',
    for (final level in levels)
      'L|${level.id.value}|${level.buildingId.value}|${level.name}|'
          '${level.levelNumber}|${level.elevationMm}|'
          '${level.spaceIds.map((id) => id.value).join(',')}',
    for (final space in spaces)
      'R|${space.id.value}|${space.levelId.value}|${space.name}',
    for (final entry in boundaries)
      'T|${entry.key.value}|'
          '${entry.value.orderedEdgeIds.map((id) => id.value).join(',')}|'
          '${entry.value.orderedEdgeIds.map((id) {
        final edge = entry.value.edges[id]!;
        return '${edge.start.xMm},${edge.start.yMm}>'
            '${edge.end.xMm},${edge.end.yMm}';
      }).join(';')}',
  ].join('\n');
}
