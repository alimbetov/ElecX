enum EditorInputMode { mouseKeyboard, stylus, touch }

final class EditorInteractionPolicy {
  const EditorInteractionPolicy({
    required this.inputMode,
    required this.hitTargetPx,
    required this.snapRadiusPx,
    required this.defaultNudgeMm,
    required this.coarseNudgeMm,
    required this.pointerPreviewOffsetPx,
    required this.showPrecisionPad,
    required this.edgeAutoPanInsetPx,
  });

  factory EditorInteractionPolicy.forMode(EditorInputMode mode) =>
      switch (mode) {
        EditorInputMode.mouseKeyboard => const EditorInteractionPolicy(
            inputMode: EditorInputMode.mouseKeyboard,
            hitTargetPx: 18,
            snapRadiusPx: 12,
            defaultNudgeMm: 100,
            coarseNudgeMm: 1000,
            pointerPreviewOffsetPx: 0,
            showPrecisionPad: false,
            edgeAutoPanInsetPx: 28,
          ),
        EditorInputMode.stylus => const EditorInteractionPolicy(
            inputMode: EditorInputMode.stylus,
            hitTargetPx: 26,
            snapRadiusPx: 16,
            defaultNudgeMm: 50,
            coarseNudgeMm: 500,
            pointerPreviewOffsetPx: 0,
            showPrecisionPad: false,
            edgeAutoPanInsetPx: 34,
          ),
        EditorInputMode.touch => const EditorInteractionPolicy(
            inputMode: EditorInputMode.touch,
            hitTargetPx: 44,
            snapRadiusPx: 26,
            defaultNudgeMm: 100,
            coarseNudgeMm: 500,
            pointerPreviewOffsetPx: 36,
            showPrecisionPad: true,
            edgeAutoPanInsetPx: 48,
          ),
      };

  final EditorInputMode inputMode;
  final double hitTargetPx;
  final double snapRadiusPx;
  final int defaultNudgeMm;
  final int coarseNudgeMm;
  final double pointerPreviewOffsetPx;
  final bool showPrecisionPad;
  final double edgeAutoPanInsetPx;

  int nudgeStepMm({bool coarse = false}) =>
      coarse ? coarseNudgeMm : defaultNudgeMm;
}
