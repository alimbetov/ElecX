import 'package:drift/drift.dart';
import 'package:elecx/src/data/drift_component_catalog_repository.dart';
import 'package:elecx/src/domain/component_catalog_v2.dart';
import 'package:elecx/src/domain/engineering_graph.dart';
import 'package:flutter_test/flutter_test.dart';

/// No schema/query/delete/transaction call is allowed before evidence rejection.
class _NoIoDatabase implements GeneratedDatabase {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('Unexpected database operation: ${invocation.memberName}');
  }
}

void main() {
  for (final withMedium in [true, false]) {
    test(
      'P11 catalog rejects unsupported ${withMedium ? 'media' : 'capabilities'} before storage mutation',
      () async {
        final base = ComponentCatalogV2.entries.first;
        final entry = ComponentCatalogEntryV2(
          id: 'extension',
          code: 'extension',
          name: 'Extension',
          discipline: base.discipline,
          systemClass: base.systemClass,
          calculationKind: base.calculationKind,
          mounting: base.mounting,
          environment: base.environment,
          ports: [
            EngineeringPortSpec(
              id: 'port',
              direction: EngineeringPortDirection.input,
              allowedConnections: {EngineeringConnectionType.custom},
              media: withMedium ? {EngineeringMedia.acPower} : {},
              capabilities: withMedium
                  ? {}
                  : {EngineeringPortCapability('vendor.protocol')},
            ),
          ],
        );
        final db = _NoIoDatabase();
        await expectLater(
          DriftComponentCatalogRepository(db).replaceAll([base, entry]),
          throwsUnsupportedError,
        );
        expect(db.calls, 0);
      },
    );
  }
}
