import 'component_catalog_v2.dart';
import 'engineering_graph.dart';

enum ComponentCategory {
  power,
  lighting,
  data,
  cctv,
  accessControl,
  fireSafety,
  automation,
  infrastructure,
  custom,
}

enum ComponentSubcategory {
  socketOutlet,
  switchControl,
  luminaire,
  distributionBoard,
  junctionBox,
  powerSource,
  motorDrive,
  dataOutlet,
  accessPoint,
  camera,
  accessReader,
  detector,
  contactSensor,
  fiberTermination,
  controller,
  custom,
}

final class ComponentTaxonomyRef {
  const ComponentTaxonomyRef({
    required this.category,
    required this.subcategory,
  });

  final ComponentCategory category;
  final ComponentSubcategory subcategory;
}

/// Stable semantic taxonomy independent from localized display names.
///
/// Default catalog ids are intentionally used only as identity, never as
/// translated labels. External/user catalogs should persist category and
/// subcategory explicitly when they are introduced.
abstract final class ComponentTaxonomyResolver {
  static ComponentTaxonomyRef resolve(ComponentCatalogEntryV2 entry) {
    final id = entry.id;
    if (id == 'power.socket.general') {
      return const ComponentTaxonomyRef(
        category: ComponentCategory.power,
        subcategory: ComponentSubcategory.socketOutlet,
      );
    }
    if (id == 'lighting.switch.general') {
      return const ComponentTaxonomyRef(
        category: ComponentCategory.lighting,
        subcategory: ComponentSubcategory.switchControl,
      );
    }
    if (id == 'lighting.luminaire.general') {
      return const ComponentTaxonomyRef(
        category: ComponentCategory.lighting,
        subcategory: ComponentSubcategory.luminaire,
      );
    }
    if (id == 'power.distribution-board.general') {
      return const ComponentTaxonomyRef(
        category: ComponentCategory.power,
        subcategory: ComponentSubcategory.distributionBoard,
      );
    }
    if (id == 'power.junction-box.general') {
      return const ComponentTaxonomyRef(
        category: ComponentCategory.infrastructure,
        subcategory: ComponentSubcategory.junctionBox,
      );
    }
    if (id == 'power.source.general') {
      return const ComponentTaxonomyRef(
        category: ComponentCategory.power,
        subcategory: ComponentSubcategory.powerSource,
      );
    }
    if (id == 'power.motor.curtain') {
      return const ComponentTaxonomyRef(
        category: ComponentCategory.automation,
        subcategory: ComponentSubcategory.motorDrive,
      );
    }
    return switch (entry.systemClass) {
      EngineeringSystemClass.structuredCabling => const ComponentTaxonomyRef(
          category: ComponentCategory.data,
          subcategory: ComponentSubcategory.dataOutlet,
        ),
      EngineeringSystemClass.poeNetwork => const ComponentTaxonomyRef(
          category: ComponentCategory.data,
          subcategory: ComponentSubcategory.accessPoint,
        ),
      EngineeringSystemClass.fiberOptic => const ComponentTaxonomyRef(
          category: ComponentCategory.data,
          subcategory: ComponentSubcategory.fiberTermination,
        ),
      EngineeringSystemClass.cctv => const ComponentTaxonomyRef(
          category: ComponentCategory.cctv,
          subcategory: ComponentSubcategory.camera,
        ),
      EngineeringSystemClass.accessControl => const ComponentTaxonomyRef(
          category: ComponentCategory.accessControl,
          subcategory: ComponentSubcategory.accessReader,
        ),
      EngineeringSystemClass.fireAlarm => const ComponentTaxonomyRef(
          category: ComponentCategory.fireSafety,
          subcategory: ComponentSubcategory.detector,
        ),
      EngineeringSystemClass.automationBus => const ComponentTaxonomyRef(
          category: ComponentCategory.automation,
          subcategory: ComponentSubcategory.controller,
        ),
      EngineeringSystemClass.dryContact => const ComponentTaxonomyRef(
          category: ComponentCategory.automation,
          subcategory: ComponentSubcategory.contactSensor,
        ),
      EngineeringSystemClass.lighting => const ComponentTaxonomyRef(
          category: ComponentCategory.lighting,
          subcategory: ComponentSubcategory.luminaire,
        ),
      EngineeringSystemClass.powerAc ||
      EngineeringSystemClass.powerDc =>
        const ComponentTaxonomyRef(
          category: ComponentCategory.power,
          subcategory: ComponentSubcategory.custom,
        ),
      EngineeringSystemClass.custom => const ComponentTaxonomyRef(
          category: ComponentCategory.custom,
          subcategory: ComponentSubcategory.custom,
        ),
    };
  }
}
