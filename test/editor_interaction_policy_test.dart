import 'package:elecx/src/features/editor/editor_interaction_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('touch policy uses larger hit and snap targets than mouse', () {
    final mouse = EditorInteractionPolicy.forMode(
      EditorInputMode.mouseKeyboard,
    );
    final touch = EditorInteractionPolicy.forMode(EditorInputMode.touch);

    expect(touch.hitTargetPx, greaterThan(mouse.hitTargetPx));
    expect(touch.snapRadiusPx, greaterThan(mouse.snapRadiusPx));
    expect(touch.showPrecisionPad, isTrue);
    expect(touch.pointerPreviewOffsetPx, greaterThan(0));
  });

  test('desktop coarse nudge is larger than normal nudge', () {
    final policy = EditorInteractionPolicy.forMode(
      EditorInputMode.mouseKeyboard,
    );

    expect(policy.nudgeStepMm(coarse: true), greaterThan(policy.nudgeStepMm()));
  });
}
