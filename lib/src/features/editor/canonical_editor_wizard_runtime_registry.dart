import '../../application/project/project_structure_authoring.dart';
import '../../application/project/wizard/project_wizard_mutation_port.dart';

/// Session-identity bridge between the production composition root and the
/// canonical Project Navigator.
///
/// The registry never creates a mutation session or a Wizard port. It only
/// exposes the exact [ProjectWizardMutationPort] already composed for the same
/// [ProjectStructureAuthoringSession]. [Expando] keeps the association scoped
/// to the lifetime of the canonical session and avoids a project-id global map.
final class CanonicalEditorWizardRuntimeRegistry {
  CanonicalEditorWizardRuntimeRegistry._();

  static final Expando<ProjectWizardMutationPort> _ports =
      Expando<ProjectWizardMutationPort>('canonical-editor-wizard-port');

  static void bind({
    required ProjectStructureAuthoringSession session,
    required ProjectWizardMutationPort mutations,
  }) {
    _ports[session] = mutations;
  }

  static ProjectWizardMutationPort? resolve(
    ProjectStructureAuthoringSession session,
  ) =>
      _ports[session];
}
