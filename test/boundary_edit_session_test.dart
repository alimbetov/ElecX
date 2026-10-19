import 'package:elecx/src/domain/boundary_editing.dart';
import 'package:elecx/src/features/editor/boundary_edit_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('boundary edit session enters, switches profiles and exits cleanly', () {
    final session = BoundaryEditSession();

    expect(session.active, isFalse);

    session.enter();
    expect(session.active, isTrue);
    expect(session.profile, BoundaryEditProfile.wall);

    session.setProfile(BoundaryEditProfile.openings);
    session.hoverOpening('door-1');
    expect(session.profile, BoundaryEditProfile.openings);
    expect(session.hoveredOpeningId, 'door-1');

    session.setProfile(BoundaryEditProfile.structuralProfile);
    expect(session.hoveredOpeningId, isNull);

    session.exit();
    expect(session.active, isFalse);
    expect(session.profile, isNull);
    expect(session.hoveredOpeningId, isNull);
  });
}
