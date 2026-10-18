import 'package:flutter/material.dart';

import 'editor_building_workspace.dart';
import 'site_map_interaction.dart';
import 'site_navigation_model.dart';

enum LevelNavigatorFilter { all, residential, basement }

class UnifiedSiteNavigator extends StatefulWidget {
  const UnifiedSiteNavigator({
    required this.workspace,
    this.interaction,
    this.onOpenSiteMap,
    this.compact = false,
    super.key,
  });

  final EditorBuildingWorkspace workspace;
  final SiteMapInteractionController? interaction;
  final VoidCallback? onOpenSiteMap;
  final bool compact;

  @override
  State<UnifiedSiteNavigator> createState() => _UnifiedSiteNavigatorState();
}

class _UnifiedSiteNavigatorState extends State<UnifiedSiteNavigator> {
  final TextEditingController _search = TextEditingController();
  final Set<String> _expanded = {'site', 'building:building-a'};
  LevelNavigatorFilter _filter = LevelNavigatorFilter.all;

  EditorBuildingWorkspace get workspace => widget.workspace;

  @override
  void initState() {
    super.initState();
    workspace.addListener(_refresh);
    widget.interaction?.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant UnifiedSiteNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace != workspace) {
      oldWidget.workspace.removeListener(_refresh);
      workspace.addListener(_refresh);
    }
    if (oldWidget.interaction != widget.interaction) {
      oldWidget.interaction?.removeListener(_refresh);
      widget.interaction?.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    workspace.removeListener(_refresh);
    widget.interaction?.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  NavigatorNode get _root => SiteNavigationProjection.apartmentTower(
        siteName: workspace.site.site.name,
        building: workspace.building,
        outdoorZones: workspace.site.outdoorZones,
      );

  @override
  Widget build(BuildContext context) {
    final root = _root;
    final query = _search.text.trim().toLowerCase();
    final visible = _applyFilter(root, query);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          _header(context),
          _breadcrumb(context, root),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 19),
                hintText: 'Этаж, квартира, комната…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          _levelFilter(context),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 24),
              children: [
                for (final child in visible.children)
                  _nodeTile(context, child, depth: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 6),
        child: Row(
          children: [
            const Icon(Icons.account_tree_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'НАВИГАТОР',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            IconButton(
              tooltip: 'Карта площадки',
              visualDensity: VisualDensity.compact,
              onPressed: widget.onOpenSiteMap,
              icon: const Icon(Icons.map_outlined),
            ),
            IconButton(
              tooltip: 'Предыдущий уровень',
              visualDensity: VisualDensity.compact,
              onPressed: workspace.context == EditorWorkspaceContext.buildingLevel
                  ? workspace.previousLevel
                  : null,
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton(
              tooltip: 'Следующий уровень',
              visualDensity: VisualDensity.compact,
              onPressed: workspace.context == EditorWorkspaceContext.buildingLevel
                  ? workspace.nextLevel
                  : null,
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
          ],
        ),
      );

  Widget _breadcrumb(BuildContext context, NavigatorNode root) {
    final activeNodeId = _activeNodeId();
    final path = activeNodeId == null ? <NavigatorNode>[root] : root.pathTo(activeNodeId);
    final effective = path.isEmpty ? <NavigatorNode>[root] : path;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: effective.length,
        separatorBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Icon(Icons.chevron_right, size: 15),
        ),
        itemBuilder: (context, index) {
          final node = effective[index];
          return Center(
            child: Text(
              node.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: index == effective.length - 1
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
            ),
          );
        },
      ),
    );
  }

  Widget _levelFilter(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: SegmentedButton<LevelNavigatorFilter>(
          segments: const [
            ButtonSegment(
              value: LevelNavigatorFilter.all,
              label: Text('Все'),
              icon: Icon(Icons.layers_outlined, size: 16),
            ),
            ButtonSegment(
              value: LevelNavigatorFilter.residential,
              label: Text('Этажи'),
              icon: Icon(Icons.apartment_outlined, size: 16),
            ),
            ButtonSegment(
              value: LevelNavigatorFilter.basement,
              label: Text('B'),
              icon: Icon(Icons.foundation_outlined, size: 16),
            ),
          ],
          selected: {_filter},
          showSelectedIcon: false,
          onSelectionChanged: (value) => setState(() => _filter = value.first),
          style: ButtonStyle(
            visualDensity: widget.compact ? VisualDensity.compact : null,
          ),
        ),
      );

  Widget _nodeTile(
    BuildContext context,
    NavigatorNode node, {
    required int depth,
  }) {
    final hasChildren = node.children.isNotEmpty;
    final expanded = _expanded.contains(node.id) || _forceExpanded(node);
    final selected = _isSelected(node) || widget.interaction?.selectedNodeId == node.id;
    final hovered = widget.interaction?.hoveredNodeId == node.id;
    final indent = 8.0 + depth * 14;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: MouseRegion(
            onEnter: (_) => widget.interaction?.hover(node.id),
            onExit: (_) {
              if (widget.interaction?.hoveredNodeId == node.id) {
                widget.interaction?.hover(null);
              }
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: hovered
                    ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1)
                    : null,
              ),
              child: ListTile(
                dense: true,
                minLeadingWidth: 24,
                horizontalTitleGap: 6,
                selected: selected,
                selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                leading: hasChildren
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                        onPressed: () => setState(() {
                          if (!_expanded.add(node.id)) _expanded.remove(node.id);
                        }),
                        icon: Icon(
                          expanded ? Icons.expand_more : Icons.chevron_right,
                          size: 18,
                        ),
                      )
                    : Icon(_iconFor(node.kind), size: 18),
                title: Text(node.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: node.subtitle == null
                    ? null
                    : Text(
                        node.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                trailing: node.kind == NavigatorNodeKind.level && selected
                    ? const Icon(Icons.my_location, size: 16)
                    : null,
                onTap: () => _activate(node),
              ),
            ),
          ),
        ),
        if (hasChildren && expanded)
          for (final child in node.children)
            _nodeTile(context, child, depth: depth + 1),
      ],
    );
  }

  void _activate(NavigatorNode node) {
    widget.interaction?.select(node.id);
    switch (node.kind) {
      case NavigatorNodeKind.outdoorZone:
        final target = node.targetId;
        if (target != null) workspace.selectOutdoorZone(target);
      case NavigatorNodeKind.level:
        final level = node.levelNumber;
        if (level != null) workspace.selectLevel(level);
      case NavigatorNodeKind.zone:
        workspace.selectZone(node.targetId);
      case NavigatorNodeKind.room:
        final target = node.targetId;
        if (target != null) workspace.editor.selectSpace(target);
      case NavigatorNodeKind.site:
        widget.onOpenSiteMap?.call();
      case NavigatorNodeKind.lot:
      case NavigatorNodeKind.building:
      case NavigatorNodeKind.surface:
      case NavigatorNodeKind.network:
        if (node.children.isNotEmpty) {
          setState(() {
            if (!_expanded.add(node.id)) _expanded.remove(node.id);
          });
        }
    }
  }

  NavigatorNode _applyFilter(NavigatorNode root, String query) {
    NavigatorNode? filterNode(NavigatorNode node) {
      if (node.kind == NavigatorNodeKind.level) {
        final number = node.levelNumber;
        if (_filter == LevelNavigatorFilter.residential && (number ?? 0) <= 0) {
          return null;
        }
        if (_filter == LevelNavigatorFilter.basement && (number ?? 0) >= 0) {
          return null;
        }
      }
      final children = [
        for (final child in node.children)
          if (filterNode(child) case final filtered?) filtered,
      ];
      final ownMatch = query.isEmpty ||
          node.label.toLowerCase().contains(query) ||
          (node.subtitle?.toLowerCase().contains(query) ?? false);
      if (!ownMatch && children.isEmpty && query.isNotEmpty) return null;
      return NavigatorNode(
        id: node.id,
        label: node.label,
        kind: node.kind,
        subtitle: node.subtitle,
        children: children,
        levelNumber: node.levelNumber,
        targetId: node.targetId,
      );
    }

    return filterNode(root) ?? root;
  }

  bool _forceExpanded(NavigatorNode node) => _search.text.trim().isNotEmpty;

  String? _activeNodeId() {
    if (workspace.context == EditorWorkspaceContext.siteOutdoor) {
      final id = workspace.activeOutdoorZoneId;
      return id == null ? null : 'outdoor:$id';
    }
    final roomId = workspace.editor.selectedSpaceId;
    if (roomId != null) return 'room:$roomId';
    final zoneId = workspace.selectedZoneId;
    if (zoneId != null) {
      return 'level:${workspace.activeLevelNumber}:zone:$zoneId';
    }
    return 'level:${workspace.activeLevelNumber}';
  }

  bool _isSelected(NavigatorNode node) {
    if (node.kind == NavigatorNodeKind.outdoorZone) {
      return workspace.context == EditorWorkspaceContext.siteOutdoor &&
          node.targetId == workspace.activeOutdoorZoneId;
    }
    if (node.kind == NavigatorNodeKind.level) {
      return workspace.context == EditorWorkspaceContext.buildingLevel &&
          node.levelNumber == workspace.activeLevelNumber;
    }
    if (node.kind == NavigatorNodeKind.zone) {
      return node.targetId == workspace.selectedZoneId;
    }
    if (node.kind == NavigatorNodeKind.room) {
      return node.targetId == workspace.editor.selectedSpaceId;
    }
    return false;
  }

  IconData _iconFor(NavigatorNodeKind kind) => switch (kind) {
        NavigatorNodeKind.site => Icons.location_on_outlined,
        NavigatorNodeKind.outdoorZone => Icons.park_outlined,
        NavigatorNodeKind.lot => Icons.fence_outlined,
        NavigatorNodeKind.building => Icons.apartment_outlined,
        NavigatorNodeKind.level => Icons.layers_outlined,
        NavigatorNodeKind.zone => Icons.home_work_outlined,
        NavigatorNodeKind.room => Icons.crop_square,
        NavigatorNodeKind.surface => Icons.crop_landscape,
        NavigatorNodeKind.network => Icons.hub_outlined,
      };
}
