import 'dart:math' as math;

import '../../../../domain/apartment_topology.dart';
import '../../../../domain/apartment_topology/apartment_vector_scene.dart';

/// Presentation-only responsive classes. They never participate in P9
/// candidate/scene fingerprints.
enum ElecXResponsiveWidthClass { compact, medium, expanded, large }

enum ApartmentPreviewInputSignal {
  mouseClick,
  keyboardActivate,
  touchTap,
  stylusTap,
}

enum ApartmentPreviewSemanticOperation { selectCandidate }

ApartmentPreviewSemanticOperation semanticOperationFor(
  ApartmentPreviewInputSignal signal,
) =>
    switch (signal) {
      ApartmentPreviewInputSignal.mouseClick ||
      ApartmentPreviewInputSignal.keyboardActivate ||
      ApartmentPreviewInputSignal.touchTap ||
      ApartmentPreviewInputSignal.stylusTap =>
        ApartmentPreviewSemanticOperation.selectCandidate,
    };

ElecXResponsiveWidthClass responsiveWidthClassFor(double logicalWidth) {
  if (!logicalWidth.isFinite || logicalWidth < 0) {
    throw ArgumentError.value(logicalWidth, 'logicalWidth', 'Must be finite.');
  }
  if (logicalWidth < 600) return ElecXResponsiveWidthClass.compact;
  if (logicalWidth < 1024) return ElecXResponsiveWidthClass.medium;
  if (logicalWidth < 1440) return ElecXResponsiveWidthClass.expanded;
  return ElecXResponsiveWidthClass.large;
}

final class ApartmentPreviewLayoutPolicy {
  const ApartmentPreviewLayoutPolicy({
    required this.widthClass,
    required this.showInCanvasLabels,
    required this.summaryVisible,
    required this.actionsVisible,
    required this.animationsEnabled,
  });

  factory ApartmentPreviewLayoutPolicy.resolve({
    required double logicalWidth,
    required double textScaleFactor,
    required bool animationsDisabled,
  }) {
    if (!textScaleFactor.isFinite || textScaleFactor <= 0) {
      throw ArgumentError.value(
        textScaleFactor,
        'textScaleFactor',
        'Must be finite and positive.',
      );
    }
    return ApartmentPreviewLayoutPolicy(
      widthClass: responsiveWidthClassFor(logicalWidth),
      showInCanvasLabels: textScaleFactor < 1.75,
      summaryVisible: true,
      actionsVisible: true,
      animationsEnabled: !animationsDisabled,
    );
  }

  final ElecXResponsiveWidthClass widthClass;
  final bool showInCanvasLabels;
  final bool summaryVisible;
  final bool actionsVisible;
  final bool animationsEnabled;
}

/// Bounded transient viewport state shared by mouse/touch/keyboard adapters.
/// It is intentionally detached from candidate/scene identity.
final class PreviewViewportState {
  PreviewViewportState({
    required this.scale,
    required this.translationX,
    required this.translationY,
  }) {
    _validate(scale, translationX, translationY);
  }

  factory PreviewViewportState.initial() => PreviewViewportState(
        scale: 1,
        translationX: 0,
        translationY: 0,
      );

  static const double minScale = 0.25;
  static const double maxScale = 8;
  static const double maxTranslation = 1000000;

  final double scale;
  final double translationX;
  final double translationY;

  PreviewViewportState zoomIn({double anchorX = 0, double anchorY = 0}) =>
      zoomAroundAnchor(1.25, anchorX: anchorX, anchorY: anchorY);

  PreviewViewportState zoomOut({double anchorX = 0, double anchorY = 0}) =>
      zoomAroundAnchor(0.8, anchorX: anchorX, anchorY: anchorY);

  PreviewViewportState zoomAroundAnchor(
    double factor, {
    required double anchorX,
    required double anchorY,
  }) {
    if (!factor.isFinite ||
        factor <= 0 ||
        !anchorX.isFinite ||
        !anchorY.isFinite) {
      throw ArgumentError('Zoom inputs must be finite and positive.');
    }
    final nextScale = (scale * factor).clamp(minScale, maxScale).toDouble();
    final applied = nextScale / scale;
    final nextX = anchorX - (anchorX - translationX) * applied;
    final nextY = anchorY - (anchorY - translationY) * applied;
    return PreviewViewportState(
      scale: nextScale,
      translationX: _clampTranslation(nextX),
      translationY: _clampTranslation(nextY),
    );
  }

  PreviewViewportState pan({required double dx, required double dy}) {
    if (!dx.isFinite || !dy.isFinite) {
      throw ArgumentError('Pan delta must be finite.');
    }
    return PreviewViewportState(
      scale: scale,
      translationX: _clampTranslation(translationX + dx),
      translationY: _clampTranslation(translationY + dy),
    );
  }

  PreviewViewportState zoomToFit() => PreviewViewportState.initial();

  PreviewViewportState resetView() => PreviewViewportState.initial();

  static void _validate(double scale, double x, double y) {
    if (!scale.isFinite ||
        !x.isFinite ||
        !y.isFinite ||
        scale < minScale ||
        scale > maxScale ||
        x.abs() > maxTranslation ||
        y.abs() > maxTranslation) {
      throw ArgumentError('Viewport state is outside bounded finite limits.');
    }
  }
}

double _clampTranslation(double value) => math.max(
    -PreviewViewportState.maxTranslation,
    math.min(PreviewViewportState.maxTranslation, value));

final class ApartmentPreviewInteractionState {
  const ApartmentPreviewInteractionState({
    required this.selectedCandidateFingerprint,
    required this.viewport,
    required this.previewPanCaptured,
  });

  factory ApartmentPreviewInteractionState.initial() =>
      ApartmentPreviewInteractionState(
        selectedCandidateFingerprint: null,
        viewport: PreviewViewportState.initial(),
        previewPanCaptured: false,
      );

  final String? selectedCandidateFingerprint;
  final PreviewViewportState viewport;
  final bool previewPanCaptured;

  bool get carouselSwipeEnabled => !previewPanCaptured;

  ApartmentPreviewInteractionState selectCandidate(
    String candidateFingerprint, {
    required ApartmentPreviewInputSignal inputSignal,
  }) {
    if (candidateFingerprint.trim().isEmpty) {
      throw ArgumentError.value(candidateFingerprint, 'candidateFingerprint');
    }
    if (semanticOperationFor(inputSignal) !=
        ApartmentPreviewSemanticOperation.selectCandidate) {
      throw StateError('Unsupported semantic input operation.');
    }
    return ApartmentPreviewInteractionState(
      selectedCandidateFingerprint: candidateFingerprint,
      viewport: viewport,
      previewPanCaptured: previewPanCaptured,
    );
  }

  ApartmentPreviewInteractionState withViewport(PreviewViewportState next) =>
      ApartmentPreviewInteractionState(
        selectedCandidateFingerprint: selectedCandidateFingerprint,
        viewport: next,
        previewPanCaptured: previewPanCaptured,
      );

  ApartmentPreviewInteractionState beginPreviewPan() =>
      ApartmentPreviewInteractionState(
        selectedCandidateFingerprint: selectedCandidateFingerprint,
        viewport: viewport,
        previewPanCaptured: true,
      );

  ApartmentPreviewInteractionState endPreviewPan() =>
      ApartmentPreviewInteractionState(
        selectedCandidateFingerprint: selectedCandidateFingerprint,
        viewport: viewport,
        previewPanCaptured: false,
      );
}

enum ApartmentPreviewLocale { ru, en }

final class ApartmentPreviewDescriptionFormatter {
  const ApartmentPreviewDescriptionFormatter();

  String describe(
    ApartmentPreviewSummary summary, {
    required ApartmentPreviewLocale locale,
  }) =>
      switch (locale) {
        ApartmentPreviewLocale.ru => _ru(summary),
        ApartmentPreviewLocale.en => _en(summary),
      };

  String _ru(ApartmentPreviewSummary summary) {
    final room = '${summary.habitableRoomCount}-комнатная';
    final family = _familyRu(summary.family);
    final interior = _formatArea(summary.interiorAreaDm2, decimalComma: true);
    final appendage =
        _formatArea(summary.exteriorAppendageAreaDm2, decimalComma: true);
    final score = (summary.scoreBp + 50) ~/ 100;
    return <String>[
      '$room $family квартира',
      'внутренняя площадь $interior м²',
      if (summary.exteriorAppendageAreaDm2 > 0) 'балконы/лоджии $appendage м²',
      _kitchenRu(summary.kitchenMode),
      'ванных: ${summary.bathroomCount}',
      'оценка $score процентов',
    ].join(', ');
  }

  String _en(ApartmentPreviewSummary summary) {
    final family = _familyEn(summary.family);
    final interior = _formatArea(summary.interiorAreaDm2, decimalComma: false);
    final appendage =
        _formatArea(summary.exteriorAppendageAreaDm2, decimalComma: false);
    final score = (summary.scoreBp + 50) ~/ 100;
    return <String>[
      '${summary.habitableRoomCount}-room $family apartment',
      '$interior square metres interior area',
      if (summary.exteriorAppendageAreaDm2 > 0)
        '$appendage square metres balcony/loggia area',
      _kitchenEn(summary.kitchenMode),
      '${summary.bathroomCount} bathroom${summary.bathroomCount == 1 ? '' : 's'}',
      'score $score percent',
    ].join(', ');
  }
}

String _formatArea(int dm2, {required bool decimalComma}) {
  final whole = dm2 ~/ 100;
  final fraction = dm2.abs() % 100;
  if (fraction == 0) return '$whole';
  final separator = decimalComma ? ',' : '.';
  if (fraction % 10 == 0) return '$whole$separator${fraction ~/ 10}';
  return '$whole$separator${fraction.toString().padLeft(2, '0')}';
}

String _familyEn(ApartmentTopologyFamily family) => switch (family) {
      ApartmentTopologyFamily.compact => 'compact',
      ApartmentTopologyFamily.linear => 'linear',
      ApartmentTopologyFamily.corner => 'corner',
      ApartmentTopologyFamily.centralCorridor => 'central-corridor',
      ApartmentTopologyFamily.corridorSpine => 'corridor-spine',
      ApartmentTopologyFamily.euro => 'euro',
      ApartmentTopologyFamily.openPlan => 'open-plan',
      ApartmentTopologyFamily.splitDayNight => 'split day/night',
    };

String _familyRu(ApartmentTopologyFamily family) => switch (family) {
      ApartmentTopologyFamily.compact => 'компактная',
      ApartmentTopologyFamily.linear => 'линейная',
      ApartmentTopologyFamily.corner => 'угловая',
      ApartmentTopologyFamily.centralCorridor => 'с центральным коридором',
      ApartmentTopologyFamily.corridorSpine => 'с коридорным ядром',
      ApartmentTopologyFamily.euro => 'евроформата',
      ApartmentTopologyFamily.openPlan => 'открытой планировки',
      ApartmentTopologyFamily.splitDayNight => 'с разделением день/ночь',
    };

String _kitchenEn(ApartmentKitchenMode mode) => switch (mode) {
      ApartmentKitchenMode.separate => 'separate kitchen',
      ApartmentKitchenMode.kitchenLiving => 'kitchen-living room',
      ApartmentKitchenMode.openPlan => 'open-plan kitchen',
    };

String _kitchenRu(ApartmentKitchenMode mode) => switch (mode) {
      ApartmentKitchenMode.separate => 'отдельная кухня',
      ApartmentKitchenMode.kitchenLiving => 'кухня-гостиная',
      ApartmentKitchenMode.openPlan => 'кухня открытой планировки',
    };
