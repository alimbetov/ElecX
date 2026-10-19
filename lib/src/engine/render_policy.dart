enum RenderLod {
  site,
  building,
  level,
  room,
  detail,
}

final class RenderPolicy {
  const RenderPolicy._();

  static RenderLod lodForWorldUnitsPerPixel(double mmPerPixel) {
    if (mmPerPixel <= 0) {
      throw ArgumentError.value(mmPerPixel, 'mmPerPixel', 'Must be positive.');
    }
    if (mmPerPixel >= 5000) return RenderLod.site;
    if (mmPerPixel >= 1000) return RenderLod.building;
    if (mmPerPixel >= 200) return RenderLod.level;
    if (mmPerPixel >= 25) return RenderLod.room;
    return RenderLod.detail;
  }

  static bool showRoomLabels(RenderLod lod) =>
      lod.index >= RenderLod.level.index;

  static bool showOpenings(RenderLod lod) => lod.index >= RenderLod.room.index;

  static bool showElectricalSymbols(RenderLod lod) =>
      lod.index >= RenderLod.room.index;

  static bool showFineDimensions(RenderLod lod) => lod == RenderLod.detail;

  static bool showMinorGrid(RenderLod lod) => lod == RenderLod.detail;
}
