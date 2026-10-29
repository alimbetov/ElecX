import 'package:flutter/material.dart';

import '../../domain/project_space_semantics.dart';
import 'canonical_space_semantics_adapter.dart';

final class SpaceSemanticsInspector extends StatelessWidget {
  const SpaceSemanticsInspector({
    super.key,
    required this.projection,
    this.onUsageChanged,
  });

  final CanonicalSpaceSemanticsProjection projection;
  final ValueChanged<SpaceUsage>? onUsageChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'Room semantics inspector',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: SingleChildScrollView(
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ROOM SEMANTICS', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    projection.space.name,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _UsageField(
                    usage: projection.usage,
                    onChanged: onUsageChanged,
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Openings',
                    emptyLabel: 'No canonical openings',
                    children: [
                      for (final opening in projection.openings)
                        _OpeningRow(
                          projection: projection,
                          opening: opening,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Adjacent spaces',
                    emptyLabel: 'No canonical adjacency',
                    children: [
                      for (final adjacency in projection.adjacencies)
                        _AdjacencyRow(
                          projection: projection,
                          adjacency: adjacency,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Classifications',
                    emptyLabel: 'No overlay classifications',
                    children: [
                      for (final overlay in projection.overlays)
                        _OverlayRow(overlay: overlay),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _UsageField extends StatelessWidget {
  const _UsageField({required this.usage, this.onChanged});

  final SpaceUsage usage;
  final ValueChanged<SpaceUsage>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (onChanged == null) {
      return _LabeledValue(label: 'Usage', value: spaceUsageLabel(usage));
    }
    return DropdownButtonFormField<SpaceUsage>(
      key: const ValueKey('space-semantics-usage'),
      initialValue: usage,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Usage',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final value in SpaceUsage.values)
          DropdownMenuItem<SpaceUsage>(
            value: value,
            child: Text(
              spaceUsageLabel(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) {
        if (value != null && value != usage) onChanged?.call(value);
      },
    );
  }
}

final class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.emptyLabel,
    required this.children,
  });

  final String title;
  final String emptyLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        if (children.isEmpty)
          Text(emptyLabel, style: theme.textTheme.bodySmall)
        else
          ...children,
      ],
    );
  }
}

final class _OpeningRow extends StatelessWidget {
  const _OpeningRow({required this.projection, required this.opening});

  final CanonicalSpaceSemanticsProjection projection;
  final ProjectOpeningEntity opening;

  @override
  Widget build(BuildContext context) {
    final otherNames = opening.connectedSpaceIds
        .where((id) => id != projection.spaceId)
        .map((id) => projection.adjacentSpaces[id]?.name ?? id.toString())
        .toList(growable: false);
    final target =
        otherNames.isEmpty ? 'Exterior / unbound side' : otherNames.join(', ');
    return _SemanticRow(
      key: ValueKey('space-semantics-opening-${opening.id.value}'),
      icon: Icons.door_front_door_outlined,
      title: '${openingKindLabel(opening.kind)} · '
          '${opening.widthMm}×${opening.heightMm} mm',
      subtitle: target,
    );
  }
}

final class _AdjacencyRow extends StatelessWidget {
  const _AdjacencyRow({required this.projection, required this.adjacency});

  final CanonicalSpaceSemanticsProjection projection;
  final ProjectSpaceAdjacencyEntity adjacency;

  @override
  Widget build(BuildContext context) {
    final adjacent = projection.adjacentSpaceFor(adjacency);
    return _SemanticRow(
      key: ValueKey('space-semantics-adjacency-${adjacency.id.value}'),
      icon: adjacency.kind == SpaceAdjacencyKind.vertical
          ? Icons.swap_vert
          : Icons.compare_arrows,
      title: adjacent?.name ?? 'Unknown adjacent space',
      subtitle: adjacencyKindLabel(adjacency.kind),
    );
  }
}

final class _OverlayRow extends StatelessWidget {
  const _OverlayRow({required this.overlay});

  final ProjectOverlayClassificationEntity overlay;

  @override
  Widget build(BuildContext context) => _SemanticRow(
        icon: Icons.layers_outlined,
        title: overlay.name,
        subtitle: '${overlayDisciplineLabel(overlay.discipline)} · '
            '${overlayKindLabel(overlay.kind)}',
      );
}

final class _SemanticRow extends StatelessWidget {
  const _SemanticRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
}

final class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text('$label: ', style: Theme.of(context).textTheme.labelLarge),
          Expanded(child: Text(value)),
        ],
      );
}

String spaceUsageLabel(SpaceUsage value) => switch (value) {
      SpaceUsage.unknown => 'Unknown',
      SpaceUsage.bedroom => 'Bedroom',
      SpaceUsage.livingRoom => 'Living room',
      SpaceUsage.kitchen => 'Kitchen',
      SpaceUsage.kitchenLiving => 'Kitchen / living',
      SpaceUsage.diningRoom => 'Dining room',
      SpaceUsage.bathroom => 'Bathroom',
      SpaceUsage.wc => 'WC',
      SpaceUsage.showerRoom => 'Shower room',
      SpaceUsage.entranceHall => 'Entrance hall',
      SpaceUsage.corridor => 'Corridor',
      SpaceUsage.commonHall => 'Common hall',
      SpaceUsage.wardrobe => 'Wardrobe',
      SpaceUsage.storage => 'Storage',
      SpaceUsage.pantry => 'Pantry',
      SpaceUsage.laundry => 'Laundry',
      SpaceUsage.balcony => 'Balcony',
      SpaceUsage.loggia => 'Loggia',
      SpaceUsage.terrace => 'Terrace',
      SpaceUsage.office => 'Office',
      SpaceUsage.study => 'Study',
      SpaceUsage.garage => 'Garage',
      SpaceUsage.parking => 'Parking',
      SpaceUsage.electricalRoom => 'Electrical room',
      SpaceUsage.serverRoom => 'Server room',
      SpaceUsage.telecomRoom => 'Telecom room',
      SpaceUsage.fireControlRoom => 'Fire control room',
      SpaceUsage.utilityRoom => 'Utility room',
      SpaceUsage.mechanicalRoom => 'Mechanical room',
      SpaceUsage.stairwell => 'Stairwell',
      SpaceUsage.elevatorHall => 'Elevator hall',
      SpaceUsage.elevatorShaft => 'Elevator shaft',
      SpaceUsage.serviceShaft => 'Service shaft',
      SpaceUsage.electricalRiser => 'Electrical riser',
      SpaceUsage.telecomRiser => 'Telecom riser',
      SpaceUsage.commercial => 'Commercial',
      SpaceUsage.commonArea => 'Common area',
    };

String openingKindLabel(OpeningKind value) => switch (value) {
      OpeningKind.door => 'Door',
      OpeningKind.window => 'Window',
      OpeningKind.openPassage => 'Open passage',
      OpeningKind.hatch => 'Hatch',
      OpeningKind.serviceOpening => 'Service opening',
      OpeningKind.other => 'Opening',
    };

String adjacencyKindLabel(SpaceAdjacencyKind value) => switch (value) {
      SpaceAdjacencyKind.sharedBoundary => 'Shared boundary',
      SpaceAdjacencyKind.opening => 'Connected by opening',
      SpaceAdjacencyKind.openPassage => 'Open passage',
      SpaceAdjacencyKind.vertical => 'Vertical connection',
    };

String overlayDisciplineLabel(OverlayDiscipline value) => switch (value) {
      OverlayDiscipline.fireSafety => 'Fire safety',
      OverlayDiscipline.accessControl => 'Access control',
      OverlayDiscipline.security => 'Security',
      OverlayDiscipline.electrical => 'Electrical',
      OverlayDiscipline.telecom => 'Telecom',
      OverlayDiscipline.lighting => 'Lighting',
      OverlayDiscipline.custom => 'Custom',
    };

String overlayKindLabel(OverlayClassificationKind value) => switch (value) {
      OverlayClassificationKind.fireCompartment => 'Fire compartment',
      OverlayClassificationKind.smokeZone => 'Smoke zone',
      OverlayClassificationKind.evacuationZone => 'Evacuation zone',
      OverlayClassificationKind.accessControlZone => 'Access-control zone',
      OverlayClassificationKind.securityZone => 'Security zone',
      OverlayClassificationKind.restrictedArea => 'Restricted area',
      OverlayClassificationKind.electricalZone => 'Electrical zone',
      OverlayClassificationKind.emergencySupplyZone => 'Emergency supply zone',
      OverlayClassificationKind.telecomZone => 'Telecom zone',
      OverlayClassificationKind.networkZone => 'Network zone',
      OverlayClassificationKind.lightingControlZone => 'Lighting-control zone',
      OverlayClassificationKind.custom => 'Custom',
    };
