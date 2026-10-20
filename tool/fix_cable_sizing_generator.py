from pathlib import Path

p = Path('tool/apply_cable_sizing_evidence_once.py')
text = p.read_text()
old = '''# Power circuit routes carry power medium.\nreplace_once(path,\n"      segments: segments,\\n      cableType: cableType,\\n    );\\n",\n"      segments: segments,\\n      cableType: cableType,\\n      medium: RouteMediumProfile.acPower,\\n    );\\n")\n'''
new = '''# Power circuit routes carry power medium only for board -> load groups.\nreplace_once(path,\n"    final route = ElectricalCableRoute(\\n      id: routeId.$1,\\n      source: ElectricalEndpointRef(\\n        componentId: board.id,\\n        portId: pair.sourcePort.id,\\n      ),\\n      target: ElectricalEndpointRef(\\n        componentId: load.id,\\n        portId: pair.targetPort.id,\\n      ),\\n      segments: segments,\\n      cableType: cableType,\\n    );\\n",\n"    final route = ElectricalCableRoute(\\n      id: routeId.$1,\\n      source: ElectricalEndpointRef(\\n        componentId: board.id,\\n        portId: pair.sourcePort.id,\\n      ),\\n      target: ElectricalEndpointRef(\\n        componentId: load.id,\\n        portId: pair.targetPort.id,\\n      ),\\n      segments: segments,\\n      cableType: cableType,\\n      medium: RouteMediumProfile.acPower,\\n    );\\n")\n'''
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected one generator route-medium block, found {count}')
p.write_text(text.replace(old, new, 1))
