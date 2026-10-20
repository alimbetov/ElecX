from pathlib import Path

p = Path('test/room_circuit_workflow_test.dart')
text = p.read_text()
old = """  test('schema v2 migrates with empty circuit bundle list', () {
"""
if old not in text:
    raise SystemExit('schema v2 test anchor missing')
old_expect = "    expect(decoded.schemaVersion, 3);\n"
count = text.count(old_expect)
if count != 1:
    raise SystemExit(f'expected one schema v3 assertion, found {count}')
text = text.replace(old_expect, "    expect(decoded.schemaVersion, 4);\n", 1)
p.write_text(text)
