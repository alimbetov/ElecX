import 'package:flutter/material.dart';

import '../../application/project/wizard/apartment/apartment_engineering_output_projection.dart';
import '../../application/project/wizard/apartment/apartment_engineering_pipeline.dart';

/// Human-facing view of the exact D8 proposal frozen by Apartment Wizard
/// Preview. This widget is presentation-only: it never invokes the engineering
/// pipeline and therefore cannot diverge from the command that Apply commits.
final class ApartmentEngineeringPreviewPanel extends StatelessWidget {
  const ApartmentEngineeringPreviewPanel({
    required this.proposal,
    super.key,
  });

  final ApartmentEngineeringProposal? proposal;

  @override
  Widget build(BuildContext context) {
    final proposal = this.proposal;
    if (proposal == null) {
      return Card(
        key: const ValueKey('apartment-engineering-topology-only'),
        child: const ListTile(
          leading: Icon(Icons.account_tree_outlined),
          title: Text('Topology-only preview'),
          subtitle: Text(
            'No electrical values are assumed. Engineering output becomes '
            'available only when authoritative electrical inputs are configured.',
          ),
        ),
      );
    }

    final output = proposal.output;
    return Card(
      key: const ValueKey('apartment-engineering-preview'),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              const Icon(Icons.electrical_services_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Frozen engineering output',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Tooltip(
                message: 'Exact D8 output used by Apply',
                child: const Icon(Icons.lock_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _panelSummary(context, output.panelSummary),
          const SizedBox(height: 12),
          Text(
            'Circuits (${output.circuitSchedule.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          if (output.circuitSchedule.isEmpty)
            const Text('No branch circuits in this engineering projection.'),
          for (final circuit in output.circuitSchedule)
            _circuitCard(context, circuit),
          const SizedBox(height: 12),
          Text(
            'Single-line diagram',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          _sldSummary(context, output),
          const SizedBox(height: 12),
          Text('Why', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          if (output.explanations.isEmpty)
            const Text('No additional engineering explanations.'),
          for (final explanation in output.explanations)
            ListTile(
              key: ValueKey(
                'apartment-engineering-why-${explanation.code}-'
                '${explanation.circuitId ?? 'global'}',
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline, size: 18),
              title: Text(explanation.code),
              subtitle: Text(
                '${explanation.value}\n'
                '${explanation.sourceId} @ ${explanation.sourceRevision}',
              ),
            ),
          const Divider(),
          SelectableText(
            'Proposal ${proposal.proposalFingerprint}\n'
            'Output ${output.outputFingerprint}\n'
            'Requirements ${output.requirementsFingerprint}',
            key: const ValueKey('apartment-engineering-fingerprints'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _panelSummary(
    BuildContext context,
    ApartmentEngineeringPanelSummary summary,
  ) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _fact(context, 'System', summary.boardPhaseSystem),
          _fact(
            context,
            'Voltage',
            '${_number(summary.lineNeutralVoltageV)} V',
          ),
          _fact(
            context,
            'Max phase current',
            '${_number(summary.maxPhaseCurrentA)} A',
          ),
          _fact(
            context,
            'Circuits',
            summary.branchCircuitCount.toString(),
          ),
          _fact(
            context,
            'Imbalance',
            '${_number(summary.phaseCurrentImbalanceRatio * 100)} %',
          ),
        ],
      );

  Widget _fact(BuildContext context, String label, String value) => Container(
        constraints: const BoxConstraints(minWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );

  Widget _circuitCard(
    BuildContext context,
    ApartmentEngineeringCircuitScheduleRow circuit,
  ) =>
      Card.outlined(
        key: ValueKey('apartment-engineering-circuit-${circuit.circuitId}'),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Text('${circuit.circuitId} · ${circuit.assignedPhase}'),
          subtitle: Text(
            '${_number(circuit.designCurrentA)} A · '
            '${circuit.cableName} ${_number(circuit.conductorCrossSectionMm2)} mm² · '
            '${circuit.overcurrentDeviceKind} '
            '${_number(circuit.overcurrentRatedCurrentA)} A',
          ),
          children: [
            _detail(
              'Load',
              '${circuit.loadIds.join(', ')} · '
                  '${_number(circuit.designPowerW)} W',
            ),
            _detail(
              'Cable',
              '${circuit.conductorMaterial}, ${circuit.conductorCount} × '
                  '${_number(circuit.conductorCrossSectionMm2)} mm² · '
                  '${_number(circuit.routeLengthMm / 1000)} m · '
                  'ΔU ${_number(circuit.voltageDropRatio * 100)} %',
            ),
            _detail(
              'Overcurrent protection',
              '${circuit.overcurrentDeviceId} · '
                  '${_number(circuit.overcurrentRatedCurrentA)} A · '
                  '${_number(circuit.overcurrentBreakingCapacityKa)} kA · '
                  '${circuit.overcurrentPoleCount}P',
            ),
            _detail(
              'RCD / residual protection',
              circuit.residualDeviceId == null
                  ? circuit.residualApplicability
                  : '${circuit.residualDeviceId} · '
                      '${circuit.residualDeviceKind ?? '-'} '
                      '${circuit.residualType ?? '-'} · '
                      '${_number(circuit.residualOperatingCurrentMa ?? 0)} mA',
            ),
            _detail(
              'Fault / disconnection',
              'Ik ${_number(circuit.prospectiveShortCircuitCurrentA)} A · '
                  'Imin ${_number(circuit.minimumFaultCurrentA)} A · '
                  'Imax ${_number(circuit.maximumFaultCurrentA)} A · '
                  't ${_number(circuit.disconnectionOperatingTimeS)} s '
                  '≤ ${_number(circuit.requiredMaxDisconnectionTimeS)} s',
            ),
            _detail(
              'Coordination',
              'OCPD ${circuit.overcurrentCoordinationStatus} · '
                  'RCD ${circuit.residualCoordinationStatus}',
            ),
            for (final section in circuit.installationSections)
              _detail(
                'Installation ${section.sectionId}',
                '${section.installationMethodId} · '
                    '${section.ampacitySourceKey} · '
                    '${section.sourceId} @ ${section.sourceRevision}',
              ),
          ],
        ),
      );

  Widget _detail(String label, String value) => ListTile(
        dense: true,
        title: Text(label),
        subtitle: Text(value),
      );

  Widget _sldSummary(
    BuildContext context,
    ApartmentEngineeringOutputProjection output,
  ) {
    if (output.sldNodes.isEmpty && output.sldEdges.isEmpty) {
      return const Text('No SLD nodes in this engineering projection.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final node in output.sldNodes)
          ListTile(
            key: ValueKey('apartment-engineering-sld-node-${node.id}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(_sldIcon(node.kind), size: 18),
            title: Text('${node.kind.name} · ${node.referenceId}'),
            subtitle: node.circuitId == null
                ? null
                : Text('Circuit ${node.circuitId}'),
          ),
        if (output.sldEdges.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${output.sldEdges.length} SLD connections',
              key: const ValueKey('apartment-engineering-sld-edge-count'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  IconData _sldIcon(ApartmentEngineeringSldNodeKind kind) => switch (kind) {
        ApartmentEngineeringSldNodeKind.board => Icons.dashboard_outlined,
        ApartmentEngineeringSldNodeKind.overcurrentProtection =>
          Icons.toggle_on_outlined,
        ApartmentEngineeringSldNodeKind.residualCurrentProtection =>
          Icons.shield_outlined,
        ApartmentEngineeringSldNodeKind.combinedProtection =>
          Icons.security_outlined,
        ApartmentEngineeringSldNodeKind.cable => Icons.cable_outlined,
        ApartmentEngineeringSldNodeKind.loadGroup =>
          Icons.electrical_services_outlined,
      };

  String _number(num value) {
    final rounded = value.toDouble();
    if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
    return rounded.toStringAsFixed(2);
  }
}
