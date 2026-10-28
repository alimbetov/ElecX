import 'dart:math';
import 'dart:ui' show PointerDeviceKind;

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_candidate_set_service.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_parameters.dart';
import 'package:elecx/src/application/project/wizard/apartment/apartment_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_preview_scene.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/apartment_topology.dart';
import 'package:elecx/src/domain/project_aggregate.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/projects/project_wizard_localizations.dart';
import 'package:elecx/src/features/projects/wizard_candidate_carousel.dart';
import 'package:elecx/src/serialization/project/generation_provenance_aware_canonical_project_document_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GJ-02 existing empty Level leaves unrelated hierarchy unchanged', () {
    final fixture = _multiLevelFixture();
    const service = ApartmentCandidateSetService();
    final generated = service.generate(
      input: _request,
      target: fixture.target,
      project: fixture.project,
    );
    expect(generated.accepted, isTrue, reason: '${generated.failures}');
    final set = generated.candidateSet!;
    final selected = set.recommendedCandidate;
    final beforeUnrelated = _unrelatedHierarchySignature(
      fixture.project,
      targetLevelId: fixture.target.levelId,
    );

    final mutations = ProjectMutationSession(fixture.project);
    final session = WizardSession(
      target: fixture.target,
      registry: WizardProviderRegistry(const [ApartmentWizardProvider()]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(9130202)),
      ),
    );
    expect(session.begin(), isTrue);
    expect(session.selectFamily(ApartmentWizardProvider.familyId), isTrue);
    expect(
      session.updateParameters(
        ApartmentWizardParameters(
          request: _request,
          selection: set.selectionFor(selected),
        ),
      ),
      isTrue,
    );
    expect(session.generatePreview(), isTrue, reason: '${session.failure}');
    expect(session.confirm(), isTrue, reason: '${session.failure}');

    expect(
      _unrelatedHierarchySignature(
        mutations.current,
        targetLevelId: fixture.target.levelId,
      ),
      beforeUnrelated,
    );
    expect(
      mutations.current.stores.levels[fixture.target.levelId]!.spaceIds,
      isNotEmpty,
    );
    expect(
      mutations.current.stores.levels[fixture.target.levelId]!.zoneIds,
      isNotEmpty,
    );

    const codec = GenerationProvenanceAwareCanonicalProjectDocumentCodec();
    final encoded = codec.encode(
      ProjectSnapshot(
        aggregate: mutations.current,
        name: 'P9.13 GJ-02',
        createdAt: DateTime.utc(2026, 10, 28, 4),
        updatedAt: DateTime.utc(2026, 10, 28, 4),
      ),
    );
    final reopened = codec.decode(encoded).aggregate;
    expect(
      _unrelatedHierarchySignature(
        reopened,
        targetLevelId: fixture.target.levelId,
      ),
      beforeUnrelated,
    );
    expect(
      reopened.stores.levels[fixture.target.levelId]!.spaceIds,
      mutations.current.stores.levels[fixture.target.levelId]!.spaceIds,
    );
    expect(
      reopened.engineeringMetadata.generationProvenanceRegistry.manifests,
      isNotEmpty,
    );
  });

  testWidgets(
      'GJ-04 keyboard mouse touch and stylus select and apply identical candidate semantics',
      (tester) async {
    final fixture = _singleLevelFixture();
    const service = ApartmentCandidateSetService();
    final generated = service.generate(
      input: _request,
      target: fixture.target,
      project: fixture.project,
    );
    expect(generated.accepted, isTrue, reason: '${generated.failures}');
    final set = generated.candidateSet!;
    expect(set.candidates.length, greaterThanOrEqualTo(2));
    final first = set.candidates.first;
    final expected = set.candidates[1];
    final cards = <WizardCandidateCard>[
      for (var index = 0; index < set.candidates.length; index++)
        WizardCandidateCard(
          id: set.candidates[index].candidateFingerprint,
          title: 'Candidate ${index + 1}',
          scene: _scene(index),
        ),
    ];

    final results = <String, _AppliedSemantics>{};
    for (final modality in _modalities) {
      var selectedId = first.candidateFingerprint;
      await tester.pumpWidget(
        _carouselApp(
          key: ValueKey('gj04-${modality.label}'),
          cards: cards,
          selectedId: selectedId,
          onSelected: (value) => selectedId = value,
        ),
      );
      await tester.pumpAndSettle();

      final next = find.byKey(const ValueKey('wizard-candidate-next'));
      expect(next, findsOneWidget, reason: modality.label);
      final nextSize = tester.getSize(next);
      expect(nextSize.width, greaterThanOrEqualTo(48), reason: modality.label);
      expect(nextSize.height, greaterThanOrEqualTo(48), reason: modality.label);

      switch (modality.kind) {
        case _InputKind.keyboard:
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        case _InputKind.mouse:
          await tester.tap(next, kind: PointerDeviceKind.mouse);
        case _InputKind.touch:
          await tester.tap(next, kind: PointerDeviceKind.touch);
        case _InputKind.stylus:
          await tester.tap(next, kind: PointerDeviceKind.stylus);
      }
      await tester.pumpAndSettle();
      expect(
        selectedId,
        expected.candidateFingerprint,
        reason: '${modality.label}: input must select candidate #2',
      );

      results[modality.label] = _applySelectedCandidate(
        fixture: fixture,
        set: set,
        selectedCandidateId: selectedId,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }

    final baseline = results.values.first;
    for (final entry in results.entries) {
      expect(
        entry.value.normalizedIntentKey,
        baseline.normalizedIntentKey,
        reason: '${entry.key}: normalized intent diverged',
      );
      expect(
        entry.value.semanticOperationKeys,
        baseline.semanticOperationKeys,
        reason: '${entry.key}: semantic Diff diverged',
      );
      expect(
        entry.value.appliedSignature,
        baseline.appliedSignature,
        reason: '${entry.key}: Apply result diverged',
      );
    }
  });
}

const _request = ApartmentRequestInput(
  habitableRoomCount: 3,
  approximateAreaDm2: 7850,
  bathroomCount: 1,
  separateWcCount: 0,
  balconyCount: 1,
  balconyKind: ApartmentBalconyKind.loggia,
  kitchenMode: ApartmentKitchenMode.kitchenLiving,
  corridorMode: ApartmentCorridorMode.auto,
  exteriorExposurePreference: ApartmentExteriorExposurePreference.any,
);

enum _InputKind { keyboard, mouse, touch, stylus }

final class _InputModality {
  const _InputModality(this.label, this.kind);

  final String label;
  final _InputKind kind;
}

const _modalities = <_InputModality>[
  _InputModality('keyboard-only', _InputKind.keyboard),
  _InputModality('mouse+keyboard', _InputKind.mouse),
  _InputModality('touch-only', _InputKind.touch),
  _InputModality('stylus-as-pointer', _InputKind.stylus),
];

Widget _carouselApp({
  required Key key,
  required List<WizardCandidateCard> cards,
  required String selectedId,
  required ValueChanged<String> onSelected,
}) =>
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: ProjectWizardLocalizations.supportedLocales,
      localizationsDelegates: ProjectWizardLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: WizardCandidateCarousel(
            key: key,
            candidates: cards,
            selectedId: selectedId,
            onSelected: onSelected,
          ),
        ),
      ),
    );

WizardPreviewScene _scene(int index) => WizardPreviewScene(
      width: 200,
      height: 120,
      semanticLabel: 'P9.13 candidate ${index + 1}',
      elements: <WizardPreviewElement>[
        WizardPreviewRect(
          key: 'candidate-$index',
          role: WizardPreviewRole.spaceRegion,
          x: 10,
          y: 10,
          width: 180,
          height: 100,
        ),
      ],
    );

final class _AppliedSemantics {
  const _AppliedSemantics({
    required this.normalizedIntentKey,
    required this.semanticOperationKeys,
    required this.appliedSignature,
  });

  final String normalizedIntentKey;
  final List<String> semanticOperationKeys;
  final String appliedSignature;
}

_AppliedSemantics _applySelectedCandidate({
  required _Fixture fixture,
  required ApartmentCandidateSet set,
  required String selectedCandidateId,
}) {
  final selected = set.candidates.singleWhere(
    (candidate) => candidate.candidateFingerprint == selectedCandidateId,
  );
  final mutations = ProjectMutationSession(fixture.project);
  final session = WizardSession(
    target: fixture.target,
    registry: WizardProviderRegistry(const [ApartmentWizardProvider()]),
    mutations: SharedProjectWizardMutationPort(
      mutations: mutations,
      idFactory: SecureRandomEntityIdFactory(random: Random(9130404)),
    ),
  );
  expect(session.begin(), isTrue);
  expect(session.selectFamily(ApartmentWizardProvider.familyId), isTrue);
  expect(
    session.updateParameters(
      ApartmentWizardParameters(
        request: _request,
        selection: set.selectionFor(selected),
      ),
    ),
    isTrue,
  );
  expect(session.generatePreview(), isTrue, reason: '${session.failure}');
  final preview = session.preview!;
  final semanticKeys = preview.semanticChangeSet.operations
      .map((operation) => operation.semanticKey)
      .toList(growable: false);
  final normalizedIntentKey = preview.normalizedIntentKey;
  expect(session.confirm(), isTrue, reason: '${session.failure}');
  expect(mutations.undoDepth, 1);
  return _AppliedSemantics(
    normalizedIntentKey: normalizedIntentKey,
    semanticOperationKeys: semanticKeys,
    appliedSignature: _targetSemanticSignature(
      mutations.current,
      fixture.target.levelId,
    ),
  );
}

String _targetSemanticSignature(
  ProjectAggregateRoot project,
  LevelId levelId,
) {
  final level = project.stores.levels[levelId]!;
  final lines = <String>[
    'level|${level.id.value}|${(level.zoneIds.map((id) => id.value).toList()..sort()).join(',')}|'
        '${(level.spaceIds.map((id) => id.value).toList()..sort()).join(',')}',
  ];
  for (final zoneId in level.zoneIds.toList()
    ..sort((left, right) => left.value.compareTo(right.value))) {
    final zone = project.stores.zones[zoneId]!;
    lines.add(
      'zone|${zone.id.value}|${zone.kind.name}|'
      '${(zone.spaceIds.map((id) => id.value).toList()..sort()).join(',')}',
    );
  }
  for (final spaceId in level.spaceIds.toList()
    ..sort((left, right) => left.value.compareTo(right.value))) {
    final space = project.stores.spaces[spaceId]!;
    lines.add(
      'space|${space.id.value}|${space.name}|${space.type.name}|${space.usage.name}',
    );
    final topology = project.stores.boundaries[spaceId];
    if (topology != null) {
      lines.add(
        'boundary|${topology.orderedEdgeIds.map((edgeId) {
          final edge = topology.edges[edgeId]!;
          return '${edgeId.value}:${edge.start.xMm},${edge.start.yMm}>'
              '${edge.end.xMm},${edge.end.yMm}';
        }).join(';')}',
      );
    }
  }
  return lines.join('\n');
}

String _unrelatedHierarchySignature(
  ProjectAggregateRoot project, {
  required LevelId targetLevelId,
}) {
  final lines = <String>[];
  for (final site in project.stores.sites.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value))) {
    lines.add(
      'site|${site.id.value}|${site.name}|'
      '${(site.buildingIds.map((id) => id.value).toList()..sort()).join(',')}',
    );
  }
  for (final building in project.stores.buildings.values.toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value))) {
    lines.add(
      'building|${building.id.value}|${building.name}|'
      '${(building.levelIds.map((id) => id.value).toList()..sort()).join(',')}',
    );
  }
  for (final level in project.stores.levels.values
      .where((level) => level.id != targetLevelId)
      .toList()
    ..sort((a, b) => a.id.value.compareTo(b.id.value))) {
    lines.add(
      'level|${level.id.value}|${level.buildingId.value}|${level.name}|'
      '${level.levelNumber}|${level.elevationMm}|${level.kind.name}|'
      '${(level.zoneIds.map((id) => id.value).toList()..sort()).join(',')}|'
      '${(level.spaceIds.map((id) => id.value).toList()..sort()).join(',')}',
    );
  }
  return lines.join('\n');
}

final class _Fixture {
  const _Fixture({required this.project, required this.target});

  final ProjectAggregateRoot project;
  final LevelWizardTarget target;
}

_Fixture _singleLevelFixture() {
  final projectId = ProjectId('p9-p913-gj04-project');
  final siteId = SiteId('p9-p913-gj04-site');
  final buildingId = BuildingId('p9-p913-gj04-building');
  final levelId = LevelId('p9-p913-gj04-level');
  final version = LocalProjectVersion(13);
  final project = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: version,
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'P9.13 Site',
          buildingIds: {buildingId},
        ),
      },
      buildings: {
        buildingId: ProjectBuildingEntity(
          id: buildingId,
          siteId: siteId,
          name: 'P9.13 Building',
          levelIds: {levelId},
        ),
      },
      levels: {
        levelId: ProjectLevelEntity(
          id: levelId,
          buildingId: buildingId,
          name: 'Level 1',
          levelNumber: 1,
          elevationMm: 3000,
          kind: ProjectLevelKind.residential,
        ),
      },
    ),
  );
  return _Fixture(
    project: project,
    target: LevelWizardTarget(
      projectId: projectId,
      siteId: siteId,
      baseVersion: version,
      buildingId: buildingId,
      levelId: levelId,
    ),
  );
}

_Fixture _multiLevelFixture() {
  final projectId = ProjectId('p9-p913-gj02-project');
  final siteId = SiteId('p9-p913-gj02-site');
  final targetBuildingId = BuildingId('p9-p913-gj02-target-building');
  final otherBuildingId = BuildingId('p9-p913-gj02-other-building');
  final targetLevelId = LevelId('p9-p913-gj02-target-level');
  final siblingLevelId = LevelId('p9-p913-gj02-sibling-level');
  final otherBuildingLevelId = LevelId('p9-p913-gj02-other-building-level');
  final version = LocalProjectVersion(13);

  final project = ProjectAggregateRoot(
    id: projectId,
    siteId: siteId,
    version: version,
    stores: ProjectEntityStores(
      sites: {
        siteId: ProjectSiteEntity(
          id: siteId,
          name: 'P9.13 Multi-building Site',
          buildingIds: {targetBuildingId, otherBuildingId},
        ),
      },
      buildings: {
        targetBuildingId: ProjectBuildingEntity(
          id: targetBuildingId,
          siteId: siteId,
          name: 'Target Building',
          levelIds: {targetLevelId, siblingLevelId},
        ),
        otherBuildingId: ProjectBuildingEntity(
          id: otherBuildingId,
          siteId: siteId,
          name: 'Unrelated Building',
          levelIds: {otherBuildingLevelId},
        ),
      },
      levels: {
        targetLevelId: ProjectLevelEntity(
          id: targetLevelId,
          buildingId: targetBuildingId,
          name: 'Target Level',
          levelNumber: 2,
          elevationMm: 6000,
          kind: ProjectLevelKind.residential,
        ),
        siblingLevelId: ProjectLevelEntity(
          id: siblingLevelId,
          buildingId: targetBuildingId,
          name: 'Sibling Level',
          levelNumber: 1,
          elevationMm: 3000,
          kind: ProjectLevelKind.residential,
        ),
        otherBuildingLevelId: ProjectLevelEntity(
          id: otherBuildingLevelId,
          buildingId: otherBuildingId,
          name: 'Unrelated Level',
          levelNumber: 1,
          elevationMm: 3000,
          kind: ProjectLevelKind.residential,
        ),
      },
    ),
  );

  return _Fixture(
    project: project,
    target: LevelWizardTarget(
      projectId: projectId,
      siteId: siteId,
      baseVersion: version,
      buildingId: targetBuildingId,
      levelId: targetLevelId,
    ),
  );
}
