from pathlib import Path

path = Path('lib/src/features/editor/plan_geometry_editor_actions.dart')
text = path.read_text()

component_old = """      final context = contextFor(component.surface);\n      if (context == null || !containsPoint(component.position, context)) {\n        return false;\n      }\n"""
component_new = component_old

route_old = """        final context = contextFor(segment.surface);\n        if (context == null ||\n            !NormativeRouteEngine.validate(\n              points: segment.points,\n              context: context,\n            ).isValid) {\n          return false;\n        }\n"""
route_new = """        final context = contextFor(segment.surface);\n        if (!NormativeRouteEngine.validate(\n          points: segment.points,\n          context: context,\n        ).isValid) {\n          return false;\n        }\n"""

if text.count(component_old) != 1:
    raise SystemExit('component context anchor missing')
if text.count(route_old) != 1:
    raise SystemExit('route context anchor missing')
path.write_text(text.replace(component_old, component_new, 1).replace(route_old, route_new, 1))
