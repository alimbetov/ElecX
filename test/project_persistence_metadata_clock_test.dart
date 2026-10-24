import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EditorProjectMetadata monotonic time', () {
    final createdAt = DateTime.utc(2026, 10, 24, 11);

    test('touch advances when observed wall clock moves forward', () {
      final metadata = EditorProjectMetadata.create(
        projectId: 'clock-forward',
        projectName: 'Clock forward',
        now: createdAt,
      );
      final later = createdAt.add(const Duration(minutes: 5));

      final touched = metadata.touch(later);

      expect(touched.createdAt, createdAt);
      expect(touched.updatedAt, later);
    });

    test('touch never moves updatedAt backwards after clock rollback', () {
      final metadata = EditorProjectMetadata.create(
        projectId: 'clock-rollback',
        projectName: 'Clock rollback',
        now: createdAt,
      ).touch(createdAt.add(const Duration(minutes: 5)));
      final rolledBackClock = createdAt.subtract(const Duration(hours: 2));

      final touched = metadata.touch(rolledBackClock);

      expect(touched.updatedAt, metadata.updatedAt);
      expect(touched.updatedAt.isBefore(touched.createdAt), isFalse);
    });

    test('repeated equal-time touch is timeline-idempotent', () {
      final metadata = EditorProjectMetadata.create(
        projectId: 'clock-equal',
        projectName: 'Clock equal',
        now: createdAt,
      );

      final touched = metadata.touch(createdAt);

      expect(touched.updatedAt, metadata.updatedAt);
    });

    test('explicit invalid copyWith timestamp still fails closed', () {
      final metadata = EditorProjectMetadata.create(
        projectId: 'clock-invalid',
        projectName: 'Clock invalid',
        now: createdAt,
      );

      expect(
        () => metadata.copyWith(
          updatedAt: createdAt.subtract(const Duration(microseconds: 1)),
        ),
        throwsArgumentError,
      );
    });
  });
}
