import 'package:elecx/src/application/project/wizard/apartment/apartment_geometry_structural_validator.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_area_fit.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_geometry.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_draft.dart';
import 'package:elecx/src/domain/apartment_topology/apartment_topology_models.dart';
import 'package:elecx/src/domain/boundary_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/domain/project_space_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = ApartmentGeometryStructuralValidator();

  group('P9.6 independent structural validation', () {
    test('accepted non-overlapping rectangles pass', () {
      final fitted = _fittedDraft();
      final report = validator.validate(
        candidate: _candidate(
          first: RectilinearPolygonMm.rectangle(
            xMm: 0,
            yMm: 0,
            widthMm: 2000,
            heightMm: 2000,
          ),
          second: RectilinearPolygonMm.rectangle(
            xMm: 2000,
            yMm: 0,
            widthMm: 2000,
            heightMm: 2000,
          ),
        ),
        fittedDraft: fitted,
      );

      expect(report.accepted, isTrue);
      expect(report.issues, isEmpty);
    });

    test('space exceeding source maxVertices is rejected', () {
      final fitted = _fittedDraft(maxVertices: 4);
      final lShape = RectilinearPolygonMm.normalized(const [
        BoundaryPointMm(xMm: 0, yMm: 0),
        BoundaryPointMm(xMm: 3000, yMm: 0),
        BoundaryPointMm(xMm: 3000, yMm: 1000),
        BoundaryPointMm(xMm: 2000, yMm: 1000),
        BoundaryPointMm(xMm: 2000, yMm: 2000),
        BoundaryPointMm(xMm: 0, yMm: 2000),
      ]);
      final report = validator.validate(
        candidate: _candidate(
          first: lShape,
          second: RectilinearPolygonMm.rectangle(
            xMm: 3000,
            yMm: 0,
            widthMm: 2000,
            heightMm: 2000,
          ),
        ),
        fittedDraft: fitted,
      );

      expect(report.accepted, isFalse);
      expect(
        report.issues.map((issue) => issue.code),
        contains('p9.geometry.vertex-limit'),
      );
    });

    test('positive-area interior overlap is rejected', () {
      final fitted = _fittedDraft();
      final report = validator.validate(
        candidate: _candidate(
          first: RectilinearPolygonMm.rectangle(
            xMm: 0,
            yMm: 0,
            widthMm: 2500,
            heightMm: 2000,
          ),
          second: RectilinearPolygonMm.rectangle(
            xMm: 2000,
            yMm: 0,
            widthMm: 2000,
            heightMm: 2000,
          ),
        ),
        fittedDraft: fitted,
      );

      expect(report.accepted, isFalse);
      expect(
        report.issues.map((issue) => issue.code),
        contains('p9.geometry.space-overlap'),
      );
    });
  });
}

AreaFittedTopologyDraft _fittedDraft({int maxVertices = 8}) {
  final spaces = [
    _draftSpace('room:1', maxVertices: maxVertices),
    _draftSpace('room:2', maxVertices: maxVertices),
  ];
  final draft = ApartmentTopologyDraft(
    templateId: TemplateId('structural-validator-fixture'),
    templateVersion: 1,
    family: ApartmentTopologyFamily.compact,
    variantSeedId: 'fixture',
    intentFingerprint: 'intent-fixture',
    spaces: spaces,
    adjacency: const [],
    circulation: DraftCirculationGraph(
      entrySpaceKey: 'room:1',
      accessEdges: const [],
    ),
    exteriorExposure: DraftExteriorExposure(const {}),
    wetCore: DraftWetCoreGrouping(const []),
    layoutSkeleton: DraftLayoutSkeleton(
      primaryAxis: DraftLayoutAxis.horizontal,
      mirrored: false,
      entrySide: TopologyEntrySide.west,
      stableRoleOrder: const ['room:1', 'room:2'],
      dayZoneKeys: const ['room:1'],
      nightZoneKeys: const ['room:2'],
    ),
    semanticSignature: 'semantic-fixture',
    draftFingerprint: 'draft-fixture',
  );

  return AreaFittedTopologyDraft(
    draft: draft,
    requestedInteriorAreaDm2: 800,
    spaces: const [
      FittedSpaceArea(
        semanticKey: 'room:1',
        participation: SpaceAreaParticipation.requestedInteriorArea,
        areaDm2: 400,
        minAreaDm2: 300,
        preferredAreaDm2: 400,
        maxAreaDm2: 600,
      ),
      FittedSpaceArea(
        semanticKey: 'room:2',
        participation: SpaceAreaParticipation.requestedInteriorArea,
        areaDm2: 400,
        minAreaDm2: 300,
        preferredAreaDm2: 400,
        maxAreaDm2: 600,
      ),
    ],
    allocatedInteriorAreaDm2: 800,
    exteriorAppendageAreaDm2: 0,
    interiorResidualDm2: 0,
    areaPolicyVersion: 'fixture',
    allocatorVersion: 'fixture',
    areaFitFingerprint: 'area-fit-fixture',
  );
}

DraftSpace _draftSpace(String key, {required int maxVertices}) => DraftSpace(
      semanticKey: key,
      baseSemanticKey: 'room',
      ordinal: int.parse(key.split(':').last),
      usage: SpaceUsage.livingRoom,
      type: ProjectSpaceType.room,
      areaParticipation: SpaceAreaParticipation.requestedInteriorArea,
      sourceSpec: TopologySpaceSpec(
        semanticKey: 'room',
        usage: SpaceUsage.livingRoom,
        type: ProjectSpaceType.room,
        multiplicityMin: 1,
        multiplicityMax: 2,
        areaParticipation: SpaceAreaParticipation.requestedInteriorArea,
        minAreaDm2: 300,
        preferredAreaDm2: 400,
        maxAreaDm2: 600,
        areaWeightBp: 1000,
        nearFixedArea: false,
        requiresExteriorExposure: false,
        wetSpace: false,
        circulationSpace: false,
        geometry: TopologySpaceGeometryConstraints(
          minShortSideMm: 1000,
          minAspectBp: 2000,
          maxAspectBp: 50000,
          maxVertices: maxVertices,
        ),
      ),
    );

ApartmentGeometryCandidate _candidate({
  required RectilinearPolygonMm first,
  required RectilinearPolygonMm second,
}) =>
    ApartmentGeometryCandidate(
      templateId: TemplateId('structural-validator-fixture'),
      templateVersion: 1,
      family: ApartmentTopologyFamily.compact,
      variantSeedId: 'fixture',
      areaFitFingerprint: 'area-fit-fixture',
      interiorEnvelope: RectilinearPolygonMm.rectangle(
        xMm: 0,
        yMm: 0,
        widthMm: 5000,
        heightMm: 3000,
      ),
      interiorSpaces: [
        GeneratedSpaceGeometry(
          semanticKey: 'room:1',
          participation: SpaceAreaParticipation.requestedInteriorArea,
          polygon: first,
          fittedAreaDm2: 400,
        ),
        GeneratedSpaceGeometry(
          semanticKey: 'room:2',
          participation: SpaceAreaParticipation.requestedInteriorArea,
          polygon: second,
          fittedAreaDm2: 400,
        ),
      ],
      exteriorAppendages: const [],
      sharedBoundaries: const [],
      exteriorBoundaries: const [],
      openingIntents: const [],
      metrics: const GeometryMetrics(
        interiorAreaMm2: 8000000,
        appendageAreaMm2: 0,
        maxAreaErrorMm2: 0,
        sharedBoundaryLengthMm: 0,
        exteriorExposureLengthMm: 0,
        wetCoreMaxSeparationMm: 0,
      ),
      validation: GeometryValidationReport(const []),
      geometryAlgorithmVersion: 'fixture',
      geometryFingerprint: 'geometry-fixture',
    );
