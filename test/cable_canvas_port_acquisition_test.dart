import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/cable_canvas_port_acquisition.dart';
import 'package:elecx/src/features/editor/port_driven_cable_authoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final wall = RoomSurfaceRef.wall('room-101', 0);
  final otherWall = RoomSurfaceRef.wall('room-101', 1);

  PortDrivenCableCompletionTarget target(
    String componentId,
    int x, {
    int y = 1200,
    String portId = 'power-in',
    RoomSurfaceRef? surface,
  }) =>
      PortDrivenCableCompletionTarget(
        componentId: componentId,
        componentLabel: componentId,
        portId: portId,
        portKind: ElectricalPortKind.powerIn,
        role: PortDrivenCableEndpointRole.target,
        surface: surface ?? wall,
        position: SurfacePointMm(x, y),
      );

  group('P12A.3 canvas semantic port acquisition', () {
    test('chooses nearest compatible exact port rather than grid', () {
      final socket = target('socket', 2200);
      final far = target('far', 3600);
      final hit = CableCanvasPortAcquisition.resolve(
        targets: [socket, far],
        surface: wall,
        rawPoint: const SurfacePointMm(2213, 1208),
        acquisitionRadiusMm: 150,
      );
      expect(hit?.componentId, socket.componentId);
      expect(hit?.portId, socket.portId);
      expect(hit?.position, socket.position);
    });

    test('rejects out-of-range and other-host ports', () {
      expect(
        CableCanvasPortAcquisition.resolve(
          targets: [target('socket', 2200)],
          surface: wall,
          rawPoint: const SurfacePointMm(1800, 1200),
          acquisitionRadiusMm: 100,
        ),
        isNull,
      );
      expect(
        CableCanvasPortAcquisition.resolve(
          targets: [target('socket', 2200, surface: otherWall)],
          surface: wall,
          rawPoint: const SurfacePointMm(2200, 1200),
          acquisitionRadiusMm: 100,
        ),
        isNull,
      );
    });

    test('co-located and equidistant ports fail closed', () {
      expect(
        CableCanvasPortAcquisition.resolve(
          targets: [target('first', 2200), target('second', 2200)],
          surface: wall,
          rawPoint: const SurfacePointMm(2200, 1200),
          acquisitionRadiusMm: 100,
        ),
        isNull,
      );
      expect(
        CableCanvasPortAcquisition.resolve(
          targets: [target('first', 2100), target('second', 2300)],
          surface: wall,
          rawPoint: const SurfacePointMm(2200, 1200),
          acquisitionRadiusMm: 120,
        ),
        isNull,
      );
    });
  });
}
