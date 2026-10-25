import 'package:elecx/src/application/project/wizard/apartment/apartment_geometry_access_validator.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_geometry.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_semantic_validation.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_draft.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_models.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = ApartmentGeometryAccessValidator();

  group('P9.6 post-packing semantic geometry contract', () {
    test('qualified baseline satisfies access/boundary/entry/exposure handoff', () {
      final report = validator.validate(
        candidate: _candidate(),
        handoff: _handoff(),
      );

      expect(report.accepted, isTrue);
      expect(report.issues, isEmpty);
    });

    test('required shared boundary shorter than semantic minimum is rejected', () {
      final shortShared = _segment(2000, 0, 2000, 1100);
      final report = validator.validate(
        candidate: _candidate(
          sharedBoundary: shortShared,
          internalOpeningHost: shortShared,
        ),
        handoff: _handoff(minSharedBoundaryMm: 1200),
      );

      expect(report.accepted, isFalse);
      expect(
        report.issues.map((issue) => issue.code),
        contains('p9.geometry.shared-boundary-too-short'),
      );
    });

    test('reachable primary entry on the wrong semantic space is rejected', () {
      final livingEast = _segment(4000, 0, 4000, 2000);
      final report = validator.validate(
        candidate: _candidate(
          entrySpaceKey: 'livingRoom:1',
          entryHost: livingEast,
        ),
        handoff: _handoff(),
      );

      expect(report.accepted, isFalse);
      expect(
        report.issues.map((issue) => issue.code),
        contains('p9.geometry.entry-space-mismatch'),
      );
    });

    test('primary entry must be hosted by exterior edge of its entry space', () {
      final livingEast = _segment(4000, 0, 4000, 2000);
      final report = validator.validate(
        candidate: _candidate(entryHost: livingEast),
        handoff: _handoff(),
      );

      expect(report.accepted, isFalse);
      expect(
        report.issues.map((issue) => issue.code),
        contains('p9.geometry.entry-host-mismatch'),
      );
    });

    test('semantic exterior side assignment must survive geometry', () {
      final report = validator.validate(
        candidate: _candidate(),
        handoff: _handoff(livingSide: DraftExteriorSide.west),
      );

      expect(report.accepted, isFalse);
      expect(
        report.issues.map((issue) => issue.code),
        contains('p9.geometry.exterior-side-mismatch'),
      );
    });
  });
}

ApartmentGeometryCandidate _candidate({
  GeometrySegmentMm? sharedBoundary,
  GeometrySegmentMm? internalOpeningHost,
  GeometrySegmentMm? entryHost,
  String entrySpaceKey = 'entranceHall:1',
}) {
  final shared = sharedBoundary ?? _segment(2000, 0, 2000, 2000);
  final openingHost = internalOpeningHost ?? shared;
  final entranceWest = _segment(0, 0, 0, 2000);
  final livingEast = _segment(4000, 0, 4000, 2000);

  return ApartmentGeometryCandidate(
    templateId: TemplateId('p9-access-validator-fixture'),
    templateVersion: 1,
    family: ApartmentTopologyFamily.compact,
    variantSeedId: 'fixture-seed',
    areaFitFingerprint: 'area-fit-fixture',
    interiorEnvelope: RectilinearPolygonMm.rectangle(
      xMm: 0,
      yMm: 0,
      widthMm: 4000,
      heightMm: 2000,
    ),
    interiorSpaces: [
      GeneratedSpaceGeometry(
        semanticKey: 'entranceHall:1',
        participation: SpaceAreaParticipation.requestedInteriorArea,
        polygon: RectilinearPolygonMm.rectangle(
          xMm: 0,
          yMm: 0,
          widthMm: 2000,
          heightMm: 2000,
        ),
        fittedAreaDm2: 400,
      ),
      GeneratedSpaceGeometry(
        semanticKey: 'livingRoom:1',
        participation: SpaceAreaParticipation.requestedInteriorArea,
        polygon: RectilinearPolygonMm.rectangle(
          xMm: 2000,
          yMm: 0,
          widthMm: 2000,
          heightMm: 2000,
        ),
        fittedAreaDm2: 400,
      ),
    ],
    exteriorAppendages: const [],
    sharedBoundaries: [
      GeneratedSharedBoundary(
        leftSpaceKey: 'entranceHall:1',
        rightSpaceKey: 'livingRoom:1',
        segment: shared,
      ),
    ],
    exteriorBoundaries: [
      GeneratedExteriorBoundary(
        spaceSemanticKey: 'entranceHall:1',
        side: GeometryEnvelopeSide.west,
        segment: entranceWest,
      ),
      GeneratedExteriorBoundary(
        spaceSemanticKey: 'livingRoom:1',
        side: GeometryEnvelopeSide.east,
        segment: livingEast,
      ),
    ],
    openingIntents: [
      OpeningIntent(
        kind: GeometryOpeningKind.primaryEntry,
        fromSpaceKey: entrySpaceKey,
        hostSegment: entryHost ?? entranceWest,
      ),
      OpeningIntent(
        kind: GeometryOpeningKind.door,
        fromSpaceKey: 'entranceHall:1',
        toSpaceKey: 'livingRoom:1',
        hostSegment: openingHost,
      ),
    ],
    metrics: const GeometryMetrics(
      interiorAreaMm2: 8000000,
      appendageAreaMm2: 0,
      maxAreaErrorMm2: 0,
      sharedBoundaryLengthMm: 2000,
      exteriorExposureLengthMm: 4000,
      wetCoreMaxSeparationMm: 0,
    ),
    validation: GeometryValidationReport(const []),
    geometryAlgorithmVersion: 'fixture-v1',
    geometryFingerprint: 'geometry-fixture',
  );
}

TopologyGeometryHandoff _handoff({
  int minSharedBoundaryMm = 1200,
  DraftExteriorSide livingSide = DraftExteriorSide.east,
}) =>
    TopologyGeometryHandoff(
      requiredSharedBoundaries: [
        RequiredSharedBoundaryIntent(
          fromSpaceKey: 'entranceHall:1',
          toSpaceKey: 'livingRoom:1',
          kind: TopologyAdjacencyKind.directBoundary,
          minSharedBoundaryMm: minSharedBoundaryMm,
        ),
      ],
      requiredExteriorAssignments: {
        'entranceHall:1': DraftExteriorSide.west,
        'livingRoom:1': livingSide,
      },
      accessIntents: [
        SemanticAccessIntent(
          fromSpaceKey: 'entranceHall:1',
          toSpaceKey: 'livingRoom:1',
          kind: DraftAccessKind.door,
        ),
      ],
      entrySpaceKey: 'entranceHall:1',
    );

GeometrySegmentMm _segment(int x1, int y1, int x2, int y2) =>
    GeometrySegmentMm(
      start: BoundaryPointMm(xMm: x1, yMm: y1),
      end: BoundaryPointMm(xMm: x2, yMm: y2),
    );
