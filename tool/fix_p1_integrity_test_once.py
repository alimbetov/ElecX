from pathlib import Path

path = Path('test/p1_integrity_hardening_test.dart')
text = path.read_text()
old = """      boundary: const [\n        SurfacePointMm(0, 0),\n        SurfacePointMm(10000, 0),\n        SurfacePointMm(10000, 6000),\n        SurfacePointMm(7000, 6000),\n        SurfacePointMm(7000, 1500),\n        SurfacePointMm(3000, 1500),\n        SurfacePointMm(3000, 6000),\n        SurfacePointMm(0, 6000),\n      ],\n"""
new = """      boundary: const [\n        SurfacePointMm(0, 1500),\n        SurfacePointMm(1000, 1500),\n        SurfacePointMm(1000, 3000),\n        SurfacePointMm(3000, 3000),\n        SurfacePointMm(3000, 1500),\n        SurfacePointMm(10000, 1500),\n        SurfacePointMm(10000, 6000),\n        SurfacePointMm(0, 6000),\n      ],\n"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected one F02 fixture anchor, found {count}')
path.write_text(text.replace(old, new, 1))
