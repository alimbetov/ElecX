import '../domain/electrical_circuit_synthesis.dart';
import '../domain/electrical_load_calculation.dart';

const String electricalCircuitSynthesisVersion =
    'electrical.circuit-synthesis.v2';

/// Deterministic policy-driven circuit synthesis.
///
/// The engine applies source-pinned grouping and dedicated-circuit policies. It
/// contains no implicit residential appliance rules. Non-dedicated loads are
/// packed using deterministic first-fit decreasing within compatibility
/// partitions formed by phase system and the explicit grouping policy.
abstract final class CircuitGroupingEngine {
  static ElectricalCircuitSynthesisResult synthesize(
    ElectricalCircuitSynthesisRequest request,
  ) {
    _validateRequest(request);

    final dedicated = <_CircuitDraft>[];
    final groupedCandidates = <CircuitSynthesisLoad>[];

    final orderedLoads = request.loads.toList()
      ..sort(_compareLoadsForClassification);

    for (final item in orderedLoads) {
      final matchingRule = _matchingDedicatedRule(
        request.dedicatedCircuitPolicy,
        item,
      );
      if (matchingRule != null) {
        dedicated.add(
          _CircuitDraft(
            phaseSystem: item.requiredPhaseSystem,
            loads: [item],
            dedicatedRuleId: matchingRule.id,
          ),
        );
      } else {
        groupedCandidates.add(item);
      }
    }

    final grouped = <_CircuitDraft>[];
    final buckets = <String, List<CircuitSynthesisLoad>>{};
    for (final item in groupedCandidates) {
      final key = _groupingBucketKey(request.groupingPolicy, item);
      buckets.putIfAbsent(key, () => <CircuitSynthesisLoad>[]).add(item);
    }

    final bucketKeys = buckets.keys.toList()..sort();
    for (final key in bucketKeys) {
      final loads = buckets[key]!
        ..sort((left, right) {
          final byPower = right.load.connectedPowerW.compareTo(
            left.load.connectedPowerW,
          );
          if (byPower != 0) return byPower;
          return left.load.id.compareTo(right.load.id);
        });

      final drafts = <_CircuitDraft>[];
      for (final item in loads) {
        if (item.load.connectedPowerW >
            request.groupingPolicy.maxGroupedConnectedPowerW) {
          throw StateError(
            'Load ${item.load.id} exceeds grouped circuit power policy and has '
            'no matching dedicated-circuit rule.',
          );
        }

        _CircuitDraft? target;
        for (final draft in drafts) {
          if (_fitsGroupedCircuit(
            draft,
            item,
            request.groupingPolicy,
          )) {
            target = draft;
            break;
          }
        }
        if (target == null) {
          drafts.add(
            _CircuitDraft(
              phaseSystem: item.requiredPhaseSystem,
              loads: [item],
            ),
          );
        } else {
          target.loads.add(item);
        }
      }
      grouped.addAll(drafts);
    }

    final drafts = [...dedicated, ...grouped]..sort(_compareCircuitDrafts);

    final circuits = <SynthesizedElectricalCircuit>[];
    for (var index = 0; index < drafts.length; index++) {
      final draft = drafts[index];
      circuits.add(
        SynthesizedElectricalCircuit(
          id: 'circuit-${(index + 1).toString().padLeft(3, '0')}',
          requiredPhaseSystem: draft.phaseSystem,
          dedicated: draft.dedicatedRuleId != null,
          loads: draft.loads,
          groupingPolicyId: request.groupingPolicy.id,
          groupingPolicyRevision: request.groupingPolicy.sourceRevision,
          dedicatedPolicyId: request.dedicatedCircuitPolicy.id,
          dedicatedPolicyRevision:
              request.dedicatedCircuitPolicy.sourceRevision,
          dedicatedRuleId: draft.dedicatedRuleId,
        ),
      );
    }

    return ElectricalCircuitSynthesisResult(circuits: circuits);
  }

  static void _validateRequest(ElectricalCircuitSynthesisRequest request) {
    for (final item in request.loads) {
      final load = item.load;
      if (item.locationId.trim().isEmpty) {
        throw ArgumentError(
          'Circuit-synthesis load ${load.id} requires a non-empty location.',
        );
      }
      if (load.id.trim().isEmpty ||
          load.sourceId.trim().isEmpty ||
          load.sourceRevision.trim().isEmpty) {
        throw ArgumentError(
          'Circuit-synthesis load identity/source fields must be non-empty.',
        );
      }
      if (load.ratedPowerW < 0) {
        throw ArgumentError.value(load.ratedPowerW, 'ratedPowerW');
      }
      if (load.quantity <= 0) {
        throw ArgumentError.value(load.quantity, 'quantity');
      }
      if (!load.utilizationFactor.isFinite ||
          load.utilizationFactor <= 0 ||
          load.utilizationFactor > 1) {
        throw ArgumentError.value(
          load.utilizationFactor,
          'utilizationFactor',
        );
      }
      if (!load.powerFactor.isFinite ||
          load.powerFactor <= 0 ||
          load.powerFactor > 1) {
        throw ArgumentError.value(load.powerFactor, 'powerFactor');
      }
    }
  }

  static DedicatedCircuitRule? _matchingDedicatedRule(
    DedicatedCircuitPolicy policy,
    CircuitSynthesisLoad item,
  ) {
    final matches = policy.rules
        .where((rule) => rule.matches(item))
        .toList(growable: false);
    if (matches.length > 1) {
      throw StateError(
        'Load ${item.load.id} matches multiple dedicated-circuit rules: '
        '${matches.map((rule) => rule.id).join(', ')}. Explicit policy '
        'precedence is required instead of lexical first-match behavior.',
      );
    }
    return matches.isEmpty ? null : matches.single;
  }

  static String _groupingBucketKey(
    CircuitGroupingPolicy policy,
    CircuitSynthesisLoad item,
  ) {
    final parts = <String>[
      item.requiredPhaseSystem.name,
      if (policy.separateByLocation) item.locationId,
      if (policy.separateByLoadKind) item.kind.name,
    ];
    return parts.join('|');
  }

  static bool _fitsGroupedCircuit(
    _CircuitDraft draft,
    CircuitSynthesisLoad candidate,
    CircuitGroupingPolicy policy,
  ) {
    if (draft.phaseSystem != candidate.requiredPhaseSystem) return false;
    if (draft.loads.length >= policy.maxGroupedLoadsPerCircuit) return false;
    final connectedPower = draft.loads.fold<int>(
          0,
          (sum, item) => sum + item.load.connectedPowerW,
        ) +
        candidate.load.connectedPowerW;
    return connectedPower <= policy.maxGroupedConnectedPowerW;
  }

  static int _compareLoadsForClassification(
    CircuitSynthesisLoad left,
    CircuitSynthesisLoad right,
  ) {
    final byPhase = left.requiredPhaseSystem.name.compareTo(
      right.requiredPhaseSystem.name,
    );
    if (byPhase != 0) return byPhase;
    final byLocation = left.locationId.compareTo(right.locationId);
    if (byLocation != 0) return byLocation;
    final byKind = left.kind.name.compareTo(right.kind.name);
    if (byKind != 0) return byKind;
    return left.load.id.compareTo(right.load.id);
  }

  static int _compareCircuitDrafts(_CircuitDraft left, _CircuitDraft right) {
    final leftDedicated = left.dedicatedRuleId != null ? 0 : 1;
    final rightDedicated = right.dedicatedRuleId != null ? 0 : 1;
    final byDedicated = leftDedicated.compareTo(rightDedicated);
    if (byDedicated != 0) return byDedicated;
    final byPhase = left.phaseSystem.name.compareTo(right.phaseSystem.name);
    if (byPhase != 0) return byPhase;
    final leftIds =
        (left.loads.map((item) => item.load.id).toList()..sort()).join('|');
    final rightIds =
        (right.loads.map((item) => item.load.id).toList()..sort()).join('|');
    return leftIds.compareTo(rightIds);
  }
}

final class _CircuitDraft {
  _CircuitDraft({
    required this.phaseSystem,
    required this.loads,
    this.dedicatedRuleId,
  });

  final ElectricalLoadPhaseSystem phaseSystem;
  final List<CircuitSynthesisLoad> loads;
  final String? dedicatedRuleId;
}
