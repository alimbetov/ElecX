import 'dart:math';

import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P11.8 production id factory allocates all P11 aggregate identities',
      () {
    final EntityIdFactory factory = SecureRandomEntityIdFactory(
      random: Random(11),
    );

    final loopId = factory.newLoopId();
    final groupId = factory.newEngineeringGroupId();
    final sourceId = factory.newEngineeringSupplySourceId();

    expect(loopId, isA<LoopId>());
    expect(groupId, isA<EngineeringGroupId>());
    expect(sourceId, isA<EngineeringSupplySourceId>());
    expect(
      {loopId.value, groupId.value, sourceId.value},
      hasLength(3),
    );
    for (final value in [loopId.value, groupId.value, sourceId.value]) {
      expect(
        value,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    }
  });
}
