import '../../../../domain/apartment_topology.dart';
import '../../../../domain/apartment_topology/apartment_area_fit.dart';
import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_semantic_validation.dart';
import '../../../../domain/apartment_topology/apartment_topology_draft.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import '../../../../domain/boundary_topology.dart';
import '../../../../domain/project_space_semantics.dart';
import 'apartment_geometry_generator.dart';
import 'apartment_wizard_parameters.dart';
import 'p9_failure.dart';
import 'p9_sha256.dart';

/// Access topology accepted by the bounded access-spine packing engine.
enum ApartmentAccessTopologyPolicy {
  /// Historical V1 contract: every interior non-hub space must have a direct
  /// semantic access edge to the distribution hub.
  directHub,

  /// V2 contract: every interior space must be reachable from the distribution
  /// hub through the semantic access graph. Packing may still place a reachable
  /// descendant against the physical spine, but it must not invent an opening.
  graphReachable,
}

/// Access-preserving P9.6 layout.
///
/// The circulation hub is a vertical spine. Interior spaces are packed against
/// one of its sides while the selected [ApartmentAccessTopologyPolicy] controls
/// which semantic access graphs are eligible. Spoke rooms may have independent
/// depths, so the apartment outline is a deterministic stepped polygon instead
/// of forcing unrelated rooms into one rectangular strip.
final class ApartmentAccessSpineGeometryGenerator {
  const ApartmentAccessSpineGeometryGenerator({
    this.accessTopologyPolicy = ApartmentAccessTopologyPolicy.directHub,
  });

  static const String accessSpineV1AlgorithmVersion = 'p9.access-spine.v1';
  static const String graphAwareV2AlgorithmVersion = 'p9.graph-aware.v2';
  static const int maxSpineLengthMm = 24000;
  static const int maxRoomSpanMm = 9000;
  static const int minimumAreaToleranceMm2 = 200000;

  final ApartmentAccessTopologyPolicy accessTopologyPolicy;

  String get geometryAlgorithmVersion =>
      accessTopologyPolicy == ApartmentAccessTopologyPolicy.graphReachable
          ? graphAwareV2AlgorithmVersion
          : accessSpineV1AlgorithmVersion;

  ApartmentGeometryGenerationResult generate({
    required AreaFittedTopologyDraft fittedDraft,
    required TopologySemanticValidation semanticValidation,
    required ApartmentTopologyTemplate template,
    required NormalizedApartmentRequest request,
  }) {
    final failures = <P9Failure>[];
    final draft = fittedDraft.draft;
    if (!semanticValidation.accepted) {
      return _rejected('p9.geometry.semantic-input-invalid');
    }
    if (draft.templateId != template.templateId ||
        draft.templateVersion != template.templateVersion ||
        draft.intentFingerprint != request.intentFingerprint) {
      return _rejected('p9.geometry.lineage-mismatch');
    }
    if (request.exteriorExposurePreference ==
        ApartmentExteriorExposurePreference.corner) {
      return _rejected(
        'p9.geometry.exposure-preference-mismatch',
        facts: {'preference': request.exteriorExposurePreference.code},
      );
    }

    final byArea = <String, FittedSpaceArea>{
      for (final area in fittedDraft.spaces) area.semanticKey: area,
    };
    final interiorDraft = draft.spaces
        .where(
          (space) =>
              space.areaParticipation ==
              SpaceAreaParticipation.requestedInteriorArea,
        )
        .toList()
      ..sort(_compareDraftSpace);
    final appendageDraft = draft.spaces
        .where(
          (space) =>
              space.areaParticipation ==
              SpaceAreaParticipation.exteriorAppendage,
        )
        .toList()
      ..sort(_compareDraftSpace);
    if (interiorDraft.any((space) => !byArea.containsKey(space.semanticKey))) {
      return _rejected('p9.geometry.missing-fitted-area');
    }

    final distribution = _distributionSpace(interiorDraft);
    if (distribution == null) {
      return _rejected('p9.geometry.missing-circulation-hub');
    }
    final spokes = interiorDraft
        .where((space) => space.semanticKey != distribution.semanticKey)
        .toList();
    final spokeKeys = spokes.map((space) => space.semanticKey).toSet();
    final accessIntents = semanticValidation.geometryHandoff.accessIntents;
    final reachableAccessKeys = _reachableAccessKeys(
      startKey: distribution.semanticKey,
      accessIntents: accessIntents,
      allowedKeys: interiorDraft.map((space) => space.semanticKey).toSet(),
    );
    final distributionNeighbors = <String>{};
    for (final access in accessIntents) {
      if (access.pair.leftKey == distribution.semanticKey) {
        distributionNeighbors.add(access.pair.rightKey);
      } else if (access.pair.rightKey == distribution.semanticKey) {
        distributionNeighbors.add(access.pair.leftKey);
      }
    }
    final supportedAccessKeys =
        accessTopologyPolicy == ApartmentAccessTopologyPolicy.graphReachable
            ? reachableAccessKeys
            : distributionNeighbors;
    final missingAccessKeys = spokeKeys.difference(supportedAccessKeys);
    if (missingAccessKeys.isNotEmpty) {
      return _rejected(
        'p9.geometry.unsupported-access-shape',
        facts: {
          'accessTopologyPolicy': accessTopologyPolicy.name,
          'missingAccessKeys': (missingAccessKeys.toList()..sort()).join(','),
        },
      );
    }

    final units = _buildUnits(
      spokes: spokes,
      fittedByKey: byArea,
      handoff: semanticValidation.geometryHandoff,
    );
    final sidePlan = _assignSides(
      units,
      request.exteriorExposurePreference,
      semanticValidation.geometryHandoff.requiredExteriorSpaceKeys.toSet(),
    );

    final left = _layoutSide(sidePlan.left, byArea);
    final right = _layoutSide(sidePlan.right, byArea);
    if (left == null || right == null) {
      return _rejected('p9.geometry.unsatisfiable-area');
    }
    final requiredLengthMm = _max(
      _max(left.totalSpanMm, right.totalSpanMm),
      distribution.sourceSpec.geometry.minLongSideMm ?? 0,
    );
    final distributionArea = byArea[distribution.semanticKey]!;
    final spine = _distributionDimensions(
      distribution,
      distributionArea,
      requiredLengthMm,
    );
    if (spine == null) {
      return _rejected(
        'p9.geometry.circulation-spine-area',
        facts: {
          'distributionKey': distribution.semanticKey,
          'requiredLengthMm': requiredLengthMm,
          'fittedAreaDm2': distributionArea.areaDm2,
        },
      );
    }

    final leftMaxDepth = left.items.isEmpty
        ? 0
        : left.items.map((item) => item.depthMm).reduce(_max);
    final spineX = leftMaxDepth;
    final interiorSpaces = <GeneratedSpaceGeometry>[
      GeneratedSpaceGeometry(
        semanticKey: distribution.semanticKey,
        participation: distribution.areaParticipation,
        polygon: RectilinearPolygonMm.rectangle(
          xMm: spineX,
          yMm: 0,
          widthMm: spine.widthMm,
          heightMm: spine.lengthMm,
        ),
        fittedAreaDm2: distributionArea.areaDm2,
      ),
      ..._materializeSide(
        side: left,
        leftSide: true,
        spineX: spineX,
        spineWidthMm: spine.widthMm,
      ),
      ..._materializeSide(
        side: right,
        leftSide: false,
        spineX: spineX,
        spineWidthMm: spine.widthMm,
      ),
    ];
    interiorSpaces.sort((a, b) => a.semanticKey.compareTo(b.semanticKey));

    final envelope = _unionEnvelope(
      interiorSpaces.map((space) => space.polygon).toList(),
    );
    if (envelope == null) {
      return _rejected('p9.geometry.invalid-interior-envelope');
    }

    final appendages = _materializeAppendages(
      appendageDraft: appendageDraft,
      fittedByKey: byArea,
      interiorSpaces: interiorSpaces,
      envelope: envelope,
      handoff: semanticValidation.geometryHandoff,
      failures: failures,
    );
    if (failures.any((failure) => failure.isBlocker)) {
      return ApartmentGeometryGenerationResult(
        candidate: null,
        failures: failures,
      );
    }

    final allSpaces = [...interiorSpaces, ...appendages];
    final shared = _sharedBoundaries(allSpaces);
    final exterior = _exteriorBoundaries(interiorSpaces, envelope, spineX);
    final openings = _openingIntents(
      draft: draft,
      handoff: semanticValidation.geometryHandoff,
      shared: shared,
      exterior: exterior,
    );
    final validation = GeometryValidationReport(
      _validate(
        fittedDraft: fittedDraft,
        template: template,
        handoff: semanticValidation.geometryHandoff,
        envelope: envelope,
        interiorSpaces: interiorSpaces,
        appendages: appendages,
        shared: shared,
        exterior: exterior,
      ),
    );
    final metrics = _metrics(
      handoff: semanticValidation.geometryHandoff,
      interiorSpaces: interiorSpaces,
      appendages: appendages,
      shared: shared,
      exterior: exterior,
    );
    final fingerprint = _fingerprint(
      fittedDraft: fittedDraft,
      envelope: envelope,
      interiorSpaces: interiorSpaces,
      appendages: appendages,
      shared: shared,
      exterior: exterior,
      openings: openings,
    );

    final candidate = ApartmentGeometryCandidate(
      templateId: draft.templateId,
      templateVersion: draft.templateVersion,
      family: draft.family,
      variantSeedId: draft.variantSeedId,
      areaFitFingerprint: fittedDraft.areaFitFingerprint,
      interiorEnvelope: envelope,
      interiorSpaces: interiorSpaces,
      exteriorAppendages: appendages,
      sharedBoundaries: shared,
      exteriorBoundaries: exterior,
      openingIntents: openings,
      metrics: metrics,
      validation: validation,
      geometryAlgorithmVersion: geometryAlgorithmVersion,
      geometryFingerprint: fingerprint,
    );
    return ApartmentGeometryGenerationResult(
      candidate: candidate,
      failures: validation.accepted
          ? failures
          : [
              ...failures,
              _failure('p9.geometry.candidate-rejected'),
            ],
    );
  }

  DraftSpace? _distributionSpace(List<DraftSpace> spaces) {
    for (final space in spaces) {
      if (space.usage == SpaceUsage.corridor) {
        return space;
      }
    }
    for (final space in spaces) {
      if (space.usage == SpaceUsage.entranceHall) {
        return space;
      }
    }
    return null;
  }

  Set<String> _reachableAccessKeys({
    required String startKey,
    required List<SemanticAccessIntent> accessIntents,
    required Set<String> allowedKeys,
  }) {
    final neighbors = <String, Set<String>>{};
    for (final access in accessIntents) {
      final left = access.pair.leftKey;
      final right = access.pair.rightKey;
      if (!allowedKeys.contains(left) || !allowedKeys.contains(right)) {
        continue;
      }
      neighbors.putIfAbsent(left, () => <String>{}).add(right);
      neighbors.putIfAbsent(right, () => <String>{}).add(left);
    }
    final visited = <String>{startKey};
    final queue = <String>[startKey];
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

  List<_LayoutUnit> _buildUnits({
    required List<DraftSpace> spokes,
    required Map<String, FittedSpaceArea> fittedByKey,
    required TopologyGeometryHandoff handoff,
  }) {
    final parent = <String, String>{
      for (final space in spokes) space.semanticKey: space.semanticKey,
    };
    String find(String key) {
      var current = key;
      while (parent[current] != current) {
        current = parent[current]!;
      }
      var compress = key;
      while (parent[compress] != compress) {
        final next = parent[compress]!;
        parent[compress] = current;
        compress = next;
      }
      return current;
    }

    void union(String first, String second) {
      if (!parent.containsKey(first) || !parent.containsKey(second)) {
        return;
      }
      final a = find(first);
      final b = find(second);
      if (a == b) {
        return;
      }
      if (a.compareTo(b) <= 0) {
        parent[b] = a;
      } else {
        parent[a] = b;
      }
    }

    for (final pair in handoff.requiredSharedBoundaryPairs) {
      union(pair.leftKey, pair.rightKey);
    }
    for (final group in handoff.wetCoreGroups) {
      final members = group.where(parent.containsKey).toList()..sort();
      for (var index = 1; index < members.length; index++) {
        union(members.first, members[index]);
      }
    }

    final groups = <String, List<DraftSpace>>{};
    for (final space in spokes) {
      groups.putIfAbsent(find(space.semanticKey), () => []).add(space);
    }
    final units = <_LayoutUnit>[];
    for (final members in groups.values) {
      members.sort(_compareDraftSpace);
      units.add(
        _LayoutUnit(
          members: members,
          areaDm2: members.fold(
            0,
            (sum, space) => sum + fittedByKey[space.semanticKey]!.areaDm2,
          ),
        ),
      );
    }
    units.sort((a, b) => a.stableKey.compareTo(b.stableKey));
    return units;
  }

  _SidePlan _assignSides(
    List<_LayoutUnit> units,
    ApartmentExteriorExposurePreference preference,
    Set<String> requiredExterior,
  ) {
    final left = <_LayoutUnit>[];
    final right = <_LayoutUnit>[];
    var leftArea = 0;
    var rightArea = 0;
    final exteriorUnits = units
        .where(
          (unit) => unit.members
              .any((space) => requiredExterior.contains(space.semanticKey)),
        )
        .toSet();

    if (preference == ApartmentExteriorExposurePreference.oneSide) {
      for (final unit in units) {
        if (exteriorUnits.contains(unit)) {
          left.add(unit);
          leftArea += unit.areaDm2;
        }
      }
      for (final unit in units) {
        if (exteriorUnits.contains(unit)) {
          continue;
        }
        if (rightArea <= leftArea) {
          right.add(unit);
          rightArea += unit.areaDm2;
        } else {
          left.add(unit);
          leftArea += unit.areaDm2;
        }
      }
      return _SidePlan(left: left, right: right);
    }

    var forceRightExterior =
        preference == ApartmentExteriorExposurePreference.oppositeSides;
    for (final unit in units) {
      if (forceRightExterior &&
          exteriorUnits.contains(unit) &&
          left.any(exteriorUnits.contains)) {
        right.add(unit);
        rightArea += unit.areaDm2;
        forceRightExterior = false;
        continue;
      }
      if (leftArea <= rightArea) {
        left.add(unit);
        leftArea += unit.areaDm2;
      } else {
        right.add(unit);
        rightArea += unit.areaDm2;
      }
    }
    return _SidePlan(left: left, right: right);
  }

  _SideLayout? _layoutSide(
    List<_LayoutUnit> units,
    Map<String, FittedSpaceArea> fittedByKey,
  ) {
    final items = <_SpokeLayout>[];
    var totalSpan = 0;
    for (final unit in units) {
      for (final space in unit.members) {
        final area = fittedByKey[space.semanticKey]!;
        final dimensions = _spokeDimensions(space, area);
        if (dimensions == null) {
          return null;
        }
        items.add(
          _SpokeLayout(
            space: space,
            area: area,
            spanMm: dimensions.spanMm,
            depthMm: dimensions.depthMm,
          ),
        );
        totalSpan += dimensions.spanMm;
      }
    }
    return _SideLayout(items: items, totalSpanMm: totalSpan);
  }

  _SpokeDimensions? _spokeDimensions(
    DraftSpace space,
    FittedSpaceArea area,
  ) {
    final geometry = space.sourceSpec.geometry;
    var minSpan = geometry.minShortSideMm;
    final exposure = geometry.minExteriorExposureMm ?? 0;
    if (space.sourceSpec.requiresExteriorExposure && exposure > minSpan) {
      minSpan = exposure;
    }
    for (var spanMm = _ceilGrid(minSpan);
        spanMm <= maxRoomSpanMm;
        spanMm += p9GeometryGridMm) {
      final depthMm = _nearestGrid(area.areaDm2 * 10000 ~/ spanMm);
      if (_rectangleValid(
        space,
        area,
        widthMm: depthMm,
        heightMm: spanMm,
        exteriorLengthMm: spanMm,
      )) {
        return _SpokeDimensions(spanMm: spanMm, depthMm: depthMm);
      }
    }
    return null;
  }

  _SpineDimensions? _distributionDimensions(
    DraftSpace distribution,
    FittedSpaceArea area,
    int requiredLengthMm,
  ) {
    final geometry = distribution.sourceSpec.geometry;
    final start = _ceilGrid(
      _max(requiredLengthMm, geometry.minLongSideMm ?? requiredLengthMm),
    );
    for (var lengthMm = start;
        lengthMm <= maxSpineLengthMm;
        lengthMm += p9GeometryGridMm) {
      final widthMm = _nearestGrid(area.areaDm2 * 10000 ~/ lengthMm);
      if (_rectangleValid(
        distribution,
        area,
        widthMm: widthMm,
        heightMm: lengthMm,
        exteriorLengthMm: 0,
      )) {
        return _SpineDimensions(widthMm: widthMm, lengthMm: lengthMm);
      }
    }
    return null;
  }

  bool _rectangleValid(
    DraftSpace space,
    FittedSpaceArea area, {
    required int widthMm,
    required int heightMm,
    required int exteriorLengthMm,
  }) {
    if (widthMm <= 0 || heightMm <= 0) {
      return false;
    }
    final geometry = space.sourceSpec.geometry;
    final shortSide = _min(widthMm, heightMm);
    final longSide = _max(widthMm, heightMm);
    if (shortSide < geometry.minShortSideMm ||
        (geometry.minLongSideMm != null &&
            longSide < geometry.minLongSideMm!)) {
      return false;
    }
    final aspectBp = widthMm * 10000 ~/ heightMm;
    if (aspectBp < geometry.minAspectBp || aspectBp > geometry.maxAspectBp) {
      return false;
    }
    if (space.sourceSpec.requiresExteriorExposure &&
        exteriorLengthMm < (geometry.minExteriorExposureMm ?? 1)) {
      return false;
    }
    final target = area.areaDm2 * 10000;
    return (widthMm * heightMm - target).abs() <= _areaTolerance(target);
  }

  List<GeneratedSpaceGeometry> _materializeSide({
    required _SideLayout side,
    required bool leftSide,
    required int spineX,
    required int spineWidthMm,
  }) {
    final result = <GeneratedSpaceGeometry>[];
    var yMm = 0;
    for (final item in side.items) {
      result.add(
        GeneratedSpaceGeometry(
          semanticKey: item.space.semanticKey,
          participation: item.space.areaParticipation,
          polygon: RectilinearPolygonMm.rectangle(
            xMm: leftSide ? spineX - item.depthMm : spineX + spineWidthMm,
            yMm: yMm,
            widthMm: item.depthMm,
            heightMm: item.spanMm,
          ),
          fittedAreaDm2: item.area.areaDm2,
        ),
      );
      yMm += item.spanMm;
    }
    return result;
  }

  List<GeneratedSpaceGeometry> _materializeAppendages({
    required List<DraftSpace> appendageDraft,
    required Map<String, FittedSpaceArea> fittedByKey,
    required List<GeneratedSpaceGeometry> interiorSpaces,
    required RectilinearPolygonMm envelope,
    required TopologyGeometryHandoff handoff,
    required List<P9Failure> failures,
  }) {
    final byKey = {
      for (final space in interiorSpaces) space.semanticKey: space,
    };
    final result = <GeneratedSpaceGeometry>[];
    final usedByHost = <String, int>{};
    for (final appendage in appendageDraft) {
      final access = handoff.accessIntents.where(
        (intent) =>
            intent.pair.leftKey == appendage.semanticKey ||
            intent.pair.rightKey == appendage.semanticKey,
      );
      String? hostKey;
      for (final intent in access) {
        final other = intent.pair.leftKey == appendage.semanticKey
            ? intent.pair.rightKey
            : intent.pair.leftKey;
        if (byKey.containsKey(other)) {
          hostKey = other;
          break;
        }
      }
      final host = hostKey == null ? null : byKey[hostKey];
      if (host == null) {
        failures.add(
          _failure(
            'p9.geometry.appendage-attachment',
            facts: {'spaceKey': appendage.semanticKey},
          ),
        );
        continue;
      }
      final area = fittedByKey[appendage.semanticKey]!;
      final used = usedByHost[hostKey!] ?? 0;
      final placement = _appendagePlacement(
        appendage,
        area,
        host,
        envelope,
        used,
      );
      if (placement == null) {
        failures.add(
          _failure(
            'p9.geometry.appendage-attachment',
            facts: {'spaceKey': appendage.semanticKey, 'hostKey': hostKey},
          ),
        );
        continue;
      }
      usedByHost[hostKey] = used + placement.attachmentMm;
      result.add(
        GeneratedSpaceGeometry(
          semanticKey: appendage.semanticKey,
          participation: appendage.areaParticipation,
          polygon: placement.polygon,
          fittedAreaDm2: area.areaDm2,
        ),
      );
    }
    return result;
  }

  _AppendagePlacement? _appendagePlacement(
    DraftSpace appendage,
    FittedSpaceArea area,
    GeneratedSpaceGeometry host,
    RectilinearPolygonMm envelope,
    int usedMm,
  ) {
    final leftHost = host.polygon.minX == envelope.minX;
    final rightHost = host.polygon.maxX == envelope.maxX;
    if (!leftHost && !rightHost) {
      return null;
    }
    final available = host.polygon.heightMm - usedMm;
    final geometry = appendage.sourceSpec.geometry;
    for (var attachmentMm = _ceilGrid(geometry.minLongSideMm ?? 1200);
        attachmentMm <= available;
        attachmentMm += p9GeometryGridMm) {
      final depthMm = _nearestGrid(area.areaDm2 * 10000 ~/ attachmentMm);
      if (!_rectangleValid(
        appendage,
        area,
        widthMm: depthMm,
        heightMm: attachmentMm,
        exteriorLengthMm: 0,
      )) {
        continue;
      }
      return _AppendagePlacement(
        attachmentMm: attachmentMm,
        polygon: RectilinearPolygonMm.rectangle(
          xMm: leftHost ? host.polygon.minX - depthMm : host.polygon.maxX,
          yMm: host.polygon.minY + usedMm,
          widthMm: depthMm,
          heightMm: attachmentMm,
        ),
      );
    }
    return null;
  }

  RectilinearPolygonMm? _unionEnvelope(List<RectilinearPolygonMm> rectangles) {
    if (rectangles.isEmpty) {
      return null;
    }
    final xs = <int>{};
    final ys = <int>{};
    for (final rectangle in rectangles) {
      xs.addAll([rectangle.minX, rectangle.maxX]);
      ys.addAll([rectangle.minY, rectangle.maxY]);
    }
    final x = xs.toList()..sort();
    final y = ys.toList()..sort();
    final occupied = <String>{};
    for (var xi = 0; xi < x.length - 1; xi++) {
      for (var yi = 0; yi < y.length - 1; yi++) {
        final x0 = x[xi];
        final x1 = x[xi + 1];
        final y0 = y[yi];
        final y1 = y[yi + 1];
        final inside = rectangles.any(
          (rectangle) =>
              x0 >= rectangle.minX &&
              x1 <= rectangle.maxX &&
              y0 >= rectangle.minY &&
              y1 <= rectangle.maxY,
        );
        if (inside) {
          occupied.add('$xi:$yi');
        }
      }
    }

    final adjacency = <String, Set<String>>{};
    void edge(int ax, int ay, int bx, int by) {
      final a = '$ax,$ay';
      final b = '$bx,$by';
      adjacency.putIfAbsent(a, () => <String>{}).add(b);
      adjacency.putIfAbsent(b, () => <String>{}).add(a);
    }

    for (final key in occupied) {
      final parts = key.split(':');
      final xi = int.parse(parts[0]);
      final yi = int.parse(parts[1]);
      if (!occupied.contains('$xi:${yi - 1}')) {
        edge(x[xi], y[yi], x[xi + 1], y[yi]);
      }
      if (!occupied.contains('${xi + 1}:$yi')) {
        edge(x[xi + 1], y[yi], x[xi + 1], y[yi + 1]);
      }
      if (!occupied.contains('$xi:${yi + 1}')) {
        edge(x[xi + 1], y[yi + 1], x[xi], y[yi + 1]);
      }
      if (!occupied.contains('${xi - 1}:$yi')) {
        edge(x[xi], y[yi + 1], x[xi], y[yi]);
      }
    }
    if (adjacency.isEmpty || adjacency.values.any((next) => next.length != 2)) {
      return null;
    }
    final start = adjacency.keys.toList()..sort(_comparePointKey);
    final vertices = <BoundaryPointMm>[];
    var current = start.first;
    String? previous;
    do {
      vertices.add(_point(current));
      final next = adjacency[current]!.toList()..sort(_comparePointKey);
      final selected = next.first != previous ? next.first : next.last;
      previous = current;
      current = selected;
      if (vertices.length > adjacency.length + 1) {
        return null;
      }
    } while (current != start.first);
    return RectilinearPolygonMm.normalized(vertices);
  }

  List<GeneratedSharedBoundary> _sharedBoundaries(
    List<GeneratedSpaceGeometry> spaces,
  ) {
    final result = <GeneratedSharedBoundary>[];
    for (var first = 0; first < spaces.length; first++) {
      for (var second = first + 1; second < spaces.length; second++) {
        GeometrySegmentMm? longest;
        for (final a in spaces[first].polygon.segments) {
          for (final b in spaces[second].polygon.segments) {
            final overlap = intersectCollinearSegments(a, b);
            if (overlap != null &&
                (longest == null || overlap.lengthMm > longest.lengthMm)) {
              longest = overlap;
            }
          }
        }
        if (longest != null) {
          result.add(
            GeneratedSharedBoundary(
              leftSpaceKey: spaces[first].semanticKey,
              rightSpaceKey: spaces[second].semanticKey,
              segment: longest,
            ),
          );
        }
      }
    }
    return result;
  }

  List<GeneratedExteriorBoundary> _exteriorBoundaries(
    List<GeneratedSpaceGeometry> spaces,
    RectilinearPolygonMm envelope,
    int spineX,
  ) {
    final result = <GeneratedExteriorBoundary>[];
    for (final space in spaces) {
      for (final segment in space.polygon.segments) {
        for (final boundary in envelope.segments) {
          final overlap = intersectCollinearSegments(segment, boundary);
          if (overlap == null) {
            continue;
          }
          result.add(
            GeneratedExteriorBoundary(
              spaceSemanticKey: space.semanticKey,
              side: _side(overlap, envelope, spineX),
              segment: overlap,
            ),
          );
        }
      }
    }
    return result;
  }

  GeometryEnvelopeSide _side(
    GeometrySegmentMm segment,
    RectilinearPolygonMm envelope,
    int spineX,
  ) {
    if (!segment.vertical && segment.start.yMm == envelope.minY) {
      return GeometryEnvelopeSide.north;
    }
    if (!segment.vertical && segment.start.yMm == envelope.maxY) {
      return GeometryEnvelopeSide.south;
    }
    if (segment.vertical) {
      return segment.start.xMm <= spineX
          ? GeometryEnvelopeSide.west
          : GeometryEnvelopeSide.east;
    }
    return segment.start.yMm < (envelope.minY + envelope.maxY) ~/ 2
        ? GeometryEnvelopeSide.north
        : GeometryEnvelopeSide.south;
  }

  List<OpeningIntent> _openingIntents({
    required ApartmentTopologyDraft draft,
    required TopologyGeometryHandoff handoff,
    required List<GeneratedSharedBoundary> shared,
    required List<GeneratedExteriorBoundary> exterior,
  }) {
    final openings = <OpeningIntent>[];
    final entry = draft.circulation.entrySpaceKey;
    final entryBoundaries = exterior
        .where((boundary) => boundary.spaceSemanticKey == entry)
        .toList()
      ..sort((a, b) => a.segment.stableKey.compareTo(b.segment.stableKey));
    if (entryBoundaries.isNotEmpty) {
      openings.add(
        OpeningIntent(
          kind: GeometryOpeningKind.primaryEntry,
          fromSpaceKey: entry,
          hostSegment: entryBoundaries.first.segment,
        ),
      );
    }
    final byPair = {
      for (final boundary in shared) boundary.pair.stableKey: boundary,
    };
    for (final access in handoff.accessIntents) {
      final boundary = byPair[access.pair.stableKey];
      if (boundary == null) {
        continue;
      }
      openings.add(
        OpeningIntent(
          kind: access.kind == DraftAccessKind.openPassage
              ? GeometryOpeningKind.openPassage
              : GeometryOpeningKind.door,
          fromSpaceKey: access.pair.leftKey,
          toSpaceKey: access.pair.rightKey,
          hostSegment: boundary.segment,
        ),
      );
    }
    return openings;
  }

  List<GeometryValidationIssue> _validate({
    required AreaFittedTopologyDraft fittedDraft,
    required ApartmentTopologyTemplate template,
    required TopologyGeometryHandoff handoff,
    required RectilinearPolygonMm envelope,
    required List<GeneratedSpaceGeometry> interiorSpaces,
    required List<GeneratedSpaceGeometry> appendages,
    required List<GeneratedSharedBoundary> shared,
    required List<GeneratedExteriorBoundary> exterior,
  }) {
    final issues = <GeometryValidationIssue>[];
    final draftByKey = {
      for (final space in fittedDraft.draft.spaces) space.semanticKey: space,
    };
    for (final generated in [...interiorSpaces, ...appendages]) {
      final draftSpace = draftByKey[generated.semanticKey]!;
      final geometry = draftSpace.sourceSpec.geometry;
      final width = generated.polygon.widthMm;
      final height = generated.polygon.heightMm;
      final shortSide = _min(width, height);
      final longSide = _max(width, height);
      final target = generated.fittedAreaDm2 * 10000;
      if ((generated.realizedAreaMm2 - target).abs() > _areaTolerance(target)) {
        issues.add(
            _issue('p9.geometry.unsatisfiable-area', generated.semanticKey));
      }
      if (shortSide < geometry.minShortSideMm ||
          (geometry.minLongSideMm != null &&
              longSide < geometry.minLongSideMm!)) {
        issues.add(_issue('p9.geometry.min-dimension', generated.semanticKey));
      }
      final aspect = width * 10000 ~/ height;
      if (aspect < geometry.minAspectBp || aspect > geometry.maxAspectBp) {
        issues.add(_issue('p9.geometry.aspect-ratio', generated.semanticKey));
      }
    }
    final interiorArea = interiorSpaces.fold<int>(
      0,
      (sum, space) => sum + space.realizedAreaMm2,
    );
    final requested = fittedDraft.requestedInteriorAreaDm2 * 10000;
    if ((interiorArea - requested).abs() > _areaTolerance(requested) ||
        envelope.areaMm2 != interiorArea) {
      issues.add(
        GeometryValidationIssue(
          code: 'p9.geometry.unassigned-gap',
          severity: GeometryValidationSeverity.blocker,
          facts: {
            'envelopeAreaMm2': envelope.areaMm2,
            'interiorAreaMm2': interiorArea,
            'requestedAreaMm2': requested,
          },
        ),
      );
    }
    final byPair = {
      for (final boundary in shared) boundary.pair.stableKey: boundary,
    };
    for (final pair in handoff.requiredSharedBoundaryPairs) {
      if (!byPair.containsKey(pair.stableKey)) {
        issues.add(
          GeometryValidationIssue(
            code: 'p9.geometry.required-boundary-missing',
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [pair.leftKey, pair.rightKey],
          ),
        );
      }
    }
    for (final pair in handoff.forbiddenSharedBoundaryPairs) {
      if (byPair.containsKey(pair.stableKey)) {
        issues.add(
          GeometryValidationIssue(
            code: 'p9.geometry.forbidden-boundary-present',
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [pair.leftKey, pair.rightKey],
          ),
        );
      }
    }
    final exposure = <String, int>{};
    for (final boundary in exterior) {
      exposure[boundary.spaceSemanticKey] =
          (exposure[boundary.spaceSemanticKey] ?? 0) +
              boundary.segment.lengthMm;
    }
    for (final key in handoff.requiredExteriorSpaceKeys) {
      final draftSpace = draftByKey[key];
      if (draftSpace == null ||
          draftSpace.areaParticipation ==
              SpaceAreaParticipation.exteriorAppendage) {
        continue;
      }
      final required =
          draftSpace.sourceSpec.geometry.minExteriorExposureMm ?? 1;
      if ((exposure[key] ?? 0) < required) {
        issues.add(
          GeometryValidationIssue(
            code: 'p9.geometry.exterior-exposure-missing',
            severity: GeometryValidationSeverity.blocker,
            affectedKeys: [key],
          ),
        );
      }
    }
    final wet = _wetSeparation(
        handoff.wetCoreGroups, [...interiorSpaces, ...appendages]);
    if (wet > template.wetCorePolicy.maxGroupSeparationMm) {
      issues.add(
        GeometryValidationIssue(
          code: 'p9.geometry.wet-core-too-dispersed',
          severity: GeometryValidationSeverity.blocker,
          facts: {'actualMm': wet},
        ),
      );
    }
    return issues;
  }

  GeometryMetrics _metrics({
    required TopologyGeometryHandoff handoff,
    required List<GeneratedSpaceGeometry> interiorSpaces,
    required List<GeneratedSpaceGeometry> appendages,
    required List<GeneratedSharedBoundary> shared,
    required List<GeneratedExteriorBoundary> exterior,
  }) {
    var maxAreaError = 0;
    for (final space in [...interiorSpaces, ...appendages]) {
      maxAreaError = _max(
        maxAreaError,
        (space.realizedAreaMm2 - space.fittedAreaDm2 * 10000).abs(),
      );
    }
    final exteriorKeys = handoff.requiredExteriorSpaceKeys.toSet();
    return GeometryMetrics(
      interiorAreaMm2: interiorSpaces.fold(
        0,
        (sum, space) => sum + space.realizedAreaMm2,
      ),
      appendageAreaMm2: appendages.fold(
        0,
        (sum, space) => sum + space.realizedAreaMm2,
      ),
      maxAreaErrorMm2: maxAreaError,
      sharedBoundaryLengthMm: shared.fold(
        0,
        (sum, boundary) => sum + boundary.lengthMm,
      ),
      exteriorExposureLengthMm: exterior
          .where((boundary) => exteriorKeys.contains(boundary.spaceSemanticKey))
          .fold(0, (sum, boundary) => sum + boundary.segment.lengthMm),
      wetCoreMaxSeparationMm: _wetSeparation(
        handoff.wetCoreGroups,
        [...interiorSpaces, ...appendages],
      ),
    );
  }

  String _fingerprint({
    required AreaFittedTopologyDraft fittedDraft,
    required RectilinearPolygonMm envelope,
    required List<GeneratedSpaceGeometry> interiorSpaces,
    required List<GeneratedSpaceGeometry> appendages,
    required List<GeneratedSharedBoundary> shared,
    required List<GeneratedExteriorBoundary> exterior,
    required List<OpeningIntent> openings,
  }) {
    final lines = <String>[
      'p9.apartment.geometry',
      'algorithm=$geometryAlgorithmVersion',
      'areaFit=${fittedDraft.areaFitFingerprint}',
      'envelope=${envelope.stableSerialization}',
    ];
    final spaces = [...interiorSpaces, ...appendages]
      ..sort((a, b) => a.semanticKey.compareTo(b.semanticKey));
    for (final space in spaces) {
      lines.add(
        'space=${space.semanticKey}|${space.participation.name}|${space.polygon.stableSerialization}',
      );
    }
    final boundaries = shared.toList()
      ..sort((a, b) => a.pair.stableKey.compareTo(b.pair.stableKey));
    for (final boundary in boundaries) {
      lines.add(
          'shared=${boundary.pair.stableKey}|${boundary.segment.stableKey}');
    }
    final outer = exterior.toList()
      ..sort((a, b) => '${a.spaceSemanticKey}|${a.segment.stableKey}'
          .compareTo('${b.spaceSemanticKey}|${b.segment.stableKey}'));
    for (final boundary in outer) {
      lines.add(
        'exterior=${boundary.spaceSemanticKey}|${boundary.side.name}|${boundary.segment.stableKey}',
      );
    }
    for (var index = 0; index < openings.length; index++) {
      final opening = openings[index];
      lines.add(
        'opening=$index|${opening.kind.name}|${opening.fromSpaceKey ?? ''}|${opening.toSpaceKey ?? ''}|${opening.hostSegment.stableKey}',
      );
    }
    return p9Sha256Hex(lines.join('\n'));
  }
}

final class _LayoutUnit {
  const _LayoutUnit({required this.members, required this.areaDm2});

  final List<DraftSpace> members;
  final int areaDm2;
  String get stableKey => members.map((space) => space.semanticKey).join('|');
}

final class _SidePlan {
  const _SidePlan({required this.left, required this.right});

  final List<_LayoutUnit> left;
  final List<_LayoutUnit> right;
}

final class _SideLayout {
  const _SideLayout({required this.items, required this.totalSpanMm});

  final List<_SpokeLayout> items;
  final int totalSpanMm;
}

final class _SpokeLayout {
  const _SpokeLayout({
    required this.space,
    required this.area,
    required this.spanMm,
    required this.depthMm,
  });

  final DraftSpace space;
  final FittedSpaceArea area;
  final int spanMm;
  final int depthMm;
}

final class _SpokeDimensions {
  const _SpokeDimensions({required this.spanMm, required this.depthMm});

  final int spanMm;
  final int depthMm;
}

final class _SpineDimensions {
  const _SpineDimensions({required this.widthMm, required this.lengthMm});

  final int widthMm;
  final int lengthMm;
}

final class _AppendagePlacement {
  const _AppendagePlacement({
    required this.attachmentMm,
    required this.polygon,
  });

  final int attachmentMm;
  final RectilinearPolygonMm polygon;
}

ApartmentGeometryGenerationResult _rejected(
  String code, {
  Map<String, Object?> facts = const {},
}) =>
    ApartmentGeometryGenerationResult(
      candidate: null,
      failures: [_failure(code, facts: facts)],
    );

P9Failure _failure(
  String code, {
  Map<String, Object?> facts = const {},
}) =>
    P9Failure(
      code: code,
      stage: P9FailureStage.geometry,
      severity: P9FailureSeverity.blocker,
      facts: facts,
    );

GeometryValidationIssue _issue(String code, String key) =>
    GeometryValidationIssue(
      code: code,
      severity: GeometryValidationSeverity.blocker,
      affectedKeys: [key],
    );

int _wetSeparation(
  List<List<String>> groups,
  List<GeneratedSpaceGeometry> spaces,
) {
  final byKey = {for (final space in spaces) space.semanticKey: space};
  var maximum = 0;
  for (final group in groups) {
    for (var first = 0; first < group.length; first++) {
      for (var second = first + 1; second < group.length; second++) {
        final a = byKey[group[first]];
        final b = byKey[group[second]];
        if (a == null || b == null) {
          continue;
        }
        final dx = _axisGap(
            a.polygon.minX, a.polygon.maxX, b.polygon.minX, b.polygon.maxX);
        final dy = _axisGap(
            a.polygon.minY, a.polygon.maxY, b.polygon.minY, b.polygon.maxY);
        maximum = _max(maximum, dx + dy);
      }
    }
  }
  return maximum;
}

int _axisGap(int aMin, int aMax, int bMin, int bMax) {
  if (aMax < bMin) {
    return bMin - aMax;
  }
  if (bMax < aMin) {
    return aMin - bMax;
  }
  return 0;
}

int _compareDraftSpace(DraftSpace a, DraftSpace b) =>
    a.semanticKey.compareTo(b.semanticKey);

int _comparePointKey(String a, String b) {
  final ap = _point(a);
  final bp = _point(b);
  final x = ap.xMm.compareTo(bp.xMm);
  return x != 0 ? x : ap.yMm.compareTo(bp.yMm);
}

BoundaryPointMm _point(String key) {
  final parts = key.split(',');
  return BoundaryPointMm(xMm: int.parse(parts[0]), yMm: int.parse(parts[1]));
}

int _areaTolerance(int targetMm2) =>
    _max(minimumAreaToleranceMm2Value, targetMm2 ~/ 200);

const int minimumAreaToleranceMm2Value = 200000;

int _nearestGrid(int valueMm) {
  if (valueMm <= 0) {
    return 0;
  }
  final lower = valueMm ~/ p9GeometryGridMm * p9GeometryGridMm;
  final upper = lower + p9GeometryGridMm;
  return valueMm - lower <= upper - valueMm ? lower : upper;
}

int _ceilGrid(int valueMm) =>
    ((valueMm + p9GeometryGridMm - 1) ~/ p9GeometryGridMm) * p9GeometryGridMm;

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;
