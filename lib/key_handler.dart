import 'package:xterm/xterm.dart';

class FixedKeyHandler implements TerminalInputHandler {
  const FixedKeyHandler();

  static const _fallback = CascadeInputHandler([KeytabInputHandler(), CtrlInputHandler()]);

  static const _cursor = {
    TerminalKey.arrowUp: 'A',
    TerminalKey.arrowDown: 'B',
    TerminalKey.arrowRight: 'C',
    TerminalKey.arrowLeft: 'D',
    TerminalKey.home: 'H',
    TerminalKey.end: 'F',
  };

  static const _tilde = {
    TerminalKey.insert: '2',
    TerminalKey.delete: '3',
    TerminalKey.pageUp: '5',
    TerminalKey.pageDown: '6',
  };

  @override
  String? call(TerminalKeyboardEvent e) {
    final mod = 1 + (e.shift ? 1 : 0) + (e.alt ? 2 : 0) + (e.ctrl ? 4 : 0);
    final esc = e.alt ? '\x1b' : '';

    final cursor = _cursor[e.key];
    if (cursor != null) {
      if (mod > 1) return '\x1b[1;$mod$cursor';
      return e.state.cursorKeysMode ? '\x1bO$cursor' : '\x1b[$cursor';
    }
    final tilde = _tilde[e.key];
    if (tilde != null) return mod > 1 ? '\x1b[$tilde;$mod~' : '\x1b[$tilde~';

    switch (e.key) {
      case TerminalKey.tab:
        return e.shift ? '\x1b[Z' : '$esc\t';
      case TerminalKey.escape:
        return '$esc\x1b';
      case TerminalKey.enter:
        return '$esc\r';
      case TerminalKey.backspace:
        return '$esc${e.ctrl ? '\x08' : '\x7f'}';
      default:
    }

    final index = e.key.index - TerminalKey.keyA.index;
    if (e.alt && index >= 0 && index < 26) {
      final letter = String.fromCharCode((e.shift ? 0x41 : 0x61) + index);
      return e.ctrl ? '\x1b${String.fromCharCode(index + 1)}' : '\x1b$letter';
    }
    return _fallback(e);
  }
}
