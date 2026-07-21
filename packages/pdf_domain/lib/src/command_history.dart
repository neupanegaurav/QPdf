/// Small, engine-neutral undo/redo history.
///
/// PDF engines may maintain their own incremental revision history. This type
/// is for host-level commands and deliberately has a limit so large document
/// states cannot grow without bound.
final class CommandHistory<T> {
  CommandHistory(T initial, {this.maxEntries = 100})
    : assert(maxEntries > 0),
      _past = <T>[],
      _current = initial,
      _future = <T>[];

  final int maxEntries;
  final List<T> _past;
  final List<T> _future;
  T _current;

  T get current => _current;
  bool get canUndo => _past.isNotEmpty;
  bool get canRedo => _future.isNotEmpty;

  void push(T next) {
    _past.add(_current);
    if (_past.length > maxEntries) {
      _past.removeAt(0);
    }
    _current = next;
    _future.clear();
  }

  T? undo() {
    if (!canUndo) return null;
    _future.add(_current);
    _current = _past.removeLast();
    return _current;
  }

  T? redo() {
    if (!canRedo) return null;
    _past.add(_current);
    _current = _future.removeLast();
    return _current;
  }
}
