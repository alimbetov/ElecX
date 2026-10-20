from pathlib import Path

p = Path('lib/src/features/editor/room_circuit_panel.dart')
text = p.read_text()
old = """    if (current != null) details.add('${current.toStringAsFixed(current.truncateToDouble() == current ? 0 : 1)} A');
    if (poles != null) details.add('${poles}P');
"""
new = """    if (current != null) {
      details.add(
        '${current.toStringAsFixed(current.truncateToDouble() == current ? 0 : 1)} A',
      );
    }
    if (poles != null) {
      details.add('${poles}P');
    }
"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected one protection label anchor, found {count}')
p.write_text(text.replace(old, new, 1))
