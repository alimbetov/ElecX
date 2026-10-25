import 'electrical_placement.dart';
import 'project_identity.dart';
import 'surfaces.dart';

enum ComponentHostKind {
  roomSurface,
  slab,
  verticalCore,
  site,
  exterior,
}

/// Physical host reference for an engineering component.
sealed class ComponentHostRef {
  const ComponentHostRef();

  ComponentHostKind get kind;
  String get stableKey;
}

final class RoomSurfaceComponentHost extends ComponentHostRef {
  const RoomSurfaceComponentHost(this.surface);

  final RoomSurfaceRef surface;

  @override
  ComponentHostKind get kind => ComponentHostKind.roomSurface;

  @override
  String get stableKey => 'surface:${surface.id}';

  /// Legacy wall-index hosts remain readable during migration but must not be
  /// used as durable identity in newly persisted canonical placements.
  bool get isCanonical => !surface.isLegacyWall;
}

final class SlabComponentHost extends ComponentHostRef {
  const SlabComponentHost(this.slabId);

  final SlabId slabId;

  @override
  ComponentHostKind get kind => ComponentHostKind.slab;

  @override
  String get stableKey => 'slab:${slabId.value}';
}

final class VerticalCoreComponentHost extends ComponentHostRef {
  const VerticalCoreComponentHost(this.verticalCoreId);

  final VerticalCoreId verticalCoreId;

  @override
  ComponentHostKind get kind => ComponentHostKind.verticalCore;

  @override
  String get stableKey => 'vertical-core:${verticalCoreId.value}';
}

final class SiteComponentHost extends ComponentHostRef {
  const SiteComponentHost(this.siteId);

  final SiteId siteId;

  @override
  ComponentHostKind get kind => ComponentHostKind.site;

  @override
  String get stableKey => 'site:${siteId.value}';
}

final class ExteriorComponentHost extends ComponentHostRef {
  ExteriorComponentHost({required this.buildingId, required String faceId})
      : faceId = _nonEmpty(faceId, 'faceId');

  final BuildingId buildingId;
  final String faceId;

  @override
  ComponentHostKind get kind => ComponentHostKind.exterior;

  @override
  String get stableKey => 'exterior:${buildingId.value}:$faceId';
}

/// Coordinates in the local frame of a physical host.
///
/// U/V are coordinates on the host plane. [normalOffsetMm] is signed distance
/// from the host plane, allowing flush, surface-mounted and offset equipment
/// without leaking world/editor coordinates into engineering identity.
final class HostLocalPointMm {
  const HostLocalPointMm({
    required this.uMm,
    required this.vMm,
    this.normalOffsetMm = 0,
  });

  final int uMm;
  final int vMm;
  final int normalOffsetMm;
}

final class ComponentOrientation {
  const ComponentOrientation({
    this.yawDegrees = 0,
    this.pitchDegrees = 0,
    this.rollDegrees = 0,
  });

  final int yawDegrees;
  final int pitchDegrees;
  final int rollDegrees;
}

final class ComponentClearanceMm {
  ComponentClearanceMm({
    this.front = 0,
    this.back = 0,
    this.left = 0,
    this.right = 0,
    this.top = 0,
    this.bottom = 0,
  }) {
    if ([front, back, left, right, top, bottom].any((value) => value < 0)) {
      throw ArgumentError('Component clearances must be non-negative.');
    }
  }

  final int front;
  final int back;
  final int left;
  final int right;
  final int top;
  final int bottom;
}

enum ComponentCollisionPolicy { enforce, advisory, ignore }

/// Canonical WHERE contract for a logical engineering component.
final class ComponentPlacement {
  ComponentPlacement({
    required this.componentId,
    required this.host,
    required this.position,
    this.orientation = const ComponentOrientation(),
    ComponentClearanceMm? clearance,
    this.collisionPolicy = ComponentCollisionPolicy.enforce,
  }) : clearance = clearance ?? ComponentClearanceMm();

  final ComponentId componentId;
  final ComponentHostRef host;
  final HostLocalPointMm position;
  final ComponentOrientation orientation;
  final ComponentClearanceMm clearance;
  final ComponentCollisionPolicy collisionPolicy;
}

/// Transitional projection from the electrical editor placement to the
/// canonical physical placement model. Durable component identity is retained.
extension ElectricalPlacementCanonicalAdapter on ElectricalComponentPlacement {
  ComponentPlacement toCanonicalComponentPlacement() => ComponentPlacement(
        componentId: ComponentId(id),
        host: RoomSurfaceComponentHost(surface),
        position: HostLocalPointMm(
          uMm: position.xMm,
          vMm: position.yMm,
        ),
        orientation: ComponentOrientation(yawDegrees: rotationDegrees),
      );
}

String _nonEmpty(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must be non-empty.');
  }
  return value;
}
