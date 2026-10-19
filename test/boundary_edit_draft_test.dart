import 'package:elecx/src/domain/boundary_editing.dart';
import 'package:elecx/src/domain/surfaces.dart';
import 'package:elecx/src/features/editor/boundary_edit_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opening draft becomes dirty without changing source opening', () {
    final opening = ArchitecturalOpening(
      id: 'door',
      hostWall: RoomSurfaceRef.wall('room', 0),
      type: ArchitecturalOpeningType.door,
      offsetFromStartMm: 700,
      widthMm: 900,
      heightMm: 2100,
      sillHeightMm: 0,
    );
    final session = BoundaryEditSession()..enter(BoundaryEditProfile.openings);

    session.beginOpeningDraft(opening);
    session.updateOpeningDraft(
      session.openingDraft!.copyWith(widthMm: 1100, offsetFromStartMm: 850),
    );

    expect(session.draftDirty, isTrue);
    expect(session.openingDraft!.widthMm, 1100);
    expect(session.openingDraft!.offsetFromStartMm, 850);
    expect(opening.widthMm, 900);
    expect(opening.offsetFromStartMm, 700);
  });

  test('beam draft tracks dirty state and can be discarded', () {
    final session = BoundaryEditSession()
      ..enter(BoundaryEditProfile.structuralProfile)
      ..beginBeamDraft(
        BeamEditDraft.existing(startMm: 1000, widthMm: 800, depthMm: 300),
      );

    session.updateBeamDraft(session.beamDraft!.copyWith(depthMm: 450));
    expect(session.draftDirty, isTrue);
    expect(session.beamDraft!.depthMm, 450);

    session.discardDraft();
    expect(session.draftDirty, isFalse);
    expect(session.beamDraft, isNull);
  });
}
