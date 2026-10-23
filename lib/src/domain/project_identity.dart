import 'dart:math';

/// Base value object for externally stable ElecX entity identities.
///
/// The wrapper intentionally accepts existing non-empty legacy identifiers so
/// persisted projects can be migrated without changing identity. New identities
/// are allocated by [EntityIdFactory] and must not be derived from display
/// numbers, list positions, local database row ids or platform state.
abstract base class EntityId {
  EntityId(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'value', 'Entity id must be non-empty.');
    }
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is EntityId &&
      other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value;
}

final class ProjectId extends EntityId {
  ProjectId(super.value);
}

final class SiteId extends EntityId {
  SiteId(super.value);
}

final class BuildingId extends EntityId {
  BuildingId(super.value);
}

final class LevelId extends EntityId {
  LevelId(super.value);
}

final class ZoneId extends EntityId {
  ZoneId(super.value);
}

final class SpaceId extends EntityId {
  SpaceId(super.value);
}

final class OpeningId extends EntityId {
  OpeningId(super.value);
}

/// Stable identity for one symmetric semantic relationship between two spaces.
final class SpaceAdjacencyId extends EntityId {
  SpaceAdjacencyId(super.value);
}

/// Stable identity for one cross-discipline overlay classification.
final class OverlayClassificationId extends EntityId {
  OverlayClassificationId(super.value);
}

/// Stable identity for one logical polygon boundary edge.
///
/// This is distinct from a transient boundary-array index. The concrete wall
/// lineage/migration model lands in P7, but introducing the type now prevents
/// new APIs from cementing `wallIndex` as a persistent identity.
final class BoundaryEdgeId extends EntityId {
  BoundaryEdgeId(super.value);
}

/// Stable compile-time identity for one physical boundary penetration.
///
/// The representation intentionally remains the exact persisted string so
/// legacy project JSON can migrate losslessly without a schema rewrite. New
/// authoring APIs use this type instead of raw String, preventing accidental
/// penetration identity allocation from coordinates, list indexes or display
/// values. The unified identity is valid for both wall and slab penetrations;
/// slab ownership remains proven separately by [SlabId].
extension type BoundaryPenetrationId(String value) implements String {}

/// Stable identity for one physical horizontal building slab.
///
/// A slab is not a floor/ceiling surface ordinal and is not owned by a room.
/// It is a building-level physical boundary that can separate two canonical
/// levels and can later host penetrations and vertical routing evidence.
final class SlabId extends EntityId {
  SlabId(super.value);
}

final class VerticalCoreId extends EntityId {
  VerticalCoreId(super.value);
}

final class ServiceEntryId extends EntityId {
  ServiceEntryId(super.value);
}

final class ComponentId extends EntityId {
  ComponentId(super.value);
}

final class PortId extends EntityId {
  PortId(super.value);
}

final class CircuitId extends EntityId {
  CircuitId(super.value);
}

final class RouteId extends EntityId {
  RouteId(super.value);
}

/// Stable identity for one durable intermediate point of a physical route.
///
/// Segment and point indexes are transient editing coordinates and must never be
/// used as persistence identity. Legacy routes may temporarily have no anchor
/// identities; P7A-5 persistence fails closed for those interior points until a
/// migration assigns explicit [RouteAnchorId] values.
final class RouteAnchorId extends EntityId {
  RouteAnchorId(super.value);
}

final class GenerationId extends EntityId {
  GenerationId(super.value);
}

final class TemplateId extends EntityId {
  TemplateId(super.value);
}

final class TypicalFloorDefinitionId extends EntityId {
  TypicalFloorDefinitionId(super.value);
}

final class EngineeringConnectionId extends EntityId {
  EngineeringConnectionId(super.value);
}

/// Allocates stable persistent identities at the application/domain boundary.
abstract interface class EntityIdFactory {
  ProjectId newProjectId();
  SiteId newSiteId();
  BuildingId newBuildingId();
  LevelId newLevelId();
  ZoneId newZoneId();
  SpaceId newSpaceId();
  OpeningId newOpeningId();
  SpaceAdjacencyId newSpaceAdjacencyId();
  OverlayClassificationId newOverlayClassificationId();
  BoundaryEdgeId newBoundaryEdgeId();
  BoundaryPenetrationId newBoundaryPenetrationId();
  SlabId newSlabId();
  VerticalCoreId newVerticalCoreId();
  ServiceEntryId newServiceEntryId();
  ComponentId newComponentId();
  PortId newPortId();
  CircuitId newCircuitId();
  RouteId newRouteId();
  RouteAnchorId newRouteAnchorId();
  GenerationId newGenerationId();
  TemplateId newTemplateId();
  TypicalFloorDefinitionId newTypicalFloorDefinitionId();
  EngineeringConnectionId newEngineeringConnectionId();
}

/// Native-safe default identity allocator using RFC 4122 variant UUID v4.
final class SecureRandomEntityIdFactory implements EntityIdFactory {
  SecureRandomEntityIdFactory({Random? random})
      : _random = random ?? Random.secure();

  final Random _random;

  @override
  ProjectId newProjectId() => ProjectId(_nextUuidV4());

  @override
  SiteId newSiteId() => SiteId(_nextUuidV4());

  @override
  BuildingId newBuildingId() => BuildingId(_nextUuidV4());

  @override
  LevelId newLevelId() => LevelId(_nextUuidV4());

  @override
  ZoneId newZoneId() => ZoneId(_nextUuidV4());

  @override
  SpaceId newSpaceId() => SpaceId(_nextUuidV4());

  @override
  OpeningId newOpeningId() => OpeningId(_nextUuidV4());

  @override
  SpaceAdjacencyId newSpaceAdjacencyId() => SpaceAdjacencyId(_nextUuidV4());

  @override
  OverlayClassificationId newOverlayClassificationId() =>
      OverlayClassificationId(_nextUuidV4());

  @override
  BoundaryEdgeId newBoundaryEdgeId() => BoundaryEdgeId(_nextUuidV4());

  @override
  BoundaryPenetrationId newBoundaryPenetrationId() =>
      BoundaryPenetrationId(_nextUuidV4());

  @override
  SlabId newSlabId() => SlabId(_nextUuidV4());

  @override
  VerticalCoreId newVerticalCoreId() => VerticalCoreId(_nextUuidV4());

  @override
  ServiceEntryId newServiceEntryId() => ServiceEntryId(_nextUuidV4());

  @override
  ComponentId newComponentId() => ComponentId(_nextUuidV4());

  @override
  PortId newPortId() => PortId(_nextUuidV4());

  @override
  CircuitId newCircuitId() => CircuitId(_nextUuidV4());

  @override
  RouteId newRouteId() => RouteId(_nextUuidV4());

  @override
  RouteAnchorId newRouteAnchorId() => RouteAnchorId(_nextUuidV4());

  @override
  GenerationId newGenerationId() => GenerationId(_nextUuidV4());

  @override
  TemplateId newTemplateId() => TemplateId(_nextUuidV4());

  @override
  TypicalFloorDefinitionId newTypicalFloorDefinitionId() =>
      TypicalFloorDefinitionId(_nextUuidV4());

  @override
  EngineeringConnectionId newEngineeringConnectionId() =>
      EngineeringConnectionId(_nextUuidV4());

  String _nextUuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}
