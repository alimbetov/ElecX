import 'dart:io';

import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/features/editor/canonical_editor_demo_generation.dart';
import 'package:elecx/src/features/editor/canonical_editor_production_bootstrap.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:elecx/src/features/editor/initial_editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/infrastructure/project/json_project_repository.dart';
import 'package:elecx/src/serialization/project/engineering_state_aware_canonical_project_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('production demo generation', () {
    test('creates four canonical rooms, materializes them and survives reopen',
        () async {
      final root =
          await Directory.systemTemp.createTemp('elecx-demo-generation-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final repository = _repository(root);
      final initial = _initial();
      final handle = await CanonicalEditorProductionHandle.loadOrBootstrap(
        legacyDocument: initial,
        repository: repository,
      );

      final generated = await const CanonicalEditorDemoGenerator().generate(
        initialDocument: initial,
        handle: handle,
      );

      expect(generated.roomIds, hasLength(4));
      expect(handle.owner.project, same(handle.session.project));
      expect(handle.owner.project.stores.spaces, hasLength(4));
      expect(handle.owner.project.stores.boundaries, hasLength(4));
      expect(
        handle.owner.project.stores.spaces.values
            .every((space) => space.type == ProjectSpaceType.room),
        isTrue,
      );
      for (final roomId in generated.roomIds) {
        expect(
            handle.owner.project.index.boundary(roomId)!.validate(), isEmpty);
      }

      final activeLevel = generated.document.building
          .levelByNumber(generated.document.activeLevelNumber)!;
      expect(activeLevel.level.spaces, hasLength(4));
      expect(
        activeLevel.level.spaces.map((room) => room.name).toSet(),
        <String>{'Гостиная', 'Кухня', 'Спальня', 'Санузел'},
      );

      final reopened = await CanonicalEditorProductionHandle.loadOrBootstrap(
        legacyDocument: generated.document,
        repository: repository,
      );
      expect(reopened.owner.project.stores.spaces.keys.toSet(),
          handle.owner.project.stores.spaces.keys.toSet());
      for (final roomId in generated.roomIds) {
        expect(
            reopened.owner.project.index.boundary(roomId)!.validate(), isEmpty);
      }
    });

    test('fails closed when demo generation is requested twice', () async {
      final root = await Directory.systemTemp.createTemp('elecx-demo-repeat-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final repository = _repository(root);
      final initial = _initial(projectId: 'demo-repeat');
      final handle = await CanonicalEditorProductionHandle.loadOrBootstrap(
        legacyDocument: initial,
        repository: repository,
      );
      final generated = await const CanonicalEditorDemoGenerator().generate(
        initialDocument: initial,
        handle: handle,
      );
      final beforeVersion = generated.canonicalHandle.owner.version;
      final beforeSpaces =
          generated.canonicalHandle.owner.project.stores.spaces.keys.toSet();

      await expectLater(
        const CanonicalEditorDemoGenerator().generate(
          initialDocument: generated.document,
          handle: generated.canonicalHandle,
        ),
        throwsStateError,
      );
      expect(generated.canonicalHandle.owner.version, beforeVersion);
      expect(
        generated.canonicalHandle.owner.project.stores.spaces.keys.toSet(),
        beforeSpaces,
      );
    });
  });
}

JsonProjectRepository _repository(Directory root) => JsonProjectRepository(
      rootDirectory: root,
      codec: const EngineeringStateAwareCanonicalProjectDocumentCodec(),
    );

EditorProjectDocument _initial({String projectId = 'demo-project'}) =>
    createInitialEditorProjectDocument(
      EditorProjectMetadata.create(
        projectName: 'Demo Project',
        projectId: projectId,
        now: DateTime.utc(2026, 10, 31, 15),
      ),
    );
