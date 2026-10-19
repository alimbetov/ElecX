from pathlib import Path

source_path = Path('tool/persist_cable_constraints_once.py')
source = source_path.read_text()
old = "import 'package:elecx/src/domain/electrical_placement.dart';\n"
if old not in source:
    raise SystemExit('Unable to remove stale cable constraint test import')
source = source.replace(old, '', 1)
exec(compile(source, str(source_path), 'exec'), {'__name__': '__main__'})
