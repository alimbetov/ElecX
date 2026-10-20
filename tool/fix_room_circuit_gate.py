from pathlib import Path

p = Path('lib/src/features/editor/editor_p2_session.dart')
text = p.read_text()
text = text.replace("\n  static double _axisDistance(SurfacePointMm a, SurfacePointMm b) =>\n      (a.xMm - b.xMm).abs().toDouble() + (a.yMm - b.yMm).abs().toDouble();\n", "\n")
start = text.find('final class _DeleteComponentsCommand implements EditorCommand<EditorP2State> {')
if start == -1:
    raise SystemExit('delete command anchor missing')
end = text.find('\nfinal class _AddRouteCommand implements EditorCommand<EditorP2State> {', start)
if end == -1:
    raise SystemExit('add route command anchor missing')
text = text[:start] + text[end + 1:]
p.write_text(text)

p = Path('test/room_circuit_workflow_test.dart')
text = p.read_text().replace("import 'package:elecx/src/domain/geometry.dart';\n", '')
p.write_text(text)
