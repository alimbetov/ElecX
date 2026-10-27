import '../../project_structure_authoring.dart';
import 'apartment_engineering_pipeline.dart';

/// Runtime capability bridge for the production Apartment Wizard.
///
/// The registry is deliberately keyed by the exact canonical authoring-session
/// identity. Project aggregates are immutable and are replaced on every commit,
/// Undo and Redo, while the session owns that entire mutation timeline. Binding
/// the pipeline to the session therefore prevents both cross-project leakage and
/// accidental capability loss after the first canonical mutation.
final class ApartmentEngineeringPipelineRuntimeRegistry {
  ApartmentEngineeringPipelineRuntimeRegistry._();

  static final Expando<ApartmentEngineeringPipeline> _pipelines =
      Expando<ApartmentEngineeringPipeline>(
          'p9-apartment-engineering-pipeline');

  static void bind({
    required ProjectStructureAuthoringSession session,
    required ApartmentEngineeringPipeline pipeline,
  }) {
    _pipelines[session] = pipeline;
  }

  static ApartmentEngineeringPipeline? resolve(
    ProjectStructureAuthoringSession session,
  ) =>
      _pipelines[session];
}
