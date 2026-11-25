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

class FixedMouseHandler implements TerminalMouseHandler {
  const FixedMouseHandler();

  int _buttonCode(TerminalMouseButton button) {
    return switch (button) {
      TerminalMouseButton.left => 0,
      TerminalMouseButton.middle => 1,
      TerminalMouseButton.right => 2,
      TerminalMouseButton.wheelUp => 64,
      TerminalMouseButton.wheelDown => 65,
      TerminalMouseButton.wheelLeft => 66,
      TerminalMouseButton.wheelRight => 67,
    };
  }

  String _report(
    TerminalMouseButton button,
    TerminalMouseButtonState state,
    CellOffset position,
    MouseReportMode mode,
  ) {
    final x = position.x + 1;
    final y = position.y + 1;
    final code = _buttonCode(button);
    switch (mode) {
      case MouseReportMode.normal:
      case MouseReportMode.utf:
        final btnId = state == TerminalMouseButtonState.up ? 3 : code;
        final maxCoord = mode == MouseReportMode.normal ? 223 : 2015;
        final btn = String.fromCharCode(32 + btnId);
        final col = x > maxCoord ? '\x00' : String.fromCharCode(32 + x);
        final row = y > maxCoord ? '\x00' : String.fromCharCode(32 + y);
        return '\x1b[M$btn$col$row';
      case MouseReportMode.sgr:
        final upDown = state == TerminalMouseButtonState.down ? 'M' : 'm';
        return '\x1b[<$code;$x;$y$upDown';
      case MouseReportMode.urxvt:
        final btnId = state == TerminalMouseButtonState.up ? 3 : code;
        return '\x1b[${32 + btnId};$x;${y}M';
    }
  }

  @override
  String? call(TerminalMouseEvent event) {
    switch (event.state.mouseMode) {
      case MouseMode.none:
        return null;
      case MouseMode.clickOnly:
        if (event.buttonState == TerminalMouseButtonState.down && !event.button.isWheel) {
          return _report(event.button, event.buttonState, event.position, event.state.mouseReportMode);
        }
        return null;
      case MouseMode.upDownScroll:
      case MouseMode.upDownScrollDrag:
      case MouseMode.upDownScrollMove:
        if (event.button.isWheel && event.buttonState == TerminalMouseButtonState.up) {
          return null;
        }
        return _report(event.button, event.buttonState, event.position, event.state.mouseReportMode);
    }
  }
}
