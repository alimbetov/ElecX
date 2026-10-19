import 'package:flutter/material.dart';

import '../../app/alien_cockpit_tokens.dart';
import '../../domain/component_taxonomy.dart';
import '../../domain/electrical_placement.dart';
import '../../domain/electrical_routing.dart';
import '../../domain/route_medium.dart';
import 'component_catalog_session.dart';
import 'editor_controller.dart';
import 'editor_p2_session.dart';
import 'route_selection_session.dart';

class EngineeringSelectionInspector extends StatelessWidget {
  const EngineeringSelectionInspector({
    required this.controller,
    super.key,
  });

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller.p2,
        controller.routeSelection,
        controller.componentCatalog,
      ]),
      builder: (context, _) {
        final route = controller.routeSelection.selectedRoute;
        final hostedRoute = controller.routeSelection.selectedHostedRoute;
        if (route != null) return _RouteInspector(route: route);
        if (hostedRoute != null) {
          return _HostedRouteInspector(
            routeId: hostedRoute.routeId,
            medium: hostedRoute.medium,
            lengthMm: hostedRoute.lengthMm,
            hostCount: hostedRoute.hosts.length,
            transitionCount: hostedRoute.transitions.length,
          );
        }
        final component = controller.p2.selectedComponent;
        if (component != null) {
          return _ComponentInspector(
            controller: controller,
            component: component,
          );
        }
        return const _EmptyInspector();
      },
    );
  }
}

class _ComponentInspector extends StatelessWidget {
  const _ComponentInspector({
    required this.controller,
    required this.component,
  });

  final EditorController controller;
  final ElectricalComponentPlacement component;

  @override
  Widget build(BuildContext context) {
    final entry = controller.componentCatalog.byId(component.componentTypeId);
    final taxonomy = entry == null ? null : ComponentTaxonomyResolver.resolve(entry);
    return _InspectorScaffold(
      title: component.label,
      subtitle: component.componentTypeId,
      status: 'SELECTED',
      children: [
        _section('IDENTITY', [
          _row('ID', component.id),
          if (taxonomy != null) _row('CATEGORY', taxonomy.category.name),
          if (taxonomy != null) _row('TYPE', taxonomy.subcategory.name),
          if (entry != null) _row('SYSTEM', entry.systemClass.name),
        ]),
        _section('POSITION', [
          _row('SURFACE', component.surface.type.name.toUpperCase()),
          _row('X', '${component.position.xMm} mm'),
          _row('Y / H', '${component.position.yMm} mm'),
          _row('ROTATION', '${component.rotationDegrees}°'),
        ]),
        _section('ELECTRICAL', [
          _row('VOLTAGE', '${component.voltageV} V'),
          _row('POWER', component.ratedPowerW == null ? '—' : '${component.ratedPowerW} W'),
          _row('PORTS', component.ports.isEmpty ? '—' : '${component.ports.length}'),
        ]),
      ],
    );
  }
}

class _RouteInspector extends StatelessWidget {
  const _RouteInspector({required this.route});

  final ElectricalCableRoute route;

  @override
  Widget build(BuildContext context) => _InspectorScaffold(
        title: route.id,
        subtitle: route.medium.displayName,
        status: 'ROUTE',
        children: [
          _section('CONNECTION', [
            _row('FROM', '${route.source.componentId}:${route.source.portId}'),
            _row('TO', '${route.target.componentId}:${route.target.portId}'),
          ]),
          _section('CABLE', [
            _row('MEDIUM', route.medium.displayName),
            _row('SPEC', route.cableType ?? 'NOT ASSIGNED'),
            _row('RESERVE', '${route.reservePercent}%'),
          ]),
          _section('ROUTE', [
            _row('GEOMETRY', '${route.geometricLengthMm.round()} mm'),
            _row('INSTALL', '${route.installationLengthMm.round()} mm'),
            _row('SEGMENTS', '${route.segments.length}'),
          ]),
          _section('ENGINEERING', [
            _row('CHANNEL', 'NOT ASSIGNED'),
            _row('FILL', 'NO EVIDENCE'),
            _row('VOLTAGE DROP', 'NO EVIDENCE'),
          ]),
        ],
      );
}

class _HostedRouteInspector extends StatelessWidget {
  const _HostedRouteInspector({
    required this.routeId,
    required this.medium,
    required this.lengthMm,
    required this.hostCount,
    required this.transitionCount,
  });

  final String routeId;
  final RouteMediumProfile medium;
  final double lengthMm;
  final int hostCount;
  final int transitionCount;

  @override
  Widget build(BuildContext context) => _InspectorScaffold(
        title: routeId,
        subtitle: medium.displayName,
        status: 'HOSTED ROUTE',
        children: [
          _section('ROUTE', [
            _row('MEDIUM', medium.displayName),
            _row('LENGTH', '${lengthMm.round()} mm'),
            _row('HOSTS', '$hostCount'),
            _row('TRANSITIONS', '$transitionCount'),
          ]),
          _section('ENGINEERING', [
            _row('CABLE', 'NOT ASSIGNED'),
            _row('CHANNEL', 'NOT ASSIGNED'),
            _row('VALIDATION', 'PENDING EVIDENCE'),
          ]),
        ],
      );
}

class _EmptyInspector extends StatelessWidget {
  const _EmptyInspector();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.radar_outlined,
                size: 30,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              Text(
                'SELECT ENGINEERING OBJECT',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      letterSpacing: 1.1,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                'Компонент или трасса откроет инженерные параметры здесь.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}

class _InspectorScaffold extends StatelessWidget {
  const _InspectorScaffold({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.children,
  });

  final String title;
  final String subtitle;
  final String status;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: AlienCockpitTokens.signalCyan.withValues(alpha: 0.55),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Icon(Icons.hub_outlined, color: scheme.primary, size: 21),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AlienCockpitTokens.signalCyan,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

Widget _section(String title, List<Widget> rows) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Builder(
        builder: (context) => DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                ),
                const SizedBox(height: 7),
                ...rows,
              ],
            ),
          ),
        ),
      ),
    );

Widget _row(String label, String value) => Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          children: [
            SizedBox(
              width: 94,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
