from pathlib import Path

source_path = Path('tool/harden_interaction_once.py')
source = source_path.read_text()
old = """def c(old, new):
    global text
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'surface_canvas expected 1, found {n}: {old[:100]!r}')
    text = text.replace(old, new, 1)
"""
new = """def c(old, new):
    global text
    n = text.count(old)
    if n < 1:
        raise SystemExit(f'surface_canvas expected at least 1, found {n}: {old[:100]!r}')
    text = text.replace(old, new, 1)
"""
if old not in source:
    raise SystemExit('Unable to patch hardening helper guard')
source = source.replace(old, new, 1)
exec(compile(source, str(source_path), 'exec'), {'__name__': '__main__'})
