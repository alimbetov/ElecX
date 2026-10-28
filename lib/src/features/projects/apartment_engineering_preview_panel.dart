import 'package:flutter/material.dart';

import '../../application/project/wizard/apartment/apartment_engineering_output_projection.dart';
import '../../application/project/wizard/apartment/apartment_engineering_pipeline.dart';
import 'project_wizard_localizations.dart';

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
    final l10n = ProjectWizardLocalizations.of(context);
    final proposal = this.proposal;
    if (proposal == null) {
      return Card(
        key: const ValueKey('apartment-engineering-topology-only'),
        child: ListTile(
          leading: const Icon(Icons.account_tree_outlined),
          title: Text(l10n.apartmentTopologyOnlyPreview),
          subtitle: Text(l10n.apartmentTopologyOnlyEngineeringHint),
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
                  l10n.apartmentFrozenEngineeringOutput,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Tooltip(
                message: l10n.apartmentExactD8OutputTooltip,
                child: const Icon(Icons.lock_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _panelSummary(context, output.panelSummary, l10n),
          const SizedBox(height: 12),
          Text(
            l10n.apartmentEngineeringCircuits(output.circuitSchedule.length),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          if (output.circuitSchedule.isEmpty)
            Text(l10n.apartmentEngineeringNoBranchCircuits),
          for (final circuit in output.circuitSchedule)
            _circuitCard(context, circuit, l10n),
          const SizedBox(height: 12),
          Text(
            l10n.apartmentEngineeringSingleLineDiagram,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          _sldSummary(context, output, l10n),
          const SizedBox(height: 12),
          Text(
            l10n.apartmentEngineeringWhy,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          if (output.explanations.isEmpty)
            Text(l10n.apartmentEngineeringNoExplanations),
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
            '${l10n.apartmentEngineeringProposalFingerprint} '
            '${proposal.proposalFingerprint}\n'
            '${l10n.apartmentEngineeringOutputFingerprint} '
            '${output.outputFingerprint}\n'
            '${l10n.apartmentEngineeringRequirementsFingerprint} '
            '${output.requirementsFingerprint}',
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
    ProjectWizardLocalizations l10n,
  ) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _fact(context, l10n.apartmentEngineeringSystem,
              summary.boardPhaseSystem),
          _fact(
            context,
            l10n.apartmentEngineeringVoltage,
            '${_number(summary.lineNeutralVoltageV)} V',
          ),
          _fact(
            context,
            l10n.apartmentEngineeringMaxPhaseCurrent,
            '${_number(summary.maxPhaseCurrentA)} A',
          ),
          _fact(
            context,
            l10n.apartmentEngineeringCircuitsShort,
            summary.branchCircuitCount.toString(),
          ),
          _fact(
            context,
            l10n.apartmentEngineeringImbalance,
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
    ProjectWizardLocalizations l10n,
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
              l10n.apartmentEngineeringLoad,
              '${circuit.loadIds.join(', ')} · '
              '${_number(circuit.designPowerW)} W',
            ),
            _detail(
              l10n.apartmentEngineeringCable,
              '${circuit.conductorMaterial}, ${circuit.conductorCount} × '
              '${_number(circuit.conductorCrossSectionMm2)} mm² · '
              '${_number(circuit.routeLengthMm / 1000)} m · '
              'ΔU ${_number(circuit.voltageDropRatio * 100)} %',
            ),
            _detail(
              l10n.apartmentEngineeringOvercurrentProtection,
              '${circuit.overcurrentDeviceId} · '
              '${_number(circuit.overcurrentRatedCurrentA)} A · '
              '${_number(circuit.overcurrentBreakingCapacityKa)} kA · '
              '${circuit.overcurrentPoleCount}P',
            ),
            _detail(
              l10n.apartmentEngineeringResidualProtection,
              circuit.residualDeviceId == null
                  ? circuit.residualApplicability
                  : '${circuit.residualDeviceId} · '
                      '${circuit.residualDeviceKind ?? '-'} '
                      '${circuit.residualType ?? '-'} · '
                      '${_number(circuit.residualOperatingCurrentMa ?? 0)} mA',
            ),
            _detail(
              l10n.apartmentEngineeringFaultDisconnection,
              'Ik ${_number(circuit.prospectiveShortCircuitCurrentA)} A · '
              'Imin ${_number(circuit.minimumFaultCurrentA)} A · '
              'Imax ${_number(circuit.maximumFaultCurrentA)} A · '
              't ${_number(circuit.disconnectionOperatingTimeS)} s '
              '≤ ${_number(circuit.requiredMaxDisconnectionTimeS)} s',
            ),
            _detail(
              l10n.apartmentEngineeringCoordination,
              'OCPD ${circuit.overcurrentCoordinationStatus} · '
              'RCD ${circuit.residualCoordinationStatus}',
            ),
            for (final section in circuit.installationSections)
              _detail(
                l10n.apartmentEngineeringInstallation(section.sectionId),
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
    ProjectWizardLocalizations l10n,
  ) {
    if (output.sldNodes.isEmpty && output.sldEdges.isEmpty) {
      return Text(l10n.apartmentEngineeringNoSldNodes);
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
                : Text(l10n.apartmentEngineeringCircuit(node.circuitId!)),
          ),
        if (output.sldEdges.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.apartmentEngineeringSldConnections(output.sldEdges.length),
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
