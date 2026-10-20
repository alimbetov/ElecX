from pathlib import Path

p = Path('test/f17_scene_accessibility_test.dart')
text = p.read_text()
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
      find.semantics.byLabel('${source.label}, электрический компонент'),
      findsOne,
    );
    expect(
      find.semantics.byLabel(
        'Кабельная трасса ${controller.p2.routes.single.id}',
      ),
      findsOne,
    );
'''
if old not in text:
    raise SystemExit('F17 semantics finder oracle anchor not found')
text = text.replace(old, new, 1)
p.write_text(text)
