import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/project/project_navigator_projection.dart';
import '../../application/project/project_structure_authoring.dart';
import '../../domain/project_identity.dart';
import 'project_structure_authoring_controls.dart';

typedef BuildingRequestResolver = Future<CreateBuildingRequest?> Function(
  BuildContext context,
);
typedef LevelRequestResolver = Future<CreateLevelRequest?> Function(
  BuildContext context,
  BuildingId buildingId,
);
typedef RoomRequestResolver = Future<CreateRoomRequest?> Function(
  BuildContext context,
  LevelId levelId,
);
typedef ProjectAuthoringCommittedCallback = FutureOr<void> Function(
  ProjectStructureAuthoringSession session,
  EntityId createdId,
);

/// Canonical P5C runtime surface for Project Navigator + breadcrumb + authoring.
///
/// This widget renders only [ProjectNavigatorProjection] and changes current
/// location only through [ProjectStructureAuthoringSession]. It deliberately
/// has no dependency on EditorBuildingWorkspace, level numbers as identity,
/// demo node ids, or the legacy SiteNavigationProjection hierarchy.
class CanonicalProjectNavigator extends StatefulWidget {
  const CanonicalProjectNavigator({
    required this.session,
    this.requestBuilding,
    this.requestLevel,
    this.requestRoom,
    this.onNavigationChanged,
    this.onAuthoringCommitted,
    this.onError,
    this.compact = false,
    super.key,
  });

  final ProjectStructureAuthoringSession session;
  final BuildingRequestResolver? requestBuilding;
  final LevelRequestResolver? requestLevel;
  final RoomRequestResolver? requestRoom;
  final ValueChanged<ProjectNavigationState>? onNavigationChanged;
  final ProjectAuthoringCommittedCallback? onAuthoringCommitted;
  final ValueChanged<Object>? onError;
  final bool compact;

  @override
  State<CanonicalProjectNavigator> createState() =>
      _CanonicalProjectNavigatorState();
}

class _CanonicalProjectNavigatorState extends State<CanonicalProjectNavigator> {
  final Set<EntityId> _expanded = <EntityId>{};
  final Map<EntityId, GlobalKey> _nodeKeys = <EntityId, GlobalKey>{};
  ProjectNavigatorProjection? _projection;
  EntityId? _lastRenderedLeafId;

  ProjectStructureAuthoringSession get session => widget.session;

  @override
  void didUpdateWidget(covariant CanonicalProjectNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      _expanded.clear();
      _nodeKeys.clear();
      _projection = null;
      _lastRenderedLeafId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final projection = _projectionForCurrentProject();
    final navigation = session.navigation;
    final requiredExpanded = projection.requiredExpandedAncestorIds(navigation);
    final currentPath = projection.currentPathIds(navigation);
    final availability = session.availability;
    final currentLeafId = projection.currentLeafId(navigation);

    if (_lastRenderedLeafId != currentLeafId) {
      _lastRenderedLeafId = currentLeafId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealCurrent());
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Text(
              'PROJECT',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          _breadcrumb(context, projection, navigation),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              key: const ValueKey('canonical-project-tree'),
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
              children: [
                _nodeTile(
                  context,
                  projection,
                  projection.root,
                  navigation,
                  requiredExpanded,
                  currentPath,
                  depth: 0,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: ProjectStructureAuthoringControls(
              compact: widget.compact,
              onAddBuilding:
                  availability.canAddBuilding && widget.requestBuilding != null
                  ? _addBuilding
                  : null,
              onAddLevel:
                  availability.canAddLevel && widget.requestLevel != null
                  ? _addLevel
                  : null,
              onAddRoom: availability.canAddRoom && widget.requestRoom != null
                  ? _addRoom
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  ProjectNavigatorProjection _projectionForCurrentProject() {
    final current = session.project;
    final cached = _projection;
    if (cached != null && cached.isCurrentFor(current)) {
      return cached;
    }

    final rebuilt = ProjectNavigatorProjection.build(current);
    _projection = rebuilt;
    _expanded.removeWhere((id) => rebuilt.node(id) == null);
    _nodeKeys.removeWhere((id, _) => rebuilt.node(id) == null);
    return rebuilt;
  }

  Widget _breadcrumb(
    BuildContext context,
    ProjectNavigatorProjection projection,
    ProjectNavigationState navigation,
  ) {
    final items = projection.breadcrumb(navigation);
    return SizedBox(
      height: 34,
      child: ListView.separated(
        key: const ValueKey('canonical-project-breadcrumb'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Icon(Icons.chevron_right, size: 14),
        itemBuilder: (context, index) {
          final item = items[index];
          final isLeaf = index == items.length - 1;
          return TextButton(
            key: ValueKey('breadcrumb-${item.kind.name}-${item.id.value}'),
            onPressed: item.kind == ProjectNavigatorNodeKind.site
                ? null
                : () => _activateId(projection, item.id),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: Text(
              item.label,
              style: TextStyle(
                fontWeight: isLeaf ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _nodeTile(
    BuildContext context,
    ProjectNavigatorProjection projection,
    ProjectNavigatorNode node,
    ProjectNavigationState navigation,
    Set<EntityId> requiredExpanded,
    Set<EntityId> currentPath, {
    required int depth,
  }) {
    final hasChildren = node.childIds.isNotEmpty;
    final expanded =
        node.kind == ProjectNavigatorNodeKind.site ||
        _expanded.contains(node.id) ||
        requiredExpanded.contains(node.id);
    final selected = projection.isSelected(node, navigation);
    final active =
        projection.isActiveBuilding(node, navigation) ||
        projection.isActiveLevel(node, navigation);
    final inCurrentPath = currentPath.contains(node.id);
    final nodeKey = _nodeKeys.putIfAbsent(node.id, GlobalKey.new);

    return Column(
      key: nodeKey,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 14.0),
          child: ListTile(
            key: ValueKey('project-node-${node.kind.name}-${node.id.value}'),
            dense: true,
            minTileHeight: 34,
            selected: selected,
            selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
            leading: hasChildren
                ? IconButton(
                    tooltip: expanded ? 'Collapse' : 'Expand',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      if (!_expanded.add(node.id)) {
                        _expanded.remove(node.id);
                      }
                    }),
                    icon: Icon(
                      expanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                    ),
                  )
                : Icon(_iconFor(node.kind), size: 17),
            title: Text(
              node.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: selected
                ? const Icon(Icons.check_circle_outline, size: 16)
                : active
                ? const Icon(Icons.my_location, size: 15)
                : inCurrentPath
                ? const Icon(Icons.more_horiz, size: 15)
                : null,
            onTap: node.kind == ProjectNavigatorNodeKind.site
                ? null
                : () => _activateNode(node),
          ),
        ),
        if (hasChildren && expanded)
          for (final childId in node.childIds)
            _nodeTile(
              context,
              projection,
              projection.node(childId)!,
              navigation,
              requiredExpanded,
              currentPath,
              depth: depth + 1,
            ),
      ],
    );
  }

  void _activateId(ProjectNavigatorProjection projection, EntityId id) {
    final node = projection.node(id);
    if (node == null) return;
    _activateNode(node);
  }

  void _activateNode(ProjectNavigatorNode node) {
    try {
      switch (node.kind) {
        case ProjectNavigatorNodeKind.site:
          return;
        case ProjectNavigatorNodeKind.building:
          session.activateBuilding(node.id as BuildingId);
        case ProjectNavigatorNodeKind.level:
          session.activateLevel(node.id as LevelId);
        case ProjectNavigatorNodeKind.structuralZone:
          session.selectZone(node.id as ZoneId);
        case ProjectNavigatorNodeKind.space:
          session.selectRoom(node.id as SpaceId);
      }
    } catch (error, stackTrace) {
      _reportOperationError(error, stackTrace);
      return;
    }

    setState(() {});
    _notifyNavigationChanged();
    _scheduleRevealCurrent();
  }

  Future<void> _addBuilding() async {
    final resolver = widget.requestBuilding;
    if (resolver == null) return;

    ProjectStructureAuthoringResult<BuildingId> result;
    try {
      final request = await resolver(context);
      if (!mounted || request == null) return;
      result = session.createBuilding(request);
    } catch (error, stackTrace) {
      _reportOperationError(error, stackTrace);
      return;
    }

    if (!mounted) return;
    setState(() {});
    _notifyNavigationChanged();
    await _notifyAuthoringCommitted(result.createdId);
    _scheduleRevealCurrent();
  }

  Future<void> _addLevel() async {
    final resolver = widget.requestLevel;
    final targetBuildingId = session.navigation.activeBuildingId;
    if (resolver == null || targetBuildingId == null) return;

    ProjectStructureAuthoringResult<LevelId> result;
    try {
      final request = await resolver(context, targetBuildingId);
      if (!mounted || request == null) return;
      result = session.createLevel(
        request,
        expectedActiveBuildingId: targetBuildingId,
      );
    } catch (error, stackTrace) {
      _reportOperationError(error, stackTrace);
      return;
    }

    if (!mounted) return;
    setState(() {});
    _notifyNavigationChanged();
    await _notifyAuthoringCommitted(result.createdId);
    _scheduleRevealCurrent();
  }

  Future<void> _addRoom() async {
    final resolver = widget.requestRoom;
    final targetLevelId = session.navigation.activeLevelId;
    if (resolver == null || targetLevelId == null) return;

    ProjectStructureAuthoringResult<SpaceId> result;
    try {
      final request = await resolver(context, targetLevelId);
      if (!mounted || request == null) return;
      result = session.createRoom(
        request,
        expectedActiveLevelId: targetLevelId,
      );
    } catch (error, stackTrace) {
      _reportOperationError(error, stackTrace);
      return;
    }

    if (!mounted) return;
    setState(() {});
    _notifyNavigationChanged();
    await _notifyAuthoringCommitted(result.createdId);
    _scheduleRevealCurrent();
  }

  void _notifyNavigationChanged() {
    final callback = widget.onNavigationChanged;
    if (callback == null) return;
    try {
      callback(session.navigation);
    } catch (error, stackTrace) {
      _reportCallbackError('onNavigationChanged', error, stackTrace);
    }
  }

  Future<void> _notifyAuthoringCommitted(EntityId createdId) async {
    final callback = widget.onAuthoringCommitted;
    if (callback == null) return;
    try {
      await callback(session, createdId);
    } catch (error, stackTrace) {
      _reportCallbackError('onAuthoringCommitted', error, stackTrace);
    }
  }

  void _reportOperationError(Object error, StackTrace stackTrace) {
    final callback = widget.onError;
    if (callback != null) {
      try {
        callback(error);
        return;
      } catch (callbackError, callbackStackTrace) {
        _reportCallbackError('onError', callbackError, callbackStackTrace);
      }
    }
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'ElecX canonical project navigator',
        context: ErrorDescription('while applying a navigator operation'),
      ),
    );
  }

  void _reportCallbackError(
    String callbackName,
    Object error,
    StackTrace stackTrace,
  ) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'ElecX canonical project navigator',
        context: ErrorDescription('while invoking $callbackName'),
      ),
    );
  }

  void _scheduleRevealCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealCurrent());
  }

  void _revealCurrent() {
    if (!mounted) return;
    final projection = _projectionForCurrentProject();
    final key = _nodeKeys[projection.currentLeafId(session.navigation)];
    final targetContext = key?.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  IconData _iconFor(ProjectNavigatorNodeKind kind) => switch (kind) {
    ProjectNavigatorNodeKind.site => Icons.location_on_outlined,
    ProjectNavigatorNodeKind.building => Icons.apartment_outlined,
    ProjectNavigatorNodeKind.level => Icons.layers_outlined,
    ProjectNavigatorNodeKind.structuralZone => Icons.home_work_outlined,
    ProjectNavigatorNodeKind.space => Icons.crop_square,
  };
}
