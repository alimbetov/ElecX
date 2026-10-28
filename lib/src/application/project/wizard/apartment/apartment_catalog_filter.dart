import '../../../../domain/apartment_topology.dart';
import '../../../../domain/apartment_topology/apartment_topology_catalog.dart';
import '../../../../domain/apartment_topology/apartment_topology_models.dart';
import 'apartment_wizard_parameters.dart';

/// Pure P9.2 compatibility filter. Catalog integrity is validated separately
/// before a production catalog is made available to Wizard sessions.
final class ApartmentTopologyCatalogFilter {
  const ApartmentTopologyCatalogFilter();

  List<TemplateCompatibility> evaluate(
    ApartmentTopologyCatalog catalog,
    NormalizedApartmentRequest request,
  ) {
    final result = [
      for (final template in catalog.templates)
        TemplateCompatibility(
          template: template,
          reasons: _reasons(template, request),
        ),
    ];
    result.sort(
      (left, right) => _compareTemplates(
        left.template,
        right.template,
        request.preferredFamily,
      ),
    );
    return List.unmodifiable(result);
  }

  List<ApartmentTopologyTemplate> compatibleTemplates(
    ApartmentTopologyCatalog catalog,
    NormalizedApartmentRequest request,
  ) =>
      List.unmodifiable(
        evaluate(catalog, request)
            .where((compatibility) => compatibility.compatible)
            .map((compatibility) => compatibility.template),
      );

  List<TemplateIncompatibilityReason> _reasons(
    ApartmentTopologyTemplate template,
    NormalizedApartmentRequest request,
  ) {
    final constraints = template.constraints;
    final reasons = <TemplateIncompatibilityReason>[];

    if (!constraints.supportedHabitableRoomCounts
        .contains(request.habitableRoomCount)) {
      reasons.add(
        _reason(
          'p9.catalog.room-count',
          'habitableRoomCount',
          request.habitableRoomCount,
        ),
      );
    }
    if (request.interiorAreaDm2 < constraints.minInteriorAreaDm2) {
      reasons.add(
        _reason(
          'p9.catalog.area-too-small',
          'interiorAreaDm2',
          request.interiorAreaDm2,
        ),
      );
    } else if (request.interiorAreaDm2 > constraints.maxInteriorAreaDm2) {
      reasons.add(
        _reason(
          'p9.catalog.area-too-large',
          'interiorAreaDm2',
          request.interiorAreaDm2,
        ),
      );
    }
    if (!constraints.supportedBathroomCounts.contains(request.bathroomCount)) {
      reasons.add(
        _reason(
          'p9.catalog.bathroom-count',
          'bathroomCount',
          request.bathroomCount,
        ),
      );
    }
    if (!constraints.supportedSeparateWcCounts
        .contains(request.separateWcCount)) {
      reasons.add(
        _reason(
          'p9.catalog.wc-count',
          'separateWcCount',
          request.separateWcCount,
        ),
      );
    }
    if (!constraints.supportedBalconyCounts.contains(request.balconyCount)) {
      reasons.add(
        _reason(
          'p9.catalog.balcony-count',
          'balconyCount',
          request.balconyCount,
        ),
      );
    }
    if (!_supportsBalconyKind(
      constraints.supportedBalconyKinds,
      request.balconyKind,
    )) {
      reasons.add(
        _reason(
          'p9.catalog.balcony-kind',
          'balconyKind',
          request.balconyKind.code,
        ),
      );
    }
    if (!constraints.supportedKitchenModes.contains(request.kitchenMode)) {
      reasons.add(
        _reason(
          'p9.catalog.kitchen-mode',
          'kitchenMode',
          request.kitchenMode.code,
        ),
      );
    }
    if (request.corridorMode != ApartmentCorridorMode.auto &&
        !constraints.supportedCorridorModes.contains(request.corridorMode)) {
      reasons.add(
        _reason(
          'p9.catalog.corridor-mode',
          'corridorMode',
          request.corridorMode.code,
        ),
      );
    }
    if (request.exteriorExposurePreference !=
            ApartmentExteriorExposurePreference.any &&
        !constraints.supportedExteriorExposurePreferences
            .contains(request.exteriorExposurePreference)) {
      reasons.add(
        _reason(
          'p9.catalog.exterior-exposure-preference',
          'exteriorExposurePreference',
          request.exteriorExposurePreference.code,
        ),
      );
    }
    if (request.preferDayNightSeparation &&
        !constraints.supportsDayNightSeparation) {
      reasons.add(
        _reason(
          'p9.catalog.day-night-not-supported',
          'preferDayNightSeparation',
          true,
        ),
      );
    }
    return reasons;
  }

  TemplateIncompatibilityReason _reason(
    String code,
    String field,
    Object? actualValue,
  ) =>
      TemplateIncompatibilityReason(
        code: code,
        field: field,
        actualValue: actualValue,
      );

  bool _supportsBalconyKind(
    Set<ApartmentBalconyKind> supported,
    ApartmentBalconyKind requested,
  ) {
    if (requested == ApartmentBalconyKind.none) {
      return supported.contains(ApartmentBalconyKind.none);
    }
    if (requested == ApartmentBalconyKind.either) {
      return supported.contains(ApartmentBalconyKind.either) ||
          supported.contains(ApartmentBalconyKind.balcony) ||
          supported.contains(ApartmentBalconyKind.loggia);
    }
    return supported.contains(requested) ||
        supported.contains(ApartmentBalconyKind.either);
  }

  int _compareTemplates(
    ApartmentTopologyTemplate left,
    ApartmentTopologyTemplate right,
    ApartmentTopologyFamily? preferredFamily,
  ) {
    final leftPreferred = left.family == preferredFamily ? 0 : 1;
    final rightPreferred = right.family == preferredFamily ? 0 : 1;
    var compared = leftPreferred.compareTo(rightPreferred);
    if (compared != 0) {
      return compared;
    }
    compared = _familyOrder(left.family).compareTo(_familyOrder(right.family));
    if (compared != 0) {
      return compared;
    }
    compared = left.stableOrder.compareTo(right.stableOrder);
    if (compared != 0) {
      return compared;
    }
    compared = left.templateId.value.compareTo(right.templateId.value);
    if (compared != 0) {
      return compared;
    }
    return left.templateVersion.compareTo(right.templateVersion);
  }

  int _familyOrder(ApartmentTopologyFamily family) => switch (family) {
        ApartmentTopologyFamily.compact => 0,
        ApartmentTopologyFamily.linear => 1,
        ApartmentTopologyFamily.corner => 2,
        ApartmentTopologyFamily.centralCorridor => 3,
        ApartmentTopologyFamily.corridorSpine => 4,
        ApartmentTopologyFamily.euro => 5,
        ApartmentTopologyFamily.openPlan => 6,
        ApartmentTopologyFamily.splitDayNight => 7,
      };
}
