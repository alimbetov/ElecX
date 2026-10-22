import 'package:elecx/src/domain/installation_guides.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('residential project preset creates wall socket/switch lines and ceiling axes', () {
    final guides = InstallationGuideFactory.forRoom(
      roomId: 'room-1',
      wallCount: 4,
    );

    expect(guides.length, 9);
    expect(
      guides.where(
        (guide) => guide.kind == InstallationGuideKind.socketMountingLine,
      ),
      hasLength(4),
    );
    expect(
      guides.where(
        (guide) => guide.kind == InstallationGuideKind.switchMountingLine,
      ),
      hasLength(4),
    );
    expect(
      guides
          .singleWhere(
            (guide) => guide.kind == InstallationGuideKind.ceilingLightingAxis,
          )
          .surface,
      RoomSurfaceRef.ceiling('room-1'),
    );
  });

  test('300/900 residential values are explicitly project presets, not normative rules', () {
    final guides = InstallationGuideFactory.forRoom(
      roomId: 'room-1',
      wallCount: 1,
    );

    final socket = guides.singleWhere(
      (guide) => guide.kind == InstallationGuideKind.socketMountingLine,
    );
    final lightSwitch = guides.singleWhere(
      (guide) => guide.kind == InstallationGuideKind.switchMountingLine,
    );

    expect(socket.offsetMm, 300);
    expect(lightSwitch.offsetMm, 900);
    expect(socket.authority, InstallationGuideAuthority.projectPreset);
    expect(lightSwitch.authority, InstallationGuideAuthority.projectPreset);
    expect(socket.source, isNull);
    expect(lightSwitch.source, isNull);
  });

  test('custom project profile changes mounting lines without changing normative semantics', () {
    const profile = InstallationGuideProfile(
      id: 'custom',
      name: 'Custom project',
      socketHeightMm: 450,
      switchHeightMm: 1050,
      showCeilingCenterAxes: false,
      showCeilingGrid: true,
    );

    final guides = InstallationGuideFactory.forRoom(
      roomId: 'room-2',
      wallCount: 2,
      profile: profile,
    );

    expect(guides.where((guide) => guide.offsetMm == 450), hasLength(2));
    expect(guides.where((guide) => guide.offsetMm == 1050), hasLength(2));
    expect(
      guides.where(
        (guide) => guide.kind == InstallationGuideKind.ceilingLightingAxis,
      ),
      isEmpty,
    );
    expect(
      guides.where(
        (guide) => guide.kind == InstallationGuideKind.ceilingLightingGrid,
      ),
      hasLength(1),
    );
  });
}
