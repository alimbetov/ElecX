import 'dart:convert';

import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/level_apartment_composition.dart';
import '../../../../domain/project_identity.dart';
import '../../../../domain/semantic_sha256.dart';
import '../apartment/apartment_candidate_set_service.dart';
import '../apartment/apartment_wizard_parameters.dart';

/// Frozen exact P9 selection and its explicit placement/access contract.
final class ApartmentPlacementSlot {
  ApartmentPlacementSlot._(
      {required this.key,
      required this.displayName,
      required this.source,
      required this.transform,
      required this.accessSpaceId});

  factory ApartmentPlacementSlot.fromCandidateSet(
      {required String key,
      required String displayName,
      required ApartmentCandidateSet candidateSet,
      required ApartmentCandidateSelection selection,
      required ApartmentPlacementTransform transform,
      required SpaceId accessSpaceId}) {
    final source = candidateSet.resolveSelection(selection);
    final normalized = key.trim();
    if (!RegExp(r'^[a-z][a-z0-9._-]{0,95}$').hasMatch(normalized) ||
        displayName.trim().isEmpty ||
        selection.candidateSetFingerprint !=
            candidateSet.candidateSetFingerprint ||
        source == null) {
      throw const ApartmentCompositionException(
          'p10.apartments.invalid-selection');
    }
    final geometry = source.rankedCandidate.candidate;
    if (!geometry.validation.accepted ||
        geometry.geometryFingerprint != source.identity.geometryFingerprint ||
        geometry.templateId != source.template.templateId ||
        geometry.templateVersion != source.identity.templateVersion ||
        geometry.geometryAlgorithmVersion !=
            source.identity.geometryAlgorithmVersion) {
      throw const ApartmentCompositionException(
          'p10.apartments.invalid-p9-candidate');
    }
    return ApartmentPlacementSlot._(
        key: normalized,
        displayName: displayName.trim(),
        source: source,
        transform: transform,
        accessSpaceId: accessSpaceId);
  }

  final String key;
  final String displayName;
  final ApartmentCandidateCard source;
  final ApartmentPlacementTransform transform;
  final SpaceId accessSpaceId;

  Map<String, Object?> toCanonicalJson() => {
        'key': key,
        'displayName': displayName,
        'candidateFingerprint': source.candidateFingerprint,
        'transform': transform.toCanonicalJson(),
        'accessSpaceId': accessSpaceId.value
      };
}

/// A P10 rigid placement of accepted P9 output. P9 child identity is preserved
/// separately; the placed geometry/fingerprint explicitly identify P10 output.
final class PlacedApartmentCandidate {
  PlacedApartmentCandidate(ApartmentPlacementSlot slot)
      : slot = slot,
        placementFingerprint = semanticSha256Hex(jsonEncode({
          'schema': 'p10.apartment-placement.v1',
          ...slot.toCanonicalJson()
        })),
        geometry = _place(slot);

  final ApartmentPlacementSlot slot;
  final String placementFingerprint;
  final ApartmentGeometryCandidate geometry;

  static ApartmentGeometryCandidate _place(ApartmentPlacementSlot slot) {
    final source = slot.source.rankedCandidate.candidate;
    final transform = slot.transform;
    RectilinearPolygonMm polygon(RectilinearPolygonMm value) =>
        RectilinearPolygonMm.normalized(value.vertices.map(transform.apply));
    GeometrySegmentMm segment(GeometrySegmentMm value) => GeometrySegmentMm(
        start: transform.apply(value.start), end: transform.apply(value.end));
    GeneratedSpaceGeometry space(GeneratedSpaceGeometry value) =>
        GeneratedSpaceGeometry(
            semanticKey: value.semanticKey,
            participation: value.participation,
            polygon: polygon(value.polygon),
            fittedAreaDm2: value.fittedAreaDm2);
    return ApartmentGeometryCandidate(
      templateId: source.templateId,
      templateVersion: source.templateVersion,
      family: source.family,
      variantSeedId: source.variantSeedId,
      areaFitFingerprint: source.areaFitFingerprint,
      interiorEnvelope: polygon(source.interiorEnvelope),
      interiorSpaces: source.interiorSpaces.map(space),
      exteriorAppendages: source.exteriorAppendages.map(space),
      sharedBoundaries: source.sharedBoundaries.map((value) =>
          GeneratedSharedBoundary(
              leftSpaceKey: value.pair.leftKey,
              rightSpaceKey: value.pair.rightKey,
              segment: segment(value.segment))),
      exteriorBoundaries: source.exteriorBoundaries.map((value) =>
          GeneratedExteriorBoundary(
              spaceSemanticKey: value.spaceSemanticKey,
              side: GeometryEnvelopeSide.values[
                  (value.side.index + transform.clockwiseQuarterTurns) % 4],
              segment: segment(value.segment))),
      openingIntents: source.openingIntents.map((value) => OpeningIntent(
          kind: value.kind,
          fromSpaceKey: value.fromSpaceKey,
          toSpaceKey: value.toSpaceKey,
          hostSegment: segment(value.hostSegment))),
      metrics: source.metrics,
      validation: source.validation,
      geometryAlgorithmVersion:
          '${source.geometryAlgorithmVersion}|p10.rigid-placement.v1',
      geometryFingerprint: semanticSha256Hex(jsonEncode({
        'schema': 'p10.placed-geometry.v1',
        'source': source.geometryFingerprint,
        'transform': transform.toCanonicalJson()
      })),
    );
  }
}
