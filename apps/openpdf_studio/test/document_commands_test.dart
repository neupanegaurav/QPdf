import 'package:flutter_test/flutter_test.dart';
import 'package:openpdf_studio/src/editor/document_commands.dart';

void main() {
  test('document command identifiers and labels are unique', () {
    expect(
      documentCommands.map((command) => command.id).toSet().length,
      documentCommands.length,
    );
    expect(
      documentCommands.map((command) => command.label).toSet().length,
      documentCommands.length,
    );
  });

  test('command search includes aliases and category names', () {
    final optimize = documentCommands.singleWhere(
      (command) => command.id == DocumentCommandId.optimize,
    );
    final audit = documentCommands.singleWhere(
      (command) => command.id == DocumentCommandId.audit,
    );

    expect(optimize.matches('compress'), isTrue);
    expect(audit.matches('accessibility'), isTrue);
    expect(audit.matches('Inspect'), isTrue);
    expect(audit.matches('unrelated phrase'), isFalse);
  });
}
