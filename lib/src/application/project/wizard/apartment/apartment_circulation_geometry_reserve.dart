import '../../../../domain/apartment_topology.dart';
import '../../../../domain/apartment_topology/apartment_geometry.dart';
import '../../../../domain/apartment_topology/apartment_topology_draft.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import '../../../../domain/project_space_semantics.dart';
import 'apartment_wizard_parameters.dart';

/// Result of the P9.4 -> P9.6 circulation feasibility bridge.
final class CirculationGeometryReserveResult {
  CirculationGeometryReserveResult({
    required Map<String, int> allocations,
    this.failureCode,
    Map<String, Object?> facts = const {},
  })  : allocations = Map.unmodifiable(allocations),
        facts = Map.unmodifiable(facts);

  final Map<String, int> allocations;
  final String? failureCode;
  final Map<String, Object?> facts;

  bool get accepted => failureCode == null;
}

/// Rebalances a completed P9.4 allocation so the circulation hub can realize
/// the contact spans required by the final room areas in P9.6.
///
/// This is not a geometry generator. It mirrors only the bounded rectangular
/// feasibility rules used by the access-spine layout. The total requested
/// interior area remains exact; area is moved from deterministic donor spaces
/// to the circulation hub only when necessary.
final class ApartmentCirculationGeometryReserve {
  const ApartmentCirculationGeometryReserve();

  static const int maxRoomSpanMm = 9000;
  static const int maxSpineLengthMm = 24000;
  static const int minimumAreaToleranceMm2 = 200000;
  static const int maxRebalanceIterations = 16;
  static const int squareMillimetresPerSquareDecimetre = 10000;

  CirculationGeometryReserveResult rebalance({
    required ApartmentTopologyDraft draft,
    required NormalizedApartmentRequest request,
    required List<DraftSpace> interiorSpaces,
    required Map<String, int> allocations,
  }) {
    final adjusted = Map<String, int>.from(allocations);
    final distribution = _distributionSpace(interiorSpaces);
    if (distribution == null) {
      return CirculationGeometryReserveResult(allocations: adjusted);
    }

    for (var iteration = 0;
        iteration < maxRebalanceIterations;
        iteration++) {
      final plan = _plan(
        draft: draft,
        request: request,
        interiorSpaces: interiorSpaces,
        allocations: adjusted,
        distribution: distribution,
      );
      if (plan.failureCode != null) {
        return CirculationGeometryReserveResult(
          allocations: adjusted,
          failureCode: plan.failureCode,
          facts: plan.facts,
        );
      }

      final current = adjusted[distribution.semanticKey]!;
      final target = plan.requiredDistributionAreaDm2!;
      if (current >= target) {
        return CirculationGeometryReserveResult(allocations: adjusted);
      }
      if (target > distribution.sourceSpec.maxAreaDm2) {
        return CirculationGeometryReserveResult(
          allocations: adjusted,
          failureCode: 'p9.area.circulation-geometry-reserve',
          facts: {
            'semanticKey': distribution.semanticKey,
            'requiredAreaDm2': target,
            'maximumAreaDm2': distribution.sourceSpec.maxAreaDm2,
            'requiredLengthMm': plan.requiredSpineLengthMm,
          },
        );
      }

      var needed = target - current;
      final donors = interiorSpaces
          .where((space) => space.semanticKey != distribution.semanticKey)
          .where(
            (space) =>
                adjusted[space.semanticKey]! > space.sourceSpec.minAreaDm2,
          )
          .toList()
        ..sort((left, right) {
          final leftSurplus =
              adjusted[left.semanticKey]! - left.sourceSpec.minAreaDm2;
          final rightSurplus =
              adjusted[right.semanticKey]! - right.sourceSpec.minAreaDm2;
          final surplus = rightSurplus.compareTo(leftSurplus);
          return surplus != 0
              ? surplus
              : left.semanticKey.compareTo(right.semanticKey);
        });

      var transferred = 0;
      for (final donor in donors) {
        if (needed == 0) {
          break;
        }
        final currentDonor = adjusted[donor.semanticKey]!;
        final available = currentDonor - donor.sourceSpec.minAreaDm2;
        final amount = available < needed ? available : needed;
        if (amount <= 0) {
          continue;
        }
        adjusted[donor.semanticKey] = currentDonor - amount;
        adjusted[distribution.semanticKey] =
            adjusted[distribution.semanticKey]! + amount;
        transferred += amount;
        needed -= amount;
      }

      if (needed > 0 || transferred == 0) {
        return CirculationGeometryReserveResult(
          allocations: adjusted,
          failureCode: 'p9.area.circulation-geometry-reserve',
          facts: {
            'semanticKey': distribution.semanticKey,
            'requiredAreaDm2': target,
            'currentAreaDm2': current,
            'unfundedAreaDm2': needed,
            'requiredLengthMm': plan.requiredSpineLengthMm,
          },
        );
      }
    }

    return CirculationGeometryReserveResult(
      allocations: adjusted,
      failureCode: 'p9.area.circulation-rebalance-limit',
      facts: {
        'maxIterations': maxRebalanceIterations,
        'distributionKey': distribution.semanticKey,
      },
    );
  }

  _ReservePlan _plan({
    required ApartmentTopologyDraft draft,
    required NormalizedApartmentRequest request,
    required List<DraftSpace> interiorSpaces,
    required Map<String, int> allocations,
    required DraftSpace distribution,
  }) {
    final spokes = interiorSpaces
        .where((space) => space.semanticKey != distribution.semanticKey)
        .toList()
      ..sort(_compareSpace);
    if (spokes.isEmpty) {
      return _ReservePlan(
        requiredSpineLengthMm:
            distribution.sourceSpec.geometry.minLongSideMm ?? 0,
        requiredDistributionAreaDm2: distribution.sourceSpec.preferredAreaDm2,
      );
    }

    final units = _buildUnits(draft, spokes, allocations);
    for (final unit in units) {
      for (final member in unit.members) {
        final span = _minimumSpokeSpanMm(
          member,
          allocations[member.semanticKey]!,
        );
        if (span == null) {
          return _ReservePlan.failure(
            'p9.area.geometry-span-unrealizable',
            facts: {
              'semanticKey': member.semanticKey,
              'areaDm2': allocations[member.semanticKey],
            },
          );
        }
        unit.spanByKey[member.semanticKey] = span;
      }
    }

    final sides = _assignSides(units, request.exteriorExposurePreference);
    final leftSpan = sides.left.fold<int>(
      0,
      (sum, unit) => sum + unit.totalSpanMm,
    );
    final rightSpan = sides.right.fold<int>(
      0,
      (sum, unit) => sum + unit.totalSpanMm,
    );
    var requiredLengthMm = leftSpan > rightSpan ? leftSpan : rightSpan;
    final minLong = distribution.sourceSpec.geometry.minLongSideMm ?? 0;
    if (requiredLengthMm < minLong) {
      requiredLengthMm = minLong;
    }
    final requiredArea = _minimumDistributionAreaDm2(
      distribution,
      requiredLengthMm,
    );
    if (requiredArea == null) {
      return _ReservePlan.failure(
        'p9.area.circulation-geometry-reserve',
        facts: {
          'semanticKey': distribution.semanticKey,
          'requiredLengthMm': requiredLengthMm,
          'maximumAreaDm2': distribution.sourceSpec.maxAreaDm2,
        },
      );
    }
    return _ReservePlan(
      requiredSpineLengthMm: requiredLengthMm,
      requiredDistributionAreaDm2: requiredArea,
    );
  }

  List<_ReserveUnit> _buildUnits(
    ApartmentTopologyDraft draft,
    List<DraftSpace> spokes,
    Map<String, int> allocations,
  ) {
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

    for (final adjacency in draft.adjacency) {
      if (adjacency.requirement != TopologyAdjacencyRequirement.required ||
          (adjacency.kind != TopologyAdjacencyKind.directBoundary &&
              adjacency.kind != TopologyAdjacencyKind.openConnection)) {
        continue;
      }
      union(adjacency.fromSpaceKey, adjacency.toSpaceKey);
    }
    for (final group in draft.wetCore.groups) {
      final members = group.where(parent.containsKey).toList()..sort();
      for (var index = 1; index < members.length; index++) {
        union(members.first, members[index]);
      }
    }

    final grouped = <String, List<DraftSpace>>{};
    for (final space in spokes) {
      grouped.putIfAbsent(find(space.semanticKey), () => []).add(space);
    }
    final units = <_ReserveUnit>[];
    for (final members in grouped.values) {
      members.sort(_compareSpace);
      units.add(
        _ReserveUnit(
          members: members,
          areaDm2: members.fold<int>(
            0,
            (sum, member) => sum + allocations[member.semanticKey]!,
          ),
        ),
      );
    }
    units.sort((left, right) => left.stableKey.compareTo(right.stableKey));
    return units;
  }

  _ReserveSides _assignSides(
    List<_ReserveUnit> units,
    ApartmentExteriorExposurePreference preference,
  ) {
    final left = <_ReserveUnit>[];
    final right = <_ReserveUnit>[];
    var leftArea = 0;
    var rightArea = 0;
    final exteriorUnits = units
        .where(
          (unit) => unit.members.any(
            (space) => space.sourceSpec.requiresExteriorExposure,
          ),
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
      return _ReserveSides(left: left, right: right);
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
    return _ReserveSides(left: left, right: right);
  }

  int? _minimumSpokeSpanMm(DraftSpace space, int areaDm2) {
    final geometry = space.sourceSpec.geometry;
    var minimumSpan = geometry.minShortSideMm;
    final exposure = geometry.minExteriorExposureMm ?? 0;
    if (space.sourceSpec.requiresExteriorExposure &&
        exposure > minimumSpan) {
      minimumSpan = exposure;
    }
    for (var spanMm = _ceilGrid(minimumSpan);
        spanMm <= maxRoomSpanMm;
        spanMm += p9GeometryGridMm) {
      final depthMm = _nearestGrid(
        areaDm2 * squareMillimetresPerSquareDecimetre ~/ spanMm,
      );
      if (_rectangleValid(
        space,
        areaDm2,
        widthMm: depthMm,
        heightMm: spanMm,
        exteriorLengthMm: spanMm,
      )) {
        return spanMm;
      }
    }
    return null;
  }

  int? _minimumDistributionAreaDm2(
    DraftSpace distribution,
    int requiredLengthMm,
  ) {
    final geometry = distribution.sourceSpec.geometry;
    final minimumLength = _max(
      requiredLengthMm,
      geometry.minLongSideMm ?? requiredLengthMm,
    );
    for (var lengthMm = _ceilGrid(minimumLength);
        lengthMm <= maxSpineLengthMm;
        lengthMm += p9GeometryGridMm) {
      var widthMm = geometry.minShortSideMm;
      final aspectWidthMm =
          _ceilDiv(lengthMm * geometry.minAspectBp, 10000);
      if (aspectWidthMm > widthMm) {
        widthMm = aspectWidthMm;
      }
      widthMm = _ceilGrid(widthMm);
      final actualAreaMm2 = widthMm * lengthMm;
      final candidates = <int>{
        actualAreaMm2 ~/ squareMillimetresPerSquareDecimetre,
        _ceilDiv(actualAreaMm2, squareMillimetresPerSquareDecimetre),
      }.toList()
        ..sort();
      for (final areaDm2 in candidates) {
        if (areaDm2 < distribution.sourceSpec.minAreaDm2 ||
            areaDm2 > distribution.sourceSpec.maxAreaDm2) {
          continue;
        }
        final derivedWidthMm = _nearestGrid(
          areaDm2 * squareMillimetresPerSquareDecimetre ~/ lengthMm,
        );
        if (_rectangleValid(
          distribution,
          areaDm2,
          widthMm: derivedWidthMm,
          heightMm: lengthMm,
          exteriorLengthMm: 0,
        )) {
          return areaDm2;
        }
      }
    }
    return null;
  }

  bool _rectangleValid(
    DraftSpace space,
    int areaDm2, {
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
    if (aspectBp < geometry.minAspectBp ||
        aspectBp > geometry.maxAspectBp) {
      return false;
    }
    if (space.sourceSpec.requiresExteriorExposure &&
        exteriorLengthMm < (geometry.minExteriorExposureMm ?? 1)) {
      return false;
    }
    final targetAreaMm2 =
        areaDm2 * squareMillimetresPerSquareDecimetre;
    return (widthMm * heightMm - targetAreaMm2).abs() <=
        _areaToleranceMm2(targetAreaMm2);
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
}

final class _ReservePlan {
  const _ReservePlan({
    required this.requiredSpineLengthMm,
    required this.requiredDistributionAreaDm2,
  })  : failureCode = null,
        facts = const {};

  const _ReservePlan.failure(
    String code, {
    Map<String, Object?> facts = const {},
  })  : requiredSpineLengthMm = null,
        requiredDistributionAreaDm2 = null,
        failureCode = code,
        facts = facts;

  final int? requiredSpineLengthMm;
  final int? requiredDistributionAreaDm2;
  final String? failureCode;
  final Map<String, Object?> facts;
}

final class _ReserveUnit {
  _ReserveUnit({required this.members, required this.areaDm2});

  final List<DraftSpace> members;
  final int areaDm2;
  final Map<String, int> spanByKey = <String, int>{};

  String get stableKey => members.map((space) => space.semanticKey).join('|');
  int get totalSpanMm => members.fold(
        0,
        (sum, member) => sum + spanByKey[member.semanticKey]!,
      );
}

final class _ReserveSides {
  const _ReserveSides({required this.left, required this.right});

  final List<_ReserveUnit> left;
  final List<_ReserveUnit> right;
}

int _areaToleranceMm2(int targetAreaMm2) => _max(
      ApartmentCirculationGeometryReserve.minimumAreaToleranceMm2,
      targetAreaMm2 ~/ 200,
    );

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

int _ceilDiv(int numerator, int denominator) =>
    (numerator + denominator - 1) ~/ denominator;

int _compareSpace(DraftSpace left, DraftSpace right) =>
    left.semanticKey.compareTo(right.semanticKey);

int _min(int left, int right) => left < right ? left : right;
int _max(int left, int right) => left > right ? left : right;
