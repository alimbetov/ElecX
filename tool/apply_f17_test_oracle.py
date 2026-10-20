from pathlib import Path

p = Path('test/f17_scene_accessibility_test.dart')
text = p.read_text()
text = text.replace(
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/material.dart';\nimport 'package:flutter/semantics.dart';\n",
    1,
)
text = text.replace(
    "void main() {\n",
    r'''bool _semanticTreeContainsLabel(WidgetTester tester, String label) {
  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root == null) return false;
  bool visit(SemanticsNode node) {
    if (node.getSemanticsData().label == label) return true;
    for (final child in node.getChildrenAsList()) {
      if (visit(child)) return true;
    }
    return false;
  }
  return visit(root);
}

void main() {
''',
    1,
)
old = r'''    expect(
      find.bySemanticsLabel('${source.label}, электрический компонент'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Кабельная трасса ${controller.p2.routes.single.id}',
      ),
      findsOneWidget,
    );
'''
new = r'''    expect(
      _semanticTreeContainsLabel(
        tester,
        '${source.label}, электрический компонент',
      ),
      isTrue,
    );
    expect(
      _semanticTreeContainsLabel(
        tester,
        'Кабельная трасса ${controller.p2.routes.single.id}',
      ),
      isTrue,
    );
'''
if old not in text:
    raise SystemExit('F17 semantics finder oracle anchor not found')
text = text.replace(old, new, 1)
p.write_text(text)
