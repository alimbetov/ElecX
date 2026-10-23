import '../../domain/project_identity.dart';
import '../../domain/surfaces.dart';
import '../../domain/vertical_core_route_continuation_plan.dart';
import '../../domain/vertical_core_slab_crossing_resolver.dart';
import 'canonical_slab_cable_handoff_authoring.dart';
import 'editor_controller.dart';

enum CanonicalVerticalCoreContinuationIssueCode {
  missingRoomHeight,
  routeIdentityMismatch,
  slabIdentityMismatch,
  coreIdentityMismatch,
  hiddenLegSurfaceTransitionFailed,
  alreadyComplete,
}

final class CanonicalVerticalCoreContinuationException implements Exception {
  const CanonicalVerticalCoreContinuationException({
    required this.code,
    required this.message,
    this.entityId,
  });

  final CanonicalVerticalCoreContinuationIssueCode code;
  final String message;
  final EntityId? entityId;

  @override
  String toString() => '${code.name}: $message';
}

/// Stateful production UX coordinator for one multi-level route continuation.
///
/// Each hop reuses the rollback-safe canonical slab handoff. Between adjacent
/// slab crossings the editor switches from the arrival horizontal surface to
/// the departure horizontal surface inside the same target room. The editor's
/// existing cable-draft lifecycle materializes that switch as a one-point
/// segment; the matching VerticalCore route leg is attached later by canonical
/// route assembly and owns the hidden Z-length.
final class CanonicalVerticalCoreCableContinuationSession {
  CanonicalVerticalCoreCableContinuationSession({
    required this.routeId,
    required this.plan,
    required this.roomHeightMmByLevel,
    required this.handoff,
    required this.editor,
    this.verticalToleranceMm = 2,
  }) {
    if (routeId.trim().isEmpty) {
      throw ArgumentError('routeId must be non-empty.');
    }
    for (final hop in plan.hops) {
      if (hop.verticalCoreId != plan.verticalCoreId) {
        throw ArgumentError(
          'Every continuation hop must belong to ${plan.verticalCoreId}.',
        );
      }
    }
  }

  final String routeId;
  final VerticalCoreRouteContinuationPlan plan;
  final Map<LevelId, int> roomHeightMmByLevel;
  final CanonicalSlabCableHandoffAuthoring handoff;
  final EditorController editor;
  final int verticalToleranceMm;

  int _nextHopIndex = 0;
  final List<CanonicalSlabCableHandoffResult> _results = [];

  bool get isComplete => _nextHopIndex >= plan.hops.length;
  int get completedHopCount => _nextHopIndex;
  int get remainingHopCount => plan.hops.length - _nextHopIndex;
  VerticalCoreRouteContinuationHop? get nextHop =>
      isComplete ? null : plan.hops[_nextHopIndex];
  List<CanonicalSlabCableHandoffResult> get results =>
      List.unmodifiable(_results);

  CanonicalSlabCableHandoffResult continueNext() {
    if (isComplete) {
      throw const CanonicalVerticalCoreContinuationException(
        code: CanonicalVerticalCoreContinuationIssueCode.alreadyComplete,
        message: 'The VerticalCore route continuation is already complete.',
      );
    }
    final hop = plan.hops[_nextHopIndex];
    final fromHeight = roomHeightMmByLevel[hop.fromLevelId];
    final toHeight = roomHeightMmByLevel[hop.toLevelId];
    if (fromHeight == null || toHeight == null) {
      throw CanonicalVerticalCoreContinuationException(
        code: CanonicalVerticalCoreContinuationIssueCode.missingRoomHeight,
        entityId: fromHeight == null ? hop.fromLevelId : hop.toLevelId,
        message:
            'Both source and target room heights are required for '
            'VerticalCore continuation ${hop.fromLevelId} -> ${hop.toLevelId}.',
      );
    }

    final result = handoff.continueAcrossSlab(
      routeId: routeId,
      toSpaceId: hop.toSpaceId,
      fromRoomHeightMm: fromHeight,
      toRoomHeightMm: toHeight,
      verticalCoreId: hop.verticalCoreId,
      expectedSlabId: hop.slabId,
      verticalToleranceMm: verticalToleranceMm,
    );
    try {
      if (result.routeId != routeId) {
        throw CanonicalVerticalCoreContinuationException(
          code:
              CanonicalVerticalCoreContinuationIssueCode.routeIdentityMismatch,
          message:
              'Slab handoff changed route identity from $routeId to '
              '${result.routeId}.',
        );
      }
      if (result.slabId != hop.slabId) {
        throw CanonicalVerticalCoreContinuationException(
          code: CanonicalVerticalCoreContinuationIssueCode.slabIdentityMismatch,
          entityId: result.slabId,
          message:
              'Slab handoff returned ${result.slabId}, expected '
              '${hop.slabId}.',
        );
      }
      if (result.verticalCoreId != plan.verticalCoreId) {
        throw CanonicalVerticalCoreContinuationException(
          code: CanonicalVerticalCoreContinuationIssueCode.coreIdentityMismatch,
          entityId: result.verticalCoreId,
          message:
              'Slab handoff lost VerticalCore identity '
              '${plan.verticalCoreId}.',
        );
      }

      // Commit the hop only after the target departure surface has been
      // materialized. A failed materialization compensates the successful
      // slab cutover so the same hop can be retried from the source context.
      if (!isComplete) {
        _materializeHiddenLegDepartureSurface(hop);
      }
    } catch (error, stackTrace) {
      handoff.rollbackLastNavigation();
      Error.throwWithStackTrace(error, stackTrace);
    }

    _results.add(result);
    _nextHopIndex++;
    return result;
  }

  void _materializeHiddenLegDepartureSurface(
    VerticalCoreRouteContinuationHop completedHop,
  ) {
    final beforeCount = editor.routeSegments.length;
    final arrival = editor.activeSurface;
    if (arrival == null || editor.routeSegments.isEmpty) {
      throw const CanonicalVerticalCoreContinuationException(
        code: CanonicalVerticalCoreContinuationIssueCode
            .hiddenLegSurfaceTransitionFailed,
        message: 'Slab handoff did not restore a target route draft surface.',
      );
    }

    switch (completedHop.direction) {
      case VerticalCoreCrossingDirection.up:
        if (arrival.type != SurfacePlaneType.floor) {
          throw const CanonicalVerticalCoreContinuationException(
            code: CanonicalVerticalCoreContinuationIssueCode
                .hiddenLegSurfaceTransitionFailed,
            message: 'Upward slab handoff must arrive on a floor surface.',
          );
        }
        editor.showCeiling();
      case VerticalCoreCrossingDirection.down:
        if (arrival.type != SurfacePlaneType.ceiling) {
          throw const CanonicalVerticalCoreContinuationException(
            code: CanonicalVerticalCoreContinuationIssueCode
                .hiddenLegSurfaceTransitionFailed,
            message: 'Downward slab handoff must arrive on a ceiling surface.',
          );
        }
        editor.showFloor();
    }

    final departure = editor.activeSurface;
    final expectedType =
        completedHop.direction == VerticalCoreCrossingDirection.up
        ? SurfacePlaneType.ceiling
        : SurfacePlaneType.floor;
    if (departure == null ||
        departure.spaceId != arrival.spaceId ||
        departure.type != expectedType ||
        editor.routeSegments.length != beforeCount + 1 ||
        editor.routeSegments.last.surface != departure ||
        editor.routeSegments.last.points.length != 1) {
      throw const CanonicalVerticalCoreContinuationException(
        code: CanonicalVerticalCoreContinuationIssueCode
            .hiddenLegSurfaceTransitionFailed,
        message:
            'Editor could not materialize the hidden VerticalCore '
            'departure surface while preserving the live cable draft.',
      );
    }
  }
}
