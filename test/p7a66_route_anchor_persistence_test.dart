import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/selection_engine.dart';
import 'package:elecx/src/features/editor/editor_building_workspace.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_project_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P7A-6.6 route anchor persistence', () {
    test('schema v7 round-trip preserves durable route anchor ids exactly', () {
      final fixture = _routeDocumentJson();
      final json = fixture.json;
      final segment = fixture.segment;
      final pointCount = (segment['points']! as List).length;
      final expected = [
        for (var index = 0; index < pointCount; index++) 'stable-$index',
      ];
      segment['anchorIds'] = expected;

      final decoded = EditorProjectDocument.fromJson(json);
      final restoredIds = decoded
          .p2State.routes.single.segments.single.anchorIds
          .map((id) => id.value)
          .toList(growable: false);

      expect(decoded.schemaVersion, EditorProjectDocument.currentSchemaVersion);
      expect(decoded.schemaVersion, 7);
      expect(restoredIds, expected);
      final encodedRoute =
          ((decoded.toJson()['p2']! as Map)['routes']! as List).single as Map;
      final encodedSegment = (encodedRoute['segments']! as List).single as Map;
      expect(encodedSegment['anchorIds'], expected);
      expect(encodedRoute['penetrations'], isEmpty);
      fixture.dispose();
    });

    test('schema v5 migration never invents route anchor identity', () {
      final fixture = _routeDocumentJson();
      final json = fixture.json;
      json['schemaVersion'] = 5;
      fixture.segment.remove('anchorIds');
      final route = ((json['p2']! as Map)['routes']! as List).single as Map;
      route.remove('penetrations');

      final decoded = EditorProjectDocument.fromJson(json);

      expect(decoded.schemaVersion, 7);
      expect(decoded.p2State.routes.single.segments.single.anchorIds, isEmpty);
      expect(decoded.p2State.routes.single.penetrations, isEmpty);
      fixture.dispose();
    });

    test(
      'schema v6 explicitly migrates routes to empty penetration aggregate',
      () {
        final fixture = _routeDocumentJson();
        fixture.json['schemaVersion'] = 6;
        final route =
            ((fixture.json['p2']! as Map)['routes']! as List).single as Map;
        route.remove('penetrations');

        final decoded = EditorProjectDocument.fromJson(fixture.json);

        expect(decoded.schemaVersion, 7);
        expect(decoded.p2State.routes.single.penetrations, isEmpty);
        final encodedRoute =
            ((decoded.toJson()['p2']! as Map)['routes']! as List).single as Map;
        expect(encodedRoute['penetrations'], isEmpty);
        fixture.dispose();
      },
    );

    test('schema v7 rejects anchor count that differs from route points', () {
      final fixture = _routeDocumentJson();
      fixture.segment['anchorIds'] = ['only-one'];

      expect(
        () => EditorProjectDocument.fromJson(fixture.json),
        throwsFormatException,
      );
      fixture.dispose();
    });

    test('schema v7 rejects duplicate durable anchor ids route-wide', () {
      final fixture = _routeDocumentJson();
      final pointCount = (fixture.segment['points']! as List).length;
      fixture.segment['anchorIds'] = [
        for (var index = 0; index < pointCount; index++)
          index < 2 ? 'duplicate' : 'stable-$index',
      ];

      expect(
        () => EditorProjectDocument.fromJson(fixture.json),
        throwsFormatException,
      );
      fixture.dispose();
    });

    test('schema v7 rejects projection-only transition anchor identity', () {
      final fixture = _routeDocumentJson();
      final pointCount = (fixture.segment['points']! as List).length;
      fixture.segment['anchorIds'] = [
        for (var index = 0; index < pointCount; index++)
          index == 1 ? 'p7a-transition:synthetic' : 'stable-$index',
      ];

      expect(
        () => EditorProjectDocument.fromJson(fixture.json),
        throwsFormatException,
      );
      fixture.dispose();
    });
  });
}

_RouteJsonFixture _routeDocumentJson() {
  final editor = EditorController.demo();
  final workspace = EditorBuildingWorkspace.demo(editor);
  final wall = RoomSurfaceRef.wall(editor.selectedSpace!.id, 0);
  final source = editor.p2.placeComponent(
    type: ElectricalComponentType.powerSource,
    surface: wall,
    position: const SurfacePointMm(200, 1200),
  );
  final target = editor.p2.placeComponent(
    type: ElectricalComponentType.socketOutlet,
    surface: wall,
    position: const SurfacePointMm(1600, 2400),
  );
  editor.p2.select(source.id);
  editor.p2.select(target.id, mode: SelectionMode.add);
  if (!editor.p2.autoRouteSelectedPair()) {
    throw StateError('P7A-6.6 fixture failed to create a route.');
  }
  final json = EditorProjectDocument.capture(workspace).toJson();
  final p2 = json['p2']! as Map<String, Object?>;
  final route = (p2['routes']! as List).single as Map<String, Object?>;
  final segment = (route['segments']! as List).single as Map<String, Object?>;
  return _RouteJsonFixture(
    editor: editor,
    workspace: workspace,
    json: json,
    segment: segment,
  );
}

final class _RouteJsonFixture {
  _RouteJsonFixture({
    required this.editor,
    required this.workspace,
    required this.json,
    required this.segment,
  });

  final EditorController editor;
  final EditorBuildingWorkspace workspace;
  final Map<String, Object?> json;
  final Map<String, Object?> segment;

  void dispose() {
    editor.disposeP2State();
    workspace.dispose();
    editor.dispose();
  }
}
