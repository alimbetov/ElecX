import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/project_repository.dart';
import 'package:elecx/src/application/project/project_snapshot.dart';
import 'package:elecx/src/application/project/project_structure_authoring.dart';
import 'package:elecx/src/application/project/wizard/building/building_composition_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/editor/canonical_editor_production_bootstrap.dart';
import 'package:elecx/src/features/editor/canonical_editor_wizard_runtime_registry.dart';
import 'package:elecx/src/features/editor/canonical_project_navigator.dart';
import 'package:elecx/src/features/editor/initial_editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:elecx/src/features/projects/building_composition_wizard_screen.dart';
import 'package:elecx/src/features/projects/project_wizard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/p1011_wizard_fixture.dart';

Future<void> generate(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final button = find.byKey(const ValueKey('p10-wizard-generate'));
  await tester.scrollUntilVisible(button, 500,
      scrollable: find
          .descendant(
              of: find.byKey(const ValueKey('p10-wizard-parameters')),
              matching: find.byType(Scrollable))
          .first,
      maxScrolls: 40);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'UI-01 Site Building Wizard opens P10 provider; system Back discards frozen reservation',
      (tester) async {
    final runtime = P1011WizardRuntime();
    final authoring = ProjectStructureAuthoringSession(
        mutations: runtime.mutations, idFactory: runtime.ids);
    CanonicalEditorWizardRuntimeRegistry.bind(
        session: authoring, mutations: runtime.port);
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 400,
                child: CanonicalProjectNavigator(
                    session: authoring, onAuthoringCommitted: (_, __) {})))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('site-building-wizard')));
    await tester.pumpAndSettle();
    expect(find.byType(BuildingCompositionWizardScreen), findsOneWidget);
    expect(find.byType(ProjectWizardScreen), findsNothing);
    final screen = tester.widget<BuildingCompositionWizardScreen>(
        find.byType(BuildingCompositionWizardScreen));
    expect(screen.session.provider, isA<BuildingCompositionWizardProvider>());
    expect(screen.session.mutations, same(runtime.port));
    final before = p1011Bytes(runtime.mutations.current);
    await generate(tester);
    expect(screen.session.canConfirm, isTrue,
        reason:
            'status=${screen.session.status}, failure=${screen.session.failure}, validation=${screen.session.validation.issues.map((i) => i.code).toList()}, text=${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).where((s) => s?.contains("Review") == true).toList()}');
    expect(runtime.port.activePreviewCount, 1);
    final frozen = screen.session.preview!;
    expect(
        find.byKey(const ValueKey('p10-composition-summary')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BuildingCompositionWizardScreen), findsNothing);
    expect(runtime.port.activePreviewCount, 0);
    expect(runtime.mutations.undoDepth, 0);
    expect(p1011Bytes(runtime.mutations.current), before);
    expect(() => runtime.port.commitPreview(frozen),
        throwsA(isA<DiscardedWizardPreviewException>()));
  });

  testWidgets(
      'OWNER-01 actual production handle owns Site Apply, Undo Redo and re-save; legacy bootstrap is preserved',
      (tester) async {
    final repository = _MemoryRepository();
    final legacy = createInitialEditorProjectDocument(
        EditorProjectMetadata.create(
            projectName: 'Owner building',
            projectId: 'p1011-owner',
            now: DateTime.utc(2026, 10, 29)));
    final handle = await CanonicalEditorProductionHandle.loadOrBootstrap(
        legacyDocument: legacy, repository: repository);
    final owner = handle.owner,
        session = handle.session,
        port = handle.wizardMutations;
    final seedBuilding = handle.binding.buildingId;
    session.activateBuilding(seedBuilding);
    CanonicalEditorWizardRuntimeRegistry.bind(
        session: session, mutations: port);
    var accepted = 0;
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 400,
                child: CanonicalProjectNavigator(
                    session: session,
                    onAuthoringCommitted: (current, result) {
                      expect(current, same(session));
                      owner.acceptMutation(
                          sessionProject: current.project,
                          result: ProjectMutationResult(
                              project: result.project,
                              changeSet: result.changeSet));
                      accepted++;
                    })))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('site-building-wizard')));
    await tester.pumpAndSettle();
    final screen = tester.widget<BuildingCompositionWizardScreen>(
        find.byType(BuildingCompositionWizardScreen));
    expect(screen.session.mutations, same(port));
    for (final entry in {
      'x': '100000',
      'y': '100000',
      'width': '20000',
      'depth': '20000'
    }.entries) {
      final field = find
          .byKey(ValueKey('p10-existing-${seedBuilding.value}-${entry.key}'));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    await generate(tester);
    expect(screen.session.canConfirm, isTrue,
        reason:
            'status=${screen.session.status}, failure=${screen.session.failure}, validation=${screen.session.validation.issues.map((i) => i.code).toList()}, text=${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).where((s) => s?.contains("Review") == true).toList()}');
    expect(owner.version.value, 0);
    expect(accepted, 0);
    await tester.tap(find.byKey(const ValueKey('p10-wizard-apply')));
    await tester.pumpAndSettle();
    expect(find.byType(BuildingCompositionWizardScreen), findsNothing);
    expect(accepted, 1);
    expect(handle.owner, same(owner));
    expect(handle.session, same(session));
    expect(handle.wizardMutations, same(port));
    expect(owner.project, same(session.project));
    expect(owner.version.value, 1);
    expect(owner.project.stores.buildings, hasLength(2));
    expect(owner.project.stores.buildings.containsKey(seedBuilding), isTrue);
    expect(session.canUndoCanonicalMutation, isTrue);
    final bytes = p1011Bytes(session.project, includeVersion: false);
    await handle.saveCanonical();
    expect(
        p1011Bytes((await repository.load(owner.projectId))!.aggregate,
            includeVersion: false),
        bytes);
    final undo = session.undoCanonicalMutation()!;
    owner.acceptMutation(sessionProject: session.project, result: undo);
    expect(session.project.stores.buildings.keys.toSet(), {seedBuilding});
    expect(session.canUndoCanonicalMutation, isFalse);
    final redo = session.redoCanonicalMutation()!;
    owner.acceptMutation(sessionProject: session.project, result: redo);
    expect(p1011Bytes(session.project, includeVersion: false), bytes);
    await handle.saveCanonical();
    final reopened = await CanonicalEditorProductionHandle.loadOrBootstrap(
        legacyDocument: legacy, repository: repository);
    expect(p1011Bytes(reopened.owner.project, includeVersion: false), bytes);
    expect(reopened.binding.buildingId, seedBuilding);
  });

  testWidgets(
      'failed Apply releases reservation and shows no private exception text',
      (tester) async {
    var reject = false;
    final runtime = P1011WizardRuntime(guard: (_, __, ___) {
      if (reject) throw StateError('internal diagnostic must remain private');
    });
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: BuildingCompositionWizardScreen(session: runtime.wizard)));
    final before = p1011Bytes(runtime.mutations.current);
    await generate(tester);
    expect(runtime.port.activePreviewCount, 1);
    reject = true;
    await tester.tap(find.byKey(const ValueKey('p10-wizard-apply')));
    await tester.pumpAndSettle();
    expect(runtime.wizard.status.name, 'failed');
    expect(runtime.port.activePreviewCount, 0);
    expect(p1011Bytes(runtime.mutations.current), before);
    expect(runtime.mutations.undoDepth, 0);
    expect(find.textContaining('internal diagnostic'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('p10-wizard-apply')))
            .onPressed,
        isNull);
  });
  testWidgets(
      'editing parameters invalidates the frozen candidate before another Apply',
      (tester) async {
    final runtime = P1011WizardRuntime();
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: BuildingCompositionWizardScreen(session: runtime.wizard)));
    await generate(tester);
    final frozen = runtime.wizard.preview!;
    final name = find.byKey(const ValueKey('p10-cottage.main-name'));
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Edited cottage');
    await tester.pumpAndSettle();
    expect(runtime.wizard.preview, isNull);
    expect(runtime.port.activePreviewCount, 0);
    expect(runtime.mutations.undoDepth, 0);
    expect(() => runtime.port.commitPreview(frozen),
        throwsA(isA<DiscardedWizardPreviewException>()));
  });
  for (final family in BuildingCompositionWizardFamily.values) {
    testWidgets(
        'family control generates the actual ${family.name} production candidate',
        (tester) async {
      final runtime = P1011WizardRuntime();
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          home: BuildingCompositionWizardScreen(session: runtime.wizard)));
      await tester.tap(find.byKey(const ValueKey('p10-wizard-family')));
      await tester.pumpAndSettle();
      final label = switch (family) {
        BuildingCompositionWizardFamily.cottage => 'Cottage',
        BuildingCompositionWizardFamily.residentialTower => 'Residential tower',
        BuildingCompositionWizardFamily.residentialComplex =>
          'Residential complex'
      };
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      await generate(tester);
      expect(runtime.wizard.canConfirm, isTrue,
          reason: '${runtime.wizard.failure}');
      expect(
          (runtime.wizard.parameters! as BuildingCompositionWizardParameters)
              .family,
          family);
      expect(
          runtime.wizard.preview!.candidate.stores.buildings,
          hasLength(family == BuildingCompositionWizardFamily.residentialComplex
              ? 3
              : 1));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(runtime.port.activePreviewCount, 0);
    });
  }
  for (final width in [360.0, 900.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'P10 responsive form and actions at $width with text scale $scale',
          (tester) async {
        final runtime = P1011WizardRuntime();
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
                data: MediaQueryData(
                    size: Size(width, 1000),
                    textScaler: TextScaler.linear(scale)),
                child:
                    BuildingCompositionWizardScreen(session: runtime.wizard))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(runtime.mutations.current.version.value, 0);
        expect(runtime.port.activePreviewCount, 0);
        final apply =
            tester.getSize(find.byKey(const ValueKey('p10-wizard-apply')));
        expect(apply.height, greaterThanOrEqualTo(48));
        await tester.pumpWidget(const SizedBox.shrink());
        expect(runtime.port.activePreviewCount, 0);
      });
    }
  }
}

final class _MemoryRepository implements ProjectRepository {
  final Map<ProjectId, ProjectSnapshot> data = {};
  @override
  Future<ProjectSnapshot?> load(ProjectId id) async => data[id];
  @override
  Future<void> save(ProjectSnapshot snapshot) async =>
      data[snapshot.id] = snapshot;
  @override
  Future<List<ProjectSummary>> list() async =>
      data.values.map((s) => s.toSummary()).toList();
}
