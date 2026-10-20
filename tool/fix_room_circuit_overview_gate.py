from pathlib import Path

path = Path('lib/src/features/editor/room_circuit_overview.dart')
text = path.read_text()
old = "import '../../domain/electrical_placement.dart';\n"
count = text.count(old)
if count != 1:
    raise SystemExit(
        f'room_circuit_overview.dart: expected one unused import, found {count}'
    )
path.write_text(text.replace(old, '', 1))
