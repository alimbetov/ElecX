import 'dart:io';

import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/boundary_construction_registry.dart';
import 'package:elecx/src/domain/boundary_host_migration.dart';
import 'package:elecx/src/domain/electrical_routing.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/engine/adjacent_room_cable_router.dart';

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
        <String>{'Гостиная', 'Кухня', 'Спальня', 'Коридор'},
      );

      final placements = generated.document.p2State.components;
      expect(placements, hasLength(13));
      for (final entry in <ElectricalComponentType, int>{
        ElectricalComponentType.distributionBoard: 1,
        ElectricalComponentType.socketOutlet: 6,
        ElectricalComponentType.lightingPoint: 3,
        ElectricalComponentType.switchControl: 3,
      }.entries) {
        expect(placements.where((item) => item.type == entry.key),
            hasLength(entry.value));
      }
      final roomIds = activeLevel.level.spaces.map((room) => room.id).toSet();
      expect(placements.every((item) => roomIds.contains(item.surface.spaceId)),
          isTrue);
      // Fixture creation must never pre-apply an electrical proposal.
      expect(generated.document.p2State.routes, isEmpty);
      final decoded =
          EditorProjectDocument.fromJson(generated.document.toJson());
      expect(decoded.p2State.components.map((item) => item.id),
          placements.map((item) => item.id));

      final board = placements.singleWhere(
          (c) => c.type == ElectricalComponentType.distributionBoard);
      final socket = placements
          .firstWhere((c) => c.type == ElectricalComponentType.socketOutlet);
      final binding = generated.canonicalHandle.binding;
      final edgeOrder = {
        for (final id in generated.roomIds)
          binding.legacySpaceIds[id]!:
              handle.session.project.index.boundary(id)!.orderedEdgeIds,
      };
      final identities = SecureRandomEntityIdFactory();
      buildRoute() => AdjacentRoomCableRouter.build(
            level: activeLevel.level,
            source: board,
            target: socket,
            routeId: 'r4-test-route',
            edgeOrderBySpace: edgeOrder,
            canonicalSpaceIdResolver: binding.canonicalSpaceIdForLegacy,
            constructions: handle.session.project.engineeringMetadata
                .boundaryConstructionRegistry,
            identityFactory: identities,
          );
      expect(buildRoute, throwsStateError);
      // Explicit test construction evidence, never a fallback in the router.
      final profile = BoundaryConstructionProfile(
        kind: BoundaryConstructionKind.wall,
        thicknessMm: 100,
        materialId: 'test-partition',
      );
      final result = handle.session.boundaryConstructionEditing
          .setWallConstructions(profiles: {
        BoundaryEdgeHostRef(
            spaceId: generated.roomIds[3],
            edgeId: edgeOrder[board.surface.spaceId]!.first): profile,
        BoundaryEdgeHostRef(
            spaceId: generated.roomIds[0],
            edgeId: edgeOrder[socket.surface.spaceId]![2]): profile,
      }, expectedVersion: handle.session.project.version)!;
      handle.runtimeConfig.onCanonicalMutationCommitted!(
          handle.session, result);
      final routed = buildRoute();
      expect(routed.penetrations, hasLength(1));
      expect(routed.hiddenPenetrationLengthMm, 100);
      expect(routed.segments.map((s) => s.surface.spaceId).toSet(),
          {board.surface.spaceId, socket.surface.spaceId});
      expect(
          routed.segments.every((s) => s.anchorIds.length == s.points.length),
          isTrue);
      expect(
          ElectricalConnectivityValidator.routeIsConnected(
              route: routed, components: placements),
          isTrue);
      expect(
          ElectricalConnectivityValidator.routeIsPhysicallyAnchored(
              route: routed, components: placements),
          isTrue);

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
