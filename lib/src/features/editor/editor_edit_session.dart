/// Unified transaction lifecycle for direct manipulation in the spatial editor.
///
/// Mouse, keyboard, touch, stylus and precision-pad adapters must translate
/// device events into calls to this contract instead of mutating editor state
/// independently.
enum EditorEditSessionPhase { idle, previewing, invalid, committed, cancelled }

abstract interface class EditorEditSession<TPreview> {
  EditorEditSessionPhase get phase;

  bool get active =>
      phase == EditorEditSessionPhase.previewing ||
      phase == EditorEditSessionPhase.invalid;

  bool begin();

  TPreview? get previewState;

  bool validate();

  bool commit();

  void cancel();
}

enum EditorInputModality { mouse, keyboard, touch, stylus, precisionPad }

/// Screen-space acquisition/release profile. Callers convert these values to
/// world millimetres through the active viewport before invoking geometry
/// engines.
final class EditorSnapProfile {
  const EditorSnapProfile({required this.capturePx, required this.releasePx})
      : assert(capturePx > 0),
        assert(releasePx >= capturePx);

  final double capturePx;
  final double releasePx;

  static EditorSnapProfile forModality(EditorInputModality modality) =>
      switch (modality) {
        EditorInputModality.mouse => const EditorSnapProfile(
            capturePx: 8,
            releasePx: 14,
          ),
        EditorInputModality.keyboard => const EditorSnapProfile(
            capturePx: 6,
            releasePx: 10,
          ),
        EditorInputModality.touch => const EditorSnapProfile(
            capturePx: 20,
            releasePx: 30,
          ),
        EditorInputModality.stylus => const EditorSnapProfile(
            capturePx: 7,
            releasePx: 12,
          ),
        EditorInputModality.precisionPad => const EditorSnapProfile(
            capturePx: 10,
            releasePx: 16,
          ),
      };
}
