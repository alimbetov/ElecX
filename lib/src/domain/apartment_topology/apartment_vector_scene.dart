import '../apartment_topology.dart';

const int p9ApartmentCardViewBoxWidth = 320;
const int p9ApartmentCardViewBoxHeight = 220;

enum ApartmentVectorRole {
  interiorEnvelope,
  interiorSpaceRegion,
  exteriorAppendageRegion,
  internalPartition,
  entryMarker,
  accessMarker,
  spaceLabelAnchor,
  wetCoreMetadata,
  warningMetadata,
}

extension ApartmentVectorRoleCode on ApartmentVectorRole {
  String get code => switch (this) {
        ApartmentVectorRole.interiorEnvelope => 'interiorEnvelope',
        ApartmentVectorRole.interiorSpaceRegion => 'interiorSpaceRegion',
        ApartmentVectorRole.exteriorAppendageRegion =>
          'exteriorAppendageRegion',
        ApartmentVectorRole.internalPartition => 'internalPartition',
        ApartmentVectorRole.entryMarker => 'entryMarker',
        ApartmentVectorRole.accessMarker => 'accessMarker',
        ApartmentVectorRole.spaceLabelAnchor => 'spaceLabelAnchor',
        ApartmentVectorRole.wetCoreMetadata => 'wetCoreMetadata',
        ApartmentVectorRole.warningMetadata => 'warningMetadata',
      };
}

final class ApartmentVectorPoint {
  const ApartmentVectorPoint({required this.xUnits, required this.yUnits});

  final int xUnits;
  final int yUnits;

  String get stableSerialization => '$xUnits,$yUnits';
}

sealed class ApartmentVectorElement {
  const ApartmentVectorElement({
    required this.role,
    required this.generationKey,
  });

  final ApartmentVectorRole role;
  final String generationKey;

  String get stableSerialization;
}

final class ApartmentVectorPolygonElement extends ApartmentVectorElement {
  ApartmentVectorPolygonElement({
    required super.role,
    required super.generationKey,
    required Iterable<ApartmentVectorPoint> points,
  }) : points = List.unmodifiable(points);

  final List<ApartmentVectorPoint> points;

  @override
  String get stableSerialization => <String>[
        role.code,
        generationKey,
        points.map((point) => point.stableSerialization).join(';'),
      ].join('|');
}

final class ApartmentVectorLineElement extends ApartmentVectorElement {
  const ApartmentVectorLineElement({
    required super.role,
    required super.generationKey,
    required this.start,
    required this.end,
  });

  final ApartmentVectorPoint start;
  final ApartmentVectorPoint end;

  @override
  String get stableSerialization => <String>[
        role.code,
        generationKey,
        start.stableSerialization,
        end.stableSerialization,
      ].join('|');
}

final class ApartmentVectorMarkerElement extends ApartmentVectorElement {
  const ApartmentVectorMarkerElement({
    required super.role,
    required super.generationKey,
    required this.anchor,
    required this.markerKind,
  });

  final ApartmentVectorPoint anchor;
  final String markerKind;

  @override
  String get stableSerialization => <String>[
        role.code,
        generationKey,
        markerKind,
        anchor.stableSerialization,
      ].join('|');
}

final class ApartmentVectorLabelAnchorElement extends ApartmentVectorElement {
  const ApartmentVectorLabelAnchorElement({
    required super.generationKey,
    required this.anchor,
    required this.semanticLabelKey,
  }) : super(role: ApartmentVectorRole.spaceLabelAnchor);

  final ApartmentVectorPoint anchor;
  final String semanticLabelKey;

  @override
  String get stableSerialization => <String>[
        role.code,
        generationKey,
        semanticLabelKey,
        anchor.stableSerialization,
      ].join('|');
}

final class ApartmentVectorMetadataElement extends ApartmentVectorElement {
  const ApartmentVectorMetadataElement({
    required super.role,
    required super.generationKey,
    required this.value,
  });

  final String value;

  @override
  String get stableSerialization =>
      <String>[role.code, generationKey, value].join('|');
}

final class ApartmentPreviewSummary {
  const ApartmentPreviewSummary({
    required this.habitableRoomCount,
    required this.interiorAreaDm2,
    required this.exteriorAppendageAreaDm2,
    required this.kitchenMode,
    required this.family,
    required this.bathroomCount,
    required this.balconyCount,
    required this.scoreBp,
  });

  final int habitableRoomCount;
  final int interiorAreaDm2;
  final int exteriorAppendageAreaDm2;
  final ApartmentKitchenMode kitchenMode;
  final ApartmentTopologyFamily family;
  final int bathroomCount;
  final int balconyCount;
  final int scoreBp;

  String get stableSerialization => <String>[
        'habitableRoomCount=$habitableRoomCount',
        'interiorAreaDm2=$interiorAreaDm2',
        'exteriorAppendageAreaDm2=$exteriorAppendageAreaDm2',
        'kitchenMode=${kitchenMode.code}',
        'family=${family.code}',
        'bathroomCount=$bathroomCount',
        'balconyCount=$balconyCount',
        'scoreBp=$scoreBp',
      ].join('|');
}

final class ApartmentTopologyVectorScene {
  ApartmentTopologyVectorScene({
    required this.widthUnits,
    required this.heightUnits,
    required this.semanticLabelKey,
    required Iterable<ApartmentVectorElement> elements,
    required this.summary,
    required this.rendererVersion,
    required this.sourceGeometryFingerprint,
    required this.sceneFingerprint,
  }) : elements = List.unmodifiable(elements);

  final int widthUnits;
  final int heightUnits;
  final String semanticLabelKey;
  final List<ApartmentVectorElement> elements;
  final ApartmentPreviewSummary summary;
  final String rendererVersion;
  final String sourceGeometryFingerprint;
  final String sceneFingerprint;

  Iterable<ApartmentVectorElement> elementsByRole(ApartmentVectorRole role) =>
      elements.where((element) => element.role == role);
}
