import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_semantic_validation.dart';
import '../../../../domain/apartment_topology/apartment_topology_draft.dart';

/// Post-packing P9.6 validation for the semantic-access contract.
///
/// The semantic graph is authoritative. Geometry may not silently drop an
/// access edge merely because the selected polygons failed to share a wall.
final class ApartmentGeometryAccessValidator {
  const ApartmentGeometryAccessValidator();

  GeometryValidationReport validate({
    required ApartmentGeometryCandidate candidate,
    required TopologyGeometryHandoff handoff,
  }) {
    final issues = <GeometryValidationIssue>[];
    final sharedByPair = <String, GeneratedSharedBoundary>{
      for (final boundary in candidate.sharedBoundaries)
        boundary.pair.stableKey: boundary,
    };
    final internalOpenings = candidate.openingIntents
        .where((opening) => opening.kind != GeometryOpeningKind.primaryEntry)
        .toList();
    final openingsByPair = <String, List<OpeningIntent>>{};
    for (final opening in internalOpenings) {
      final from = opening.fromSpaceKey;
      final to = opening.toSpaceKey;
      if (from == null || to == null) {
        issues.add(
          GeometryValidationIssue(
            code: 'p9.geometry.invalid-opening-endpoints',
            severity: GeometryValidationSeverity.blocker,
          ),
        );
        continue;
      }
      final pair = SemanticSpacePair(from, to);
      openingsByPair.putIfAbsent(pair.stableKey, () => []).add(opening);
      final shared = sharedByPair[pair.stableKey];
      if (shared == null ||
          shared.segment.stableKey != opening.hostSegment.stableKey) {
        issues.add(
          GeometryValidationIssue(
            code: 'p9.geometry.opening-host-mismatch',
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [pair.leftKey, pair.rightKey],
          ),
        );
      }
    }

    for (final intent in handoff.accessIntents) {
      final expectedKind = intent.kind == DraftAccessKind.openPassage
          ? GeometryOpeningKind.openPassage
          : GeometryOpeningKind.door;
      final realized = openingsByPair[intent.pair.stableKey] ?? const [];
      if (realized.any((opening) => opening.kind == expectedKind)) {
        continue;
      }
      issues.add(
        GeometryValidationIssue(
          code: 'p9.geometry.required-access-opening-missing',
          severity: GeometryValidationSeverity.blocker,
          affectedKeys: [intent.pair.leftKey, intent.pair.rightKey],
          facts: {'expectedKind': expectedKind.name},
        ),
      );
    }

    final primaryEntries = candidate.openingIntents
        .where((opening) => opening.kind == GeometryOpeningKind.primaryEntry)
        .toList();
    if (primaryEntries.length != 1 ||
        primaryEntries.singleOrNull?.fromSpaceKey == null) {
      issues.add(
        GeometryValidationIssue(
          code: 'p9.geometry.invalid-entry',
          severity: GeometryValidationSeverity.blocker,
          facts: {'entryCount': primaryEntries.length},
        ),
      );
      return GeometryValidationReport(issues);
    }

    final entryKey = primaryEntries.single.fromSpaceKey!;
    final reachable = _reachableFrom(entryKey, internalOpenings);
    for (final space in candidate.interiorSpaces) {
      if (reachable.contains(space.semanticKey)) {
        continue;
      }
      issues.add(
        GeometryValidationIssue(
          code: 'p9.geometry.unreachable-space',
          severity: GeometryValidationSeverity.blocker,
          affectedKeys: [space.semanticKey],
          facts: {'entrySpaceKey': entryKey},
        ),
      );
    }

    return GeometryValidationReport(issues);
  }

  Set<String> _reachableFrom(
    String entryKey,
    List<OpeningIntent> openings,
  ) {
    final neighbors = <String, Set<String>>{};
    for (final opening in openings) {
      final from = opening.fromSpaceKey;
      final to = opening.toSpaceKey;
      if (from == null || to == null) {
        continue;
      }
      neighbors.putIfAbsent(from, () => <String>{}).add(to);
      neighbors.putIfAbsent(to, () => <String>{}).add(from);
    }
    final visited = <String>{entryKey};
    final queue = <String>[entryKey];
    var index = 0;
    while (index < queue.length) {
      final current = queue[index++];
      final next = (neighbors[current] ?? const <String>{}).toList()..sort();
      for (final key in next) {
        if (visited.add(key)) {
          queue.add(key);
        }
      }
    }
    return visited;
  }
}

extension<T> on List<T> {
  T? get singleOrNull => length == 1 ? single : null;
}
