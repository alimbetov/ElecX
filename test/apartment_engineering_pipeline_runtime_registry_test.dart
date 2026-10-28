import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_pipeline.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_engineering_pipeline_runtime_registry.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApartmentEngineeringPipelineRuntimeRegistry', () {
    test('PRE10-CQ19 replace null clears a previous session binding', () {
      final session = _session();
      final pipeline = _FakeApartmentEngineeringPipeline();

      ApartmentEngineeringPipelineRuntimeRegistry.bind(
        session: session,
        pipeline: pipeline,
      );
      expect(
        ApartmentEngineeringPipelineRuntimeRegistry.resolve(session),
        same(pipeline),
      );

      ApartmentEngineeringPipelineRuntimeRegistry.replace(
        session: session,
        pipeline: null,
      );

      expect(
        ApartmentEngineeringPipelineRuntimeRegistry.resolve(session),
        isNull,
      );
    });

    test('unbind clears only the targeted authoring session', () {
      final sessionA = _session(projectId: 'project-a', siteId: 'site-a');
      final sessionB = _session(projectId: 'project-b', siteId: 'site-b');
      final pipelineA = _FakeApartmentEngineeringPipeline();
      final pipelineB = _FakeApartmentEngineeringPipeline();

      ApartmentEngineeringPipelineRuntimeRegistry.bind(
        session: sessionA,
        pipeline: pipelineA,
      );
      ApartmentEngineeringPipelineRuntimeRegistry.bind(
        session: sessionB,
        pipeline: pipelineB,
      );

      ApartmentEngineeringPipelineRuntimeRegistry.unbind(sessionA);

      expect(
        ApartmentEngineeringPipelineRuntimeRegistry.resolve(sessionA),
        isNull,
      );
      expect(
        ApartmentEngineeringPipelineRuntimeRegistry.resolve(sessionB),
        same(pipelineB),
      );
    });
  });
}

ProjectStructureAuthoringSession _session({
  String projectId = 'project-1',
  String siteId = 'site-1',
}) {
  final rootSiteId = SiteId(siteId);
  final project = ProjectAggregateRoot(
    id: ProjectId(projectId),
    siteId: rootSiteId,
    version: LocalProjectVersion(0),
    stores: ProjectEntityStores(
      sites: <SiteId, ProjectSiteEntity>{
        rootSiteId: ProjectSiteEntity(
          id: rootSiteId,
          name: 'Site',
          buildingIds: const <BuildingId>[],
        ),
      },
    ),
  );
  return ProjectStructureAuthoringSession(
    mutations: ProjectMutationSession(project),
    idFactory: SecureRandomEntityIdFactory(random: Random(7)),
  );
}

final class _FakeApartmentEngineeringPipeline
    implements ApartmentEngineeringPipeline {
  @override
  ApartmentEngineeringProposal generate({
    required String candidateSetFingerprint,
    required ApartmentCandidateCard selected,
    required WizardGenerationContext context,
  }) {
    throw UnimplementedError('The registry test never executes the pipeline.');
  }
}
