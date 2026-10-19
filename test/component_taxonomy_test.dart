import 'package:elecx/src/domain/component_catalog_v2.dart';
import 'package:elecx/src/domain/component_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distribution board resolves by stable identity, not localized name', () {
    final entry = ComponentCatalogV2.require('power.distribution-board.general');
    final taxonomy = ComponentTaxonomyResolver.resolve(entry);

    expect(taxonomy.category, ComponentCategory.power);
    expect(taxonomy.subcategory, ComponentSubcategory.distributionBoard);
  });

  test('lighting switch and luminaire resolve to different subcategories', () {
    final switchEntry = ComponentCatalogV2.require('lighting.switch.general');
    final lightEntry = ComponentCatalogV2.require('lighting.luminaire.general');

    expect(
      ComponentTaxonomyResolver.resolve(switchEntry).subcategory,
      ComponentSubcategory.switchControl,
    );
    expect(
      ComponentTaxonomyResolver.resolve(lightEntry).subcategory,
      ComponentSubcategory.luminaire,
    );
  });
}
