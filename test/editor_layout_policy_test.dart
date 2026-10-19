import 'package:elecx/src/features/editor/editor_layout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phone width selects mobile editor', () {
    expect(EditorLayoutPolicy.forWidth(430), EditorLayoutMode.mobile);
    expect(
      EditorLayoutPolicy.persistentSidePanels(EditorLayoutMode.mobile),
      isFalse,
    );
  });

  test('tablet width selects touch-first tablet editor', () {
    expect(EditorLayoutPolicy.forWidth(768), EditorLayoutMode.tablet);
    expect(EditorLayoutPolicy.forWidth(1024), EditorLayoutMode.tablet);
    expect(EditorLayoutPolicy.navigatorWidth(EditorLayoutMode.tablet), 328);
    expect(EditorLayoutPolicy.inspectorWidth(EditorLayoutMode.tablet), 356);
  });

  test('desktop width keeps compact persistent panel widths', () {
    expect(EditorLayoutPolicy.forWidth(1440), EditorLayoutMode.desktop);
    expect(
      EditorLayoutPolicy.persistentSidePanels(EditorLayoutMode.desktop),
      isTrue,
    );
    expect(EditorLayoutPolicy.compactTools(EditorLayoutMode.desktop), isFalse);
    expect(EditorLayoutPolicy.navigatorWidth(EditorLayoutMode.desktop), 252);
    expect(EditorLayoutPolicy.inspectorWidth(EditorLayoutMode.desktop), 312);
  });

  test('breakpoints are deterministic at boundaries', () {
    expect(EditorLayoutPolicy.forWidth(699.9), EditorLayoutMode.mobile);
    expect(EditorLayoutPolicy.forWidth(700), EditorLayoutMode.tablet);
    expect(EditorLayoutPolicy.forWidth(1179.9), EditorLayoutMode.tablet);
    expect(EditorLayoutPolicy.forWidth(1180), EditorLayoutMode.desktop);
  });
}
