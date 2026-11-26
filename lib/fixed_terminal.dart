import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

class FixedTerminal extends Terminal {
  FixedTerminal({super.maxLines, super.inputHandler, super.mouseHandler});

  static const _maxRecoveries = 64;

  bool _listenerFailed = false;

  @override
  void notifyListeners() {
    try {
      super.notifyListeners();
    } catch (_) {
      _listenerFailed = true;
      rethrow;
    }
  }

  @override
  void write(String data) {
    var chunk = data;
    for (var i = 0; i < _maxRecoveries; i++) {
      try {
        super.write(chunk);
        return;
      } catch (error, stack) {
        if (_listenerFailed) {
          _listenerFailed = false;
          rethrow;
        }
        if (i == 0) {
          FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'xterm'));
        }
        chunk = '';
      }
    }
    notifyListeners();
  }

  @override
  void eraseChars(int amount) {
    final start = buffer.cursorX;
    final end = start + (amount < 1 ? 1 : amount);
    buffer.currentLine.eraseRange(start, end > viewWidth ? viewWidth : end, cursor);
  }

  @override
  void eraseLineLeft() {
    final line = buffer.currentLine;
    line.isWrapped = false;
    line.eraseRange(0, buffer.cursorX + 1, cursor);
  }

  @override
  void eraseDisplayAbove() {
    eraseLineLeft();
    for (var y = 0; y < buffer.cursorY; y++) {
      final line = buffer.lines[y + buffer.scrollBack];
      line.isWrapped = false;
      line.eraseRange(0, viewWidth, cursor);
    }
  }

  @override
  void setForegroundColor256(int index) {
    if (index >= 0 && index <= 255) super.setForegroundColor256(index);
  }

  @override
  void setBackgroundColor256(int index) {
    if (index >= 0 && index <= 255) super.setBackgroundColor256(index);
  }
}
