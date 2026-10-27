import '../../../../domain/project_aggregate.dart';
import 'apartment_engineering_pipeline.dart';

/// Runtime capability bridge for the production Apartment Wizard.
///
/// The registry is deliberately keyed by the exact canonical project aggregate
/// instance rather than a project id. A pipeline therefore cannot leak across
/// independently loaded mutation timelines for the same durable project.
/// Production composition binds a source-backed pipeline when the canonical
/// runtime is resolved; provider generation only consumes that bound capability.
final class ApartmentEngineeringPipelineRuntimeRegistry {
  ApartmentEngineeringPipelineRuntimeRegistry._();

  static final Expando<ApartmentEngineeringPipeline> _pipelines =
      Expando<ApartmentEngineeringPipeline>(
          'p9-apartment-engineering-pipeline');

  static void bind({
    required ProjectAggregateRoot project,
    required ApartmentEngineeringPipeline pipeline,
  }) {
    _pipelines[project] = pipeline;
  }

  static ApartmentEngineeringPipeline? resolve(ProjectAggregateRoot project) =>
      _pipelines[project];
}
