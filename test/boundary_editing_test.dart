import 'package:elecx/src/domain/boundary_editing.dart';
import 'package:elecx/src/domain/wall_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rectangular wall has no structural profile segments', () {
    final profile = WallProfile.rectangle(widthMm: 4200, heightMm: 3000);

    final segments = BoundaryEditingResolver.structuralSegments(
      profile: profile,
      wallHeightMm: 3000,
    );

    expect(segments, isEmpty);
  });

  test('top notch exposes only beam/notch boundary segments', () {
    final profile = WallProfile(
      vertices: const [
        WallProfilePoint(0, 0),
        WallProfilePoint(4200, 0),
        WallProfilePoint(4200, 3000),
        WallProfilePoint(2800, 3000),
        WallProfilePoint(2800, 2650),
        WallProfilePoint(1800, 2650),
        WallProfilePoint(1800, 3000),
        WallProfilePoint(0, 3000),
      ],
    );

    final segments = BoundaryEditingResolver.structuralSegments(
      profile: profile,
      wallHeightMm: 3000,
    );

    expect(segments, hasLength(3));
    expect(segments[0].a, const WallProfilePoint(2800, 3000));
    expect(segments[0].b, const WallProfilePoint(2800, 2650));
    expect(segments[1].a, const WallProfilePoint(2800, 2650));
    expect(segments[1].b, const WallProfilePoint(1800, 2650));
    expect(segments[2].a, const WallProfilePoint(1800, 2650));
    expect(segments[2].b, const WallProfilePoint(1800, 3000));
  });
}
