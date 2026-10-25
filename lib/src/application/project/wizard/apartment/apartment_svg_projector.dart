import '../../../../domain/apartment_topology/apartment_vector_scene.dart';
import 'p9_failure.dart';

final class ApartmentSvgProjectionResult {
  ApartmentSvgProjectionResult({
    required this.svg,
    required Iterable<P9Failure> failures,
  }) : failures = List.unmodifiable(failures);

  final String? svg;
  final List<P9Failure> failures;

  bool get accepted =>
      svg != null && failures.every((failure) => !failure.isBlocker);
}

/// Deterministic inert SVG projection of a P9.8 vector scene.
///
/// The SVG is a disposable presentation artifact. No P9 stage may parse it to
/// reconstruct authoritative geometry or candidate identity.
final class ApartmentSvgProjector {
  const ApartmentSvgProjector();

  static const String projectorVersion = 'p9.svg.v1';

  ApartmentSvgProjectionResult project(ApartmentTopologyVectorScene scene) {
    if (scene.widthUnits <= 0 ||
        scene.heightUnits <= 0 ||
        scene.sceneFingerprint.trim().isEmpty ||
        scene.sourceGeometryFingerprint.trim().isEmpty) {
      return ApartmentSvgProjectionResult(
        svg: null,
        failures: [_failure('p9.render.serialization-failure')],
      );
    }

    try {
      final out = StringBuffer()
        ..write('<svg viewBox="0 0 ${scene.widthUnits} ${scene.heightUnits}"')
        ..write(' data-projector-version="$projectorVersion"')
        ..write(' data-renderer-version="${_escape(scene.rendererVersion)}"')
        ..write(' data-scene-fingerprint="${_escape(scene.sceneFingerprint)}"')
        ..write(' aria-hidden="true" focusable="false">');

      for (final element in scene.elements) {
        _writeElement(out, element);
      }
      out.write('</svg>');
      final svg = out.toString();
      if (!_isInert(svg)) {
        return ApartmentSvgProjectionResult(
          svg: null,
          failures: [_failure('p9.render.serialization-failure')],
        );
      }
      return ApartmentSvgProjectionResult(svg: svg, failures: const []);
    } catch (_) {
      return ApartmentSvgProjectionResult(
        svg: null,
        failures: [_failure('p9.render.serialization-failure')],
      );
    }
  }

  void _writeElement(StringBuffer out, ApartmentVectorElement element) {
    final role = _escape(element.role.code);
    final key = _escape(element.generationKey);
    if (element is ApartmentVectorPolygonElement) {
      final points = element.points
          .map((point) => '${point.xUnits},${point.yUnits}')
          .join(' ');
      out
        ..write('<polygon class="p9-role-$role"')
        ..write(' data-key="$key"')
        ..write(' points="$points"/>');
      return;
    }
    if (element is ApartmentVectorLineElement) {
      out
        ..write('<line class="p9-role-$role"')
        ..write(' data-key="$key"')
        ..write(' x1="${element.start.xUnits}"')
        ..write(' y1="${element.start.yUnits}"')
        ..write(' x2="${element.end.xUnits}"')
        ..write(' y2="${element.end.yUnits}"/>');
      return;
    }
    if (element is ApartmentVectorMarkerElement) {
      out
        ..write('<circle class="p9-role-$role"')
        ..write(' data-key="$key"')
        ..write(' data-marker-kind="${_escape(element.markerKind)}"')
        ..write(' cx="${element.anchor.xUnits}"')
        ..write(' cy="${element.anchor.yUnits}" r="2"/>');
      return;
    }
    if (element is ApartmentVectorLabelAnchorElement) {
      out
        ..write('<circle class="p9-role-$role"')
        ..write(' data-key="$key"')
        ..write(' data-label-key="${_escape(element.semanticLabelKey)}"')
        ..write(' cx="${element.anchor.xUnits}"')
        ..write(' cy="${element.anchor.yUnits}" r="0"/>');
      return;
    }
    if (element is ApartmentVectorMetadataElement) {
      out
        ..write('<metadata data-role="$role"')
        ..write(' data-key="$key"')
        ..write(' data-value="${_escape(element.value)}"/>');
      return;
    }
    throw StateError('Unsupported vector element.');
  }
}

bool _isInert(String svg) {
  final lower = svg.toLowerCase();
  if (lower.contains('<script') ||
      lower.contains('<foreignobject') ||
      lower.contains('javascript:') ||
      lower.contains('data:text/html') ||
      lower.contains('@import') ||
      lower.contains(' href=') ||
      lower.contains(' xlink:href=')) {
    return false;
  }
  final eventAttribute = RegExp(r'\son[a-z]+\s*=', caseSensitive: false);
  return !eventAttribute.hasMatch(svg);
}

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

P9Failure _failure(String code) => P9Failure(
      code: code,
      stage: P9FailureStage.rendering,
      severity: P9FailureSeverity.blocker,
    );
