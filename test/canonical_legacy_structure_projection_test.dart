import 'dart:math';

import 'package:elecx/src/application/project/project_mutation.dart';
import 'package:elecx/src/application/project/wizard/basic_building_wizard_provider.dart';
import 'package:elecx/src/application/project/wizard/project_wizard_mutation_port.dart';
import 'package:elecx/src/application/project/wizard/wizard_contracts.dart';
import 'package:elecx/src/application/project/wizard/wizard_session.dart';
import 'package:elecx/src/domain/project_identity.dart';
import 'package:elecx/src/features/editor/canonical_editor_legacy_bootstrap.dart';
import 'package:elecx/src/features/editor/canonical_legacy_identity_codec.dart';
import 'package:elecx/src/features/editor/canonical_legacy_structure_projector.dart';
import 'package:elecx/src/features/editor/initial_editor_project_document.dart';
import 'package:elecx/src/features/editor/project_persistence_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'canonical Level identity codec round-trips and malformed data fails closed',
      () {
    final levelId = LevelId('level:α/beta 42');
    final encoded = CanonicalLegacyIdentityCodec.encodeLevelId(levelId);

    expect(CanonicalLegacyIdentityCodec.isEncodedLevelId(encoded), isTrue);
    expect(CanonicalLegacyIdentityCodec.tryDecodeLevelId(encoded), levelId);
    expect(CanonicalLegacyIdentityCodec.tryDecodeLevelId('legacy-level-1'),
        isNull);
    expect(
      () => CanonicalLegacyIdentityCodec.tryDecodeLevelId(
        CanonicalLegacyIdentityCodec.levelPrefix,
      ),
      throwsFormatException,
    );
  });

  test('Wizard structural projection preserves exact LevelIds across bootstrap',
      () {
    final now = DateTime.utc(2026, 10, 24, 10);
    final metadata = EditorProjectMetadata.create(
      projectName: 'Tower project',
      projectId: 'project-structural-projection',
      now: now,
    );
    final legacy = createInitialEditorProjectDocument(metadata);
    final bootstrap = CanonicalEditorLegacyBootstrap.create(legacy);
    final originalLegacyLevelId =
        bootstrap.binding.legacyLevelIds.values.single;
    final originalCanonicalLevelId =
        bootstrap.binding.legacyLevelIds.keys.single;
    final mutations = ProjectMutationSession(bootstrap.snapshot.aggregate);
    final session = WizardSession(
      target: NewProjectWizardTarget(
        projectId: bootstrap.snapshot.aggregate.id,
        siteId: bootstrap.snapshot.aggregate.siteId,
        baseVersion: bootstrap.snapshot.aggregate.version,
      ),
      registry: WizardProviderRegistry([BasicBuildingWizardProvider()]),
      mutations: SharedProjectWizardMutationPort(
        mutations: mutations,
        idFactory: SecureRandomEntityIdFactory(random: Random(503)),
      ),
    );

    session.begin();
    session.selectFamily(BasicBuildingWizardProvider.familyId);
    session.updateParameters(
      const BasicBuildingWizardParameters(
        buildingName: 'Tower A',
        aboveGroundLevelCount: 3,
        basementLevelCount: 1,
        floorToFloorHeightMm: 3200,
        createGroundLevel: true,
      ),
    );
    expect(session.generatePreview(), isTrue);
    expect(session.confirm(), isTrue);

    final canonical = mutations.current;
    const projector = CanonicalLegacyStructureProjector();
    expect(
      projector.requiresProjection(
        legacy: legacy,
        canonical: canonical,
        binding: bootstrap.binding,
      ),
      isTrue,
    );
    final projected = projector.project(
      legacy: legacy,
      canonical: canonical,
      binding: bootstrap.binding,
      now: now.add(const Duration(minutes: 1)),
    );
    final reopened = CanonicalEditorLegacyBootstrap.create(projected);
    final canonicalBuilding =
        canonical.stores.buildings[bootstrap.binding.buildingId]!;

    expect(projected.building.building.name, 'Tower A');
    expect(projected.building.levels, hasLength(5));
    expect(
      reopened.binding.legacyLevelIds.keys.toSet(),
      canonicalBuilding.levelIds,
    );
    expect(
      reopened.binding.legacyLevelIds[originalCanonicalLevelId],
      originalLegacyLevelId,
    );
    for (final entry in reopened.binding.legacyLevelIds.entries) {
      if (entry.key == originalCanonicalLevelId) continue;
      expect(
          CanonicalLegacyIdentityCodec.isEncodedLevelId(entry.value), isTrue);
      expect(CanonicalLegacyIdentityCodec.tryDecodeLevelId(entry.value),
          entry.key);
    }
    expect(
      projector.requiresProjection(
        legacy: projected,
        canonical: canonical,
        binding: reopened.binding,
      ),
      isFalse,
    );
  });
}
