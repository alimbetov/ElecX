/// Provider-neutral semantic vocabulary shared by the P9 apartment pipeline.
///
/// These values are application/domain semantics. Localized labels, widget
/// state and platform presentation must never be used as persisted codes.
enum ApartmentTopologyFamily {
  compact,
  linear,
  corner,
  centralCorridor,
  corridorSpine,
  euro,
  openPlan,
  splitDayNight,
}

enum ApartmentKitchenMode { separate, kitchenLiving, openPlan }

enum ApartmentCorridorMode { auto, compact, central, minimal }

enum ApartmentExteriorExposurePreference {
  any,
  oneSide,
  corner,
  oppositeSides,
}

enum ApartmentBalconyKind { none, balcony, loggia, either }

enum ApartmentAreaBasis { interiorNetExcludingExteriorAppendages }

enum SpaceAreaParticipation { requestedInteriorArea, exteriorAppendage }

extension ApartmentTopologyFamilyCode on ApartmentTopologyFamily {
  String get code => switch (this) {
        ApartmentTopologyFamily.compact => 'compact',
        ApartmentTopologyFamily.linear => 'linear',
        ApartmentTopologyFamily.corner => 'corner',
        ApartmentTopologyFamily.centralCorridor => 'centralCorridor',
        ApartmentTopologyFamily.corridorSpine => 'corridorSpine',
        ApartmentTopologyFamily.euro => 'euro',
        ApartmentTopologyFamily.openPlan => 'openPlan',
        ApartmentTopologyFamily.splitDayNight => 'splitDayNight',
      };
}

extension ApartmentKitchenModeCode on ApartmentKitchenMode {
  String get code => switch (this) {
        ApartmentKitchenMode.separate => 'separate',
        ApartmentKitchenMode.kitchenLiving => 'kitchenLiving',
        ApartmentKitchenMode.openPlan => 'openPlan',
      };
}

extension ApartmentCorridorModeCode on ApartmentCorridorMode {
  String get code => switch (this) {
        ApartmentCorridorMode.auto => 'auto',
        ApartmentCorridorMode.compact => 'compact',
        ApartmentCorridorMode.central => 'central',
        ApartmentCorridorMode.minimal => 'minimal',
      };
}

extension ApartmentExteriorExposurePreferenceCode
    on ApartmentExteriorExposurePreference {
  String get code => switch (this) {
        ApartmentExteriorExposurePreference.any => 'any',
        ApartmentExteriorExposurePreference.oneSide => 'oneSide',
        ApartmentExteriorExposurePreference.corner => 'corner',
        ApartmentExteriorExposurePreference.oppositeSides => 'oppositeSides',
      };
}

extension ApartmentBalconyKindCode on ApartmentBalconyKind {
  String get code => switch (this) {
        ApartmentBalconyKind.none => 'none',
        ApartmentBalconyKind.balcony => 'balcony',
        ApartmentBalconyKind.loggia => 'loggia',
        ApartmentBalconyKind.either => 'either',
      };
}

extension ApartmentAreaBasisCode on ApartmentAreaBasis {
  String get code => switch (this) {
        ApartmentAreaBasis.interiorNetExcludingExteriorAppendages =>
          'interiorNetExcludingExteriorAppendages',
      };
}
