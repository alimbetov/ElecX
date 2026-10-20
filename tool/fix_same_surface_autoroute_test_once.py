from pathlib import Path
import re

p = Path('test/editor_p2_session_test.dart')
text = p.read_text()
pattern = re.compile(
    r"  test\('same-surface AUTO uses project context to detour around opening', \(\) \{\n"
    r"    late final RouteNormativeContext context;\n"
    r"    final session = EditorP2Session\(\n"
    r"      routeContextResolver: \(surface\) \{\n"
    r"        context = RouteNormativeContext\(\n"
    r"          surface: surface,\n"
    r"          widthMm: 3500,\n"
    r"          heightMm: 2500,\n"
    r"          edgeClearanceMm: 0,\n"
    r"          obstacles: const \[\n"
    r"            RouteObstacleMm\(\n"
    r"              id: 'window',\n"
    r"              leftMm: 1400,\n"
    r"              topMm: 700,\n"
    r"              rightMm: 2100,\n"
    r"              bottomMm: 1300,\n"
    r"            \),\n"
    r"          \],\n"
    r"        \);\n"
    r"        return context;\n"
    r"      \},\n"
    r"    \);"
)
replacement = """  test('same-surface AUTO uses project context to detour around opening', () {\n    final context = RouteNormativeContext(\n      surface: wall,\n      widthMm: 3500,\n      heightMm: 2500,\n      edgeClearanceMm: 0,\n      obstacles: const [\n        RouteObstacleMm(\n          id: 'window',\n          leftMm: 1400,\n          topMm: 700,\n          rightMm: 2100,\n          bottomMm: 1300,\n        ),\n      ],\n    );\n    final session = EditorP2Session(\n      routeContextResolver: (_) => context,\n    );"""
text, count = pattern.subn(replacement, text)
if count != 1:
    raise RuntimeError(f'expected one same-surface fixture, got {count}')
p.write_text(text)
