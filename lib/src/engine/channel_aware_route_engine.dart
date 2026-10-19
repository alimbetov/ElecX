import '../domain/route_host.dart';

final class ChannelRouteState {
  const ChannelRouteState({
    required this.id,
    required this.routeNodeId,
    required this.host,
    required this.installationPathSpecId,
    required this.pathSectionId,
    required this.channelId,
  });

  final String id;
  final String routeNodeId;
  final RouteHostRef host;
  final String installationPathSpecId;
  final String pathSectionId;
  final String channelId;
}

final class ChannelRouteEdge {
  const ChannelRouteEdge({
    required this.from,
    required this.to,
    required this.lengthMm,
    this.transitionCount = 0,
    this.bendCount = 0,
    this.materialCost = 0,
    this.laborCost = 0,
    this.maintainabilityPenalty = 0,
    this.normativeRiskPenalty = 0,
  });

  final String from;
  final String to;
  final double lengthMm;
  final int transitionCount;
  final int bendCount;
  final double materialCost;
  final double laborCost;
  final double maintainabilityPenalty;
  final double normativeRiskPenalty;
}

final class ChannelRouteCostWeights {
  const ChannelRouteCostWeights({
    this.length = 1,
    this.material = 1,
    this.labor = 1,
    this.transitions = 500,
    this.bends = 100,
    this.maintainability = 1,
    this.normativeRisk = 1000,
  });

  final double length;
  final double material;
  final double labor;
  final double transitions;
  final double bends;
  final double maintainability;
  final double normativeRisk;
}

final class ChannelRouteCostVector {
  const ChannelRouteCostVector({
    required this.lengthMm,
    required this.materialCost,
    required this.laborCost,
    required this.transitionCount,
    required this.bendCount,
    required this.maintainabilityPenalty,
    required this.normativeRiskPenalty,
  });

  final double lengthMm;
  final double materialCost;
  final double laborCost;
  final int transitionCount;
  final int bendCount;
  final double maintainabilityPenalty;
  final double normativeRiskPenalty;

  ChannelRouteCostVector add(ChannelRouteEdge edge) => ChannelRouteCostVector(
        lengthMm: lengthMm + edge.lengthMm,
        materialCost: materialCost + edge.materialCost,
        laborCost: laborCost + edge.laborCost,
        transitionCount: transitionCount + edge.transitionCount,
        bendCount: bendCount + edge.bendCount,
        maintainabilityPenalty:
            maintainabilityPenalty + edge.maintainabilityPenalty,
        normativeRiskPenalty:
            normativeRiskPenalty + edge.normativeRiskPenalty,
      );

  double score(ChannelRouteCostWeights weights) =>
      lengthMm * weights.length +
      materialCost * weights.material +
      laborCost * weights.labor +
      transitionCount * weights.transitions +
      bendCount * weights.bends +
      maintainabilityPenalty * weights.maintainability +
      normativeRiskPenalty * weights.normativeRisk;

  static const zero = ChannelRouteCostVector(
    lengthMm: 0,
    materialCost: 0,
    laborCost: 0,
    transitionCount: 0,
    bendCount: 0,
    maintainabilityPenalty: 0,
    normativeRiskPenalty: 0,
  );
}

typedef ChannelRouteFeasibility = bool Function(
  ChannelRouteState from,
  ChannelRouteState to,
  ChannelRouteEdge edge,
);

final class ChannelRoutingGraph {
  const ChannelRoutingGraph({required this.states, required this.edges});

  final Map<String, ChannelRouteState> states;
  final List<ChannelRouteEdge> edges;
}

final class ChannelRouteSolution {
  const ChannelRouteSolution({
    required this.stateIds,
    required this.cost,
    required this.score,
  });

  final List<String> stateIds;
  final ChannelRouteCostVector cost;
  final double score;
}

abstract final class ChannelAwareRouteEngine {
  static ChannelRouteSolution? solve({
    required ChannelRoutingGraph graph,
    required String startStateId,
    required String endStateId,
    required ChannelRouteFeasibility isFeasible,
    ChannelRouteCostWeights weights = const ChannelRouteCostWeights(),
  }) {
    if (!graph.states.containsKey(startStateId) ||
        !graph.states.containsKey(endStateId)) {
      return null;
    }

    final adjacency = <String, List<ChannelRouteEdge>>{};
    for (final edge in graph.edges) {
      adjacency.putIfAbsent(edge.from, () => <ChannelRouteEdge>[]).add(edge);
    }

    final scores = <String, double>{startStateId: 0};
    final vectors = <String, ChannelRouteCostVector>{
      startStateId: ChannelRouteCostVector.zero,
    };
    final previous = <String, String>{};
    final queue = <({String id, double score})>[(id: startStateId, score: 0)];

    while (queue.isNotEmpty) {
      queue.sort((a, b) => a.score.compareTo(b.score));
      final current = queue.removeAt(0);
      if (current.score != scores[current.id]) continue;
      if (current.id == endStateId) break;

      final fromState = graph.states[current.id]!;
      for (final edge in adjacency[current.id] ?? const <ChannelRouteEdge>[]) {
        final toState = graph.states[edge.to];
        if (toState == null || !isFeasible(fromState, toState, edge)) continue;

        final nextVector = vectors[current.id]!.add(edge);
        final nextScore = nextVector.score(weights);
        if (nextScore < (scores[edge.to] ?? double.infinity)) {
          scores[edge.to] = nextScore;
          vectors[edge.to] = nextVector;
          previous[edge.to] = current.id;
          queue.add((id: edge.to, score: nextScore));
        }
      }
    }

    final totalScore = scores[endStateId];
    final totalVector = vectors[endStateId];
    if (totalScore == null || totalVector == null) return null;

    final path = <String>[endStateId];
    var cursor = endStateId;
    while (cursor != startStateId) {
      final parent = previous[cursor];
      if (parent == null) return null;
      path.add(parent);
      cursor = parent;
    }

    return ChannelRouteSolution(
      stateIds: List.unmodifiable(path.reversed),
      cost: totalVector,
      score: totalScore,
    );
  }
}
