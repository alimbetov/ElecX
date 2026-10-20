import 'package:elecx/src/domain/electrical_placement.dart';
import 'package:elecx/src/domain/geometry.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/engine/port_snap_resolver.dart';
import 'package:elecx/src/engine/snap_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('port snap wins over grid and centers on component anchor', () {
    final surface = RoomSurfaceRef.wall('room-101', 0);
    final component = ElectricalComponentPlacement(
      id: 'socket-1',
      type: ElectricalComponentType.socketOutlet,
      surface: surface,
      position: const SurfacePointMm(1000, 1000),
      label: 'Socket',
      ports: ElectricalComponentDefaults.portsFor(
        ElectricalComponentType.socketOutlet,
      ),
    );

    final anchors = PortSnapResolver.anchorsFor(
      components: [component],
      surface: surface,
      role: CableEndpointRole.target,
    );
    final candidate = SnapEngine.resolve(
      SnapRequest(
        rawPoint: const MmPoint(990, 1000),
        acquisitionRadiusMm: 50,
        gridStepMm: 500,
        semanticAnchors: anchors,
      ),
    );

    expect(candidate, isNotNull);
    expect(candidate!.kind, SnapKind.port);
    expect(candidate.point.x, 1000);
    expect(candidate.point.y, 1000);
    expect(candidate.sourceId, 'socket-1:power-in');
  });

  test('captured port remains sticky until release radius is exceeded', () {
    final hysteresis = SnapHysteresis();
    const port = SnapCandidate(
      kind: SnapKind.port,
      point: MmPoint(1000, 1000),
      distanceMm: 5,
      sourceId: 'socket-1:power-in',
    );

    expect(
      hysteresis.resolve(
        rawPoint: const MmPoint(1005, 1000),
        candidate: port,
        releaseRadiusMm: 50,
      ),
      same(port),
    );
    expect(
      hysteresis.resolve(
        rawPoint: const MmPoint(1030, 1000),
        candidate: null,
        releaseRadiusMm: 50,
      ),
      same(port),
    );
    expect(
      hysteresis.resolve(
        rawPoint: const MmPoint(1100, 1000),
        candidate: null,
        releaseRadiusMm: 50,
      ),
      isNull,
    );
  });
}
