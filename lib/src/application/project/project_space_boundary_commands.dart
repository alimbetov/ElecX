import '../../domain/boundary_topology.dart';
import '../../domain/project_aggregate.dart';
import '../../domain/project_entity_stores_copy.dart';
import '../../domain/project_identity.dart';
import '../../domain/project_space_semantics.dart';
import 'project_mutation.dart';
import 'project_space_commands.dart';

/// Creates one canonical Space and its closed exterior boundary as one mutation.
///
/// The command deliberately composes [CreateSpaceCommand] so hierarchy/zone
/// validation stays identical to ordinary Space authoring, while topology is
/// published in the same candidate. This prevents a transient canonical Space
/// without geometry and guarantees one version increment / one undo record.
final class CreateSpaceWithBoundaryCommand implements ProjectCommand {
  CreateSpaceWithBoundaryCommand({
    required this.spaceId,
    required this.levelId,
    required this.name,
    required Iterable<BoundaryPointMm> boundaryPoints,
    required Iterable<BoundaryEdgeId> boundaryEdgeIds,
    this.structuralZoneId,
    this.type = ProjectSpaceType.room,
    this.usage = SpaceUsage.unknown,
  })  : boundaryPoints = List<BoundaryPointMm>.unmodifiable(boundaryPoints),
        boundaryEdgeIds = List<BoundaryEdgeId>.unmodifiable(boundaryEdgeIds) {
    if (this.boundaryPoints.length < 3) {
      throw ArgumentError.value(
        this.boundaryPoints.length,
        'boundaryPoints',
        'A room boundary requires at least three vertices.',
      );
    }
    if (this.boundaryEdgeIds.length != this.boundaryPoints.length) {
      throw ArgumentError(
        'Boundary edge identity count must match boundary vertex count.',
      );
    }
    if (this.boundaryEdgeIds.toSet().length != this.boundaryEdgeIds.length) {
      throw ArgumentError('Boundary edge identities must be unique.');
    }
  }

  final SpaceId spaceId;
  final LevelId levelId;
  final String name;
  final ZoneId? structuralZoneId;
  final ProjectSpaceType type;
  final SpaceUsage usage;
  final List<BoundaryPointMm> boundaryPoints;
  final List<BoundaryEdgeId> boundaryEdgeIds;

  @override
  String get commandType => 'project.space.create-with-boundary';

  @override
  ProjectCommandCandidate buildCandidate(ProjectAggregateRoot current) {
    final hierarchyCandidate = CreateSpaceCommand(
      spaceId: spaceId,
      levelId: levelId,
      name: name,
      structuralZoneId: structuralZoneId,
      type: type,
      usage: usage,
    ).buildCandidate(current);
    final hierarchyState = hierarchyCandidate.resolveState(current);

    final edges = <BoundaryEdgeId, ProjectBoundaryEdge>{};
    for (var index = 0; index < boundaryPoints.length; index++) {
      final edgeId = boundaryEdgeIds[index];
      edges[edgeId] = ProjectBoundaryEdge(
        id: edgeId,
        spaceId: spaceId,
        start: boundaryPoints[index],
        end: boundaryPoints[(index + 1) % boundaryPoints.length],
      );
    }
    final topology = SpaceBoundaryTopology(
      spaceId: spaceId,
      orderedEdgeIds: boundaryEdgeIds,
      edges: edges,
    );
    topology.validateOrThrow();

    final boundaries = Map<SpaceId, SpaceBoundaryTopology>.from(
      hierarchyState.stores.boundaries,
    )..[spaceId] = topology;

    return ProjectCommandCandidate.fromState(
      state: ProjectMutableState(
        engineeringMetadata: hierarchyState.engineeringMetadata,
        stores: hierarchyState.stores.copyWith(boundaries: boundaries),
      ),
      affectedEntityIds: <EntityId>{
        ...hierarchyCandidate.affectedEntityIds,
        ...boundaryEdgeIds,
      },
    );
  }
}
