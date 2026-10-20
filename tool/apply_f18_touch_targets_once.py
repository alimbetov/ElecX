from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'anchor not found in {path}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1))

replace_once(
    'lib/src/features/editor/editor_ui_tokens.dart',
    "  static const double commandBarHeight = 48;\n",
    "  static const double commandBarHeight = 56;\n",
)
replace_once(
    'lib/src/features/editor/editor_ui_tokens.dart',
    "  static const double commandTarget = 40;\n",
    "  static const double commandTarget = 48;\n",
)
replace_once(
    'lib/src/features/editor/editor_ui_tokens.dart',
    "  static const double compactCommandTarget = 44;\n  static const double minimumTouchTarget = 44;\n",
    "  static const double compactCommandTarget = 48;\n  static const double minimumTouchTarget = 48;\n",
)

replace_once(
    'lib/src/features/editor/canvas_viewport_navigator.dart',
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/material.dart';\n\nimport 'editor_ui_tokens.dart';\n",
)
replace_once(
    'lib/src/features/editor/canvas_viewport_navigator.dart',
    "        constraints: const BoxConstraints.tightFor(width: 34, height: 34),\n",
    "        constraints: const BoxConstraints.tightFor(\n          width: EditorUiTokens.minimumTouchTarget,\n          height: EditorUiTokens.minimumTouchTarget,\n        ),\n",
)

replace_once(
    'lib/src/features/editor/canvas_component_controls.dart',
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/material.dart';\n\nimport 'editor_ui_tokens.dart';\n",
)
replace_once(
    'lib/src/features/editor/canvas_component_controls.dart',
    "                PopupMenuButton<int>(\n                  tooltip: 'Шаг перемещения',\n",
    "                SizedBox(\n                  height: EditorUiTokens.minimumTouchTarget,\n                  child: PopupMenuButton<int>(\n                  tooltip: 'Шаг перемещения',\n",
)
replace_once(
    'lib/src/features/editor/canvas_component_controls.dart',
    "                  child: Chip(\n                    visualDensity: VisualDensity.compact,\n                    label: Text('$stepMm мм'),\n                  ),\n                ),\n                const SizedBox(width: 4),\n                IconButton(\n",
    "                  child: Chip(\n                    visualDensity: VisualDensity.compact,\n                    label: Text('$stepMm мм'),\n                  ),\n                  ),\n                ),\n                const SizedBox(width: 4),\n                IconButton(\n",
)
replace_once(
    'lib/src/features/editor/canvas_component_controls.dart',
    "                  visualDensity: VisualDensity.compact,\n                  color: scheme.error,\n",
    "                  visualDensity: VisualDensity.standard,\n                  constraints: const BoxConstraints.tightFor(\n                    width: EditorUiTokens.minimumTouchTarget,\n                    height: EditorUiTokens.minimumTouchTarget,\n                  ),\n                  color: scheme.error,\n",
)
replace_once(
    'lib/src/features/editor/canvas_component_controls.dart',
    "        constraints: const BoxConstraints.tightFor(width: 34, height: 34),\n",
    "        constraints: const BoxConstraints.tightFor(\n          width: EditorUiTokens.minimumTouchTarget,\n          height: EditorUiTokens.minimumTouchTarget,\n        ),\n",
)

Path('test/f18_touch_target_acceptance_test.dart').write_text(r'''import 'package:elecx/src/features/editor/canvas_component_controls.dart';
import 'package:elecx/src/features/editor/canvas_viewport_navigator.dart';
import 'package:elecx/src/features/editor/editor_controller.dart';
import 'package:elecx/src/features/editor/editor_p2_session.dart';
import 'package:elecx/src/features/editor/editor_ui_tokens.dart';
import 'package:elecx/src/features/editor/unified_icon_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('F18 shared target contract is 48 logical pixels', () {
    expect(EditorUiTokens.minimumTouchTarget, greaterThanOrEqualTo(48));
    expect(EditorUiTokens.commandTarget, greaterThanOrEqualTo(48));
    expect(EditorUiTokens.compactCommandTarget, greaterThanOrEqualTo(48));
    expect(
      EditorUiTokens.commandBarHeight,
      greaterThanOrEqualTo(EditorUiTokens.compactCommandTarget + 8),
    );
  });

  testWidgets('F18 viewport navigator exposes 48dp hit regions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CanvasViewportNavigator(
              onPan: (_, __) {},
              onZoomIn: () {},
              onZoomOut: () {},
              onFit: () {},
            ),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byTooltip('Сместить фокус вверх'));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('F18 component controls expose 48dp move and delete targets',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CanvasComponentControls(
              label: 'Розетка',
              stepMm: 100,
              onStepChanged: (_) {},
              onMove: (_, __) {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    );
    final move = tester.getSize(find.byTooltip('Влево на 100 мм'));
    final delete = tester.getSize(find.byTooltip('Удалить компонент'));
    expect(move.width, greaterThanOrEqualTo(48));
    expect(move.height, greaterThanOrEqualTo(48));
    expect(delete.width, greaterThanOrEqualTo(48));
    expect(delete.height, greaterThanOrEqualTo(48));
  });

  testWidgets('F18 editor toolbar target fits inside command bar', (tester) async {
    final controller = EditorController.demo();
    addTearDown(() {
      controller.disposeP2State();
      controller.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnifiedEditorIconToolbar(controller: controller, compact: true),
        ),
      ),
    );
    await tester.pump();
    final button = tester.getSize(find.byTooltip('Выбор (V)'));
    expect(button.width, greaterThanOrEqualTo(48));
    expect(button.height, greaterThanOrEqualTo(48));
    expect(
      tester.getSize(find.byType(UnifiedEditorIconToolbar)).height,
      greaterThanOrEqualTo(56),
    );
  });
}
''')
