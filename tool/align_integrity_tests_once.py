from pathlib import Path


def replace_once(path, old, new, label):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one match, got {count}')
    p.write_text(text.replace(old, new, 1))

replace_once(
    'test/cable_route_constraints_test.dart',
    '''          route.id: CableRouteConstraints(\n            lockedSegments: {0},\n            mandatoryWaypoints: const [''',
    '''          route.id: CableRouteConstraints(\n            mandatoryWaypoints: const [''',
    'reconciliation test must use unlocked segment',
)
replace_once(
    'test/cable_route_constraints_test.dart',
    '''    expect(session.routes.single.segments.single.points, hasLength(4));\n    expect(session.routeConstraintsFor(route.id).isSegmentLocked(0), isTrue);\n    expect(''',
    '''    expect(session.routes.single.segments.single.points, hasLength(4));\n    expect(session.routeConstraintsFor(route.id).isSegmentLocked(0), isFalse);\n    expect(''',
    'reconciliation lock expectation',
)
replace_once(
    'test/normative_route_engine_test.dart',
    '''    expect(candidates, hasLength(2));\n    expect(candidates.first.validation.isValid, isTrue);\n    expect(candidates.last.validation.isValid, isFalse);\n    expect(candidates.first.points[1].xMm, 200);\n    expect(candidates.first.points[1].yMm, 1400);''',
    '''    expect(candidates.length, greaterThanOrEqualTo(2));\n    expect(candidates.first.validation.isValid, isTrue);\n    expect(\n      candidates.any((candidate) => !candidate.validation.isValid),\n      isTrue,\n    );\n    expect(\n      candidates.first.points.every(\n        (point) => !context.obstacles.single.contains(point),\n      ),\n      isTrue,\n    );''',
    'auto route behavioral expectation',
)
