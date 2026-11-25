import 'dart:collection';

import 'package:flutter/scheduler.dart';

class OutputThrottle {
  OutputThrottle({required this.write, required this.onPause, required this.onResume});

  final void Function(String) write;
  final void Function() onPause;
  final void Function() onResume;

  static const _frameBudget = Duration(milliseconds: 6);
  static const _sliceChars = 8192;
  static const _highWater = 256 * 1024;
  static const _lowWater = 64 * 1024;

  final _pending = Queue<String>();
  int _headOffset = 0;
  int _pendingChars = 0;
  bool _scheduled = false;
  bool _paused = false;
  bool _disposed = false;

  void add(String data) {
    if (data.isEmpty || _disposed) return;
    _pending.add(data);
    _pendingChars += data.length;
    if (!_paused && _pendingChars > _highWater) {
      _paused = true;
      onPause();
    }
    _schedule();
  }

  void resetFlow() {
    _paused = false;
    if (_pendingChars > _highWater) {
      _paused = true;
      onPause();
    }
  }

  void dispose() {
    _disposed = true;
    _pending.clear();
    _pendingChars = 0;
  }

  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback(_drain);
  }

  void _drain(Duration _) {
    _scheduled = false;
    if (_disposed) return;
    final watch = Stopwatch()..start();
    while (_pending.isNotEmpty && watch.elapsed < _frameBudget) {
      final head = _pending.first;
      var end = _headOffset + _sliceChars;
      if (end >= head.length) {
        end = head.length;
      } else if (_isHighSurrogate(head.codeUnitAt(end - 1))) {
        end--;
      }
      final chunk = _headOffset == 0 && end == head.length ? head : head.substring(_headOffset, end);
      if (end == head.length) {
        _pending.removeFirst();
        _headOffset = 0;
      } else {
        _headOffset = end;
      }
      _pendingChars -= chunk.length;
      write(chunk);
    }
    if (_paused && _pendingChars < _lowWater) {
      _paused = false;
      onResume();
    }
    if (_pending.isNotEmpty) _schedule();
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
}
