import 'package:pdf_domain/pdf_domain.dart';
import 'package:test/test.dart';

void main() {
  test('undo and redo move through states', () {
    final history = CommandHistory<int>(0);
    history.push(1);
    history.push(2);

    expect(history.undo(), 1);
    expect(history.undo(), 0);
    expect(history.redo(), 1);
    expect(history.redo(), 2);
  });

  test('a new command clears redo history', () {
    final history = CommandHistory<String>('a');
    history.push('b');
    history.undo();
    history.push('c');

    expect(history.canRedo, isFalse);
    expect(history.current, 'c');
  });

  test('history remains bounded', () {
    final history = CommandHistory<int>(0, maxEntries: 2);
    history.push(1);
    history.push(2);
    history.push(3);

    expect(history.undo(), 2);
    expect(history.undo(), 1);
    expect(history.undo(), isNull);
  });
}
