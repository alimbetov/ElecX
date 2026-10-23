import 'package:elecx/src/engine/command_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical projection advances revision without manufacturing undo', () {
    final history = CommandHistory<int>(1);

    history.replaceState(
      2,
      clearHistory: false,
      countAsProjection: true,
    );

    expect(history.state, 2);
    expect(history.mutationRevision, 1);
    expect(history.lastMutationKind, CommandHistoryMutationKind.projection);
    expect(history.canUndo, isFalse);
    expect(history.canRedo, isFalse);
  });
}
