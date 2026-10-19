import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/alien_cockpit_tokens.dart';
import '../../domain/surfaces.dart';
import 'component_catalog_session.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'engineering_placement_cursor_session.dart';
import 'route_selection_session.dart';

class EngineeringPlacementCursorHud extends StatelessWidget {
  const EngineeringPlacementCursorHud({
    required this.controller,
    super.key,
  });

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller,
        controller.p2,
        controller.placementCursor,
        controller.componentCatalog,
        controller.routeSelection,
      ]),
      builder: (context, _) {
        final componentTypeId = controller.placementCursor.activeComponentTypeId;
        final placement = componentTypeId == null || controller.activeSurface == null
            ? null
            : controller.placementCursor.ensure();
        final entry = placement == null
            ? null
            : controller.componentCatalog.byId(placement.componentTypeId);
        final scheme = Theme.of(context).colorScheme;
        final selectedRoute = controller.routeSelection.selectedRoute;
        final selectedHostedRoute = controller.routeSelection.selectedHostedRoute;
        final selectedRouteId = controller.routeSelection.selectedRouteId;
        final selectedComponents = controller.p2.selection.ids.length;
        final step = controller.selectedSpace?.grid.minorStepMm ?? 100;
        final activeSurface = controller.activeSurface;
        final command = _commandLabel(entry?.name);
        final commandColor = placement == null
            ? AlienCockpitTokens.signalCyan
            : placement.isValid
                ? AlienCockpitTokens.signalAqua
                : AlienCockpitTokens.signalFault;
        final medium = selectedRoute?.medium ?? selectedHostedRoute?.medium;

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Material(
            elevation: 0,
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.965),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: commandColor.withValues(alpha: 0.58)),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: commandColor.withValues(alpha: 0.08),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SignalDot(color: commandColor),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            command,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  letterSpacing: 0.75,
                                  fontWeight: FontWeight.w700,
                                  color: commandColor,
                                ),
                          ),
                        ),
                        if (controller.placementCursor.repeatPlacement) ...[
                          const SizedBox(width: 8),
                          const _MicroBadge(
                            icon: Icons.repeat,
                            label: 'REPEAT',
                            color: AlienCockpitTokens.signalViolet,
                          ),
                        ],
                      ],
                    ),
                    if (placement != null && entry != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        placement.coordinateLabel,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_surfaceLabel(placement.surface)}  ·  '
                        '${placement.snapLabel ?? placement.snapKind.name.toUpperCase()}  ·  '
                        '${entry.systemClass.name.toUpperCase()}  ·  GRID $step mm',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 0.2,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _NudgeButton(
                            icon: Icons.arrow_left,
                            tooltip: '← $step mm',
                            onPressed: () => controller.placementCursor.nudgeGrid(
                              dxSteps: -1,
                              dySteps: 0,
                            ),
                          ),
                          _NudgeButton(
                            icon: Icons.arrow_right,
                            tooltip: '→ $step mm',
                            onPressed: () => controller.placementCursor.nudgeGrid(
                              dxSteps: 1,
                              dySteps: 0,
                            ),
                          ),
                          _NudgeButton(
                            icon: Icons.arrow_upward,
                            tooltip: '↑ $step mm',
                            onPressed: () => controller.placementCursor.nudgeGrid(
                              dxSteps: 0,
                              dySteps: 1,
                            ),
                          ),
                          _NudgeButton(
                            icon: Icons.arrow_downward,
                            tooltip: '↓ $step mm',
                            onPressed: () => controller.placementCursor.nudgeGrid(
                              dxSteps: 0,
                              dySteps: -1,
                            ),
                          ),
                          const SizedBox(width: 5),
                          IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Установить (Enter)',
                            onPressed: placement.isValid
                                ? controller.placementCursor.confirm
                                : null,
                            icon: const Icon(Icons.check, size: 18),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Отмена (Esc)',
                            onPressed: controller.placementCursor.cancel,
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 7),
                    Container(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _MicroBadge(
                          icon: _surfaceIcon(activeSurface?.type),
                          label: activeSurface == null
                              ? controller.viewMode.name.toUpperCase()
                              : _surfaceLabel(activeSurface),
                          color: scheme.onSurfaceVariant,
                        ),
                        _MicroBadge(
                          icon: controller.snapEnabled
                              ? Icons.grid_4x4
                              : Icons.grid_off,
                          label: controller.snapEnabled ? 'SNAP ON' : 'SNAP OFF',
                          color: controller.snapEnabled
                              ? AlienCockpitTokens.signalAqua
                              : scheme.onSurfaceVariant,
                        ),
                        _MicroBadge(
                          icon: Icons.grid_on_outlined,
                          label: 'GRID $step',
                          color: scheme.onSurfaceVariant,
                        ),
                        if (selectedComponents > 0)
                          const _MicroBadge(
                            icon: Icons.select_all,
                            label: 'SELECTED',
                            color: AlienCockpitTokens.signalCyan,
                          ),
                        if (selectedComponents > 1)
                          _MicroBadge(
                            icon: Icons.numbers,
                            label: '$selectedComponents',
                            color: AlienCockpitTokens.signalCyan,
                          ),
                        if (selectedRouteId != null)
                          _MicroBadge(
                            icon: Icons.alt_route,
                            label: 'ROUTE $selectedRouteId',
                            color: AlienCockpitTokens.signalCyan,
                          ),
                        if (medium != null)
                          _MicroBadge(
                            icon: Icons.cable_outlined,
                            label: 'MEDIUM ${medium.displayName.toUpperCase()}',
                            color: AlienCockpitTokens.signalViolet,
                          ),
                        if (selectedRouteId != null)
                          const _MicroBadge(
                            icon: Icons.account_tree_outlined,
                            label: 'CHANNEL —',
                            color: AlienCockpitTokens.coolMuted,
                          ),
                        if (placement != null)
                          _MicroBadge(
                            icon: placement.isValid
                                ? Icons.verified_outlined
                                : Icons.error_outline,
                            label: placement.isValid ? 'VALID' : 'INVALID',
                            color: placement.isValid
                                ? AlienCockpitTokens.signalAqua
                                : AlienCockpitTokens.signalFault,
                          )
                        else if (selectedRouteId != null)
                          const _MicroBadge(
                            icon: Icons.help_outline,
                            label: 'VALIDATION NO EVIDENCE',
                            color: AlienCockpitTokens.signalWarning,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _commandLabel(String? componentName) {
    if (componentName != null) return 'PLACE // ${componentName.toUpperCase()}';
    if (controller.routeSelection.selectedRouteId != null) {
      return 'ROUTE // SELECTED';
    }
    return switch (controller.tool) {
      EditorTool.select => 'SELECT // READY',
      EditorTool.roomRectangle => 'DRAW // ROOM',
      EditorTool.guide => 'GUIDE // AUTHORING',
      EditorTool.cableRoute => 'ROUTE // MANUAL',
    };
  }
}

class _SignalDot extends StatelessWidget {
  const _SignalDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.6),
              blurRadius: 7,
              spreadRadius: 1,
            ),
          ],
        ),
      );
}

class _MicroBadge extends StatelessWidget {
  const _MicroBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontSize: 10,
                      letterSpacing: 0.35,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      );
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      );
}

String _surfaceLabel(RoomSurfaceRef surface) => switch (surface.type) {
      SurfacePlaneType.wall => 'WALL ${(surface.wallIndex ?? 0) + 1}',
      SurfacePlaneType.floor => 'FLOOR',
      SurfacePlaneType.ceiling => 'CEILING',
    };

IconData _surfaceIcon(SurfacePlaneType? type) => switch (type) {
      SurfacePlaneType.wall => Icons.view_sidebar_outlined,
      SurfacePlaneType.floor => Icons.grid_4x4,
      SurfacePlaneType.ceiling => Icons.vertical_align_top,
      null => Icons.space_dashboard_outlined,
    };
