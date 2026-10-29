import 'package:elecx/src/domain/apartment_topology/apartment_geometry.dart';

/// Run as both a Dart program and compiled JavaScript. Small footprints near
/// the canonical Site coordinate limit must preserve exact area and winding.
void main() {
  for (final origin in [-999999980, 0, 999999980]) {
    final polygon = RectilinearPolygonMm.rectangle(
        xMm: origin, yMm: origin, widthMm: 10, heightMm: 10);
    if (polygon.areaMm2 != 100 || polygon.vertices.length != 4) {
      throw StateError('Site area lost integer precision at $origin mm.');
    }
    final reversed = RectilinearPolygonMm.normalized(polygon.vertices.reversed);
    if (reversed.stableSerialization != polygon.stableSerialization) {
      throw StateError('Site winding normalization changed at $origin mm.');
    }
  }
  // Console output is intentional for this standalone VM/JavaScript probe.
  // ignore: avoid_print
  print('P10.9 Site coordinate precision PASS');
}
