import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

const double minTerminalFontSize = 6;
const double maxTerminalFontSize = 24;
const int terminalFontSizeDivisions = 36;

double snapFontSize(double size) {
  final clamped = size.clamp(minTerminalFontSize, maxTerminalFontSize);
  return (clamped * 2).round() / 2;
}

String formatFontSize(double size) {
  final snapped = snapFontSize(size);
  return snapped == snapped.roundToDouble() ? snapped.toInt().toString() : snapped.toStringAsFixed(1);
}

class _BoundedBouncingScrollPhysics extends BouncingScrollPhysics {
  const _BoundedBouncingScrollPhysics({super.parent});

  @override
  _BoundedBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _BoundedBouncingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    return position.minScrollExtent < position.maxScrollExtent;
  }
}

class TerminalScrollBehavior extends MaterialScrollBehavior {
  const TerminalScrollBehavior({required this.altBuffer});

  final bool altBuffer;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (altBuffer) return const NeverScrollableScrollPhysics();
    return switch (getPlatform(context)) {
      TargetPlatform.iOS || TargetPlatform.macOS => const _BoundedBouncingScrollPhysics(
          parent: RangeMaintainingScrollPhysics(),
        ),
      _ => const ClampingScrollPhysics(parent: RangeMaintainingScrollPhysics()),
    };
  }
}

/// Gesture recognizer that only competes and wins the gesture arena when at
/// least two pointers are down simultaneously, leaving single-finger tap,
/// scroll, and long-press gestures completely untouched.
class PinchGestureRecognizer extends OneSequenceGestureRecognizer {
  PinchGestureRecognizer({super.debugOwner, super.supportedDevices});

  VoidCallback? onPinchStart;
  void Function(double scale)? onPinchUpdate;
  VoidCallback? onPinchEnd;

  final Map<int, Offset> _pointers = {};
  double _baseScale = 1.0;
  double? _initialSpan;
  bool _pinchActive = false;
  bool _accepted = false;

  double _computeSpan() {
    if (_pointers.length < 2) return 0;
    var centroid = Offset.zero;
    for (final pos in _pointers.values) {
      centroid += pos;
    }
    centroid /= _pointers.length.toDouble();
    var total = 0.0;
    for (final pos in _pointers.values) {
      total += (pos - centroid).distance;
    }
    return total / _pointers.length;
  }

  void _endPinch() {
    if (!_pinchActive) return;
    _pinchActive = false;
    _initialSpan = null;
    _baseScale = 1.0;
    invokeCallback<void>('onPinchEnd', () => onPinchEnd?.call());
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      if (_pinchActive && _pointers.length >= 2) {
        final span = _computeSpan();
        if (_initialSpan != null && _initialSpan! > 0 && span > 0) {
          _baseScale *= span / _initialSpan!;
        }
      }
      _pointers[event.pointer] = event.position;
      if (_pointers.length >= 2) {
        final span = _computeSpan();
        _initialSpan = span > 0 ? span : null;
        if (!_accepted) {
          _accepted = true;
          resolve(GestureDisposition.accepted);
        } else {
          resolvePointer(event.pointer, GestureDisposition.accepted);
        }
        if (!_pinchActive) {
          _pinchActive = true;
          _baseScale = 1.0;
          invokeCallback<void>('onPinchStart', () => onPinchStart?.call());
        }
      }
    } else if (event is PointerMoveEvent) {
      if (!_pointers.containsKey(event.pointer)) return;
      _pointers[event.pointer] = event.position;
      if (_pinchActive && _pointers.length >= 2) {
        final span = _computeSpan();
        if (_initialSpan == null || _initialSpan! <= 0) {
          if (span > 0) _initialSpan = span;
        } else if (span > 0) {
          final scale = _baseScale * (span / _initialSpan!);
          invokeCallback<void>('onPinchUpdate', () => onPinchUpdate?.call(scale));
        }
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_pinchActive && _pointers.length >= 2) {
        final span = _computeSpan();
        if (_initialSpan != null && _initialSpan! > 0 && span > 0) {
          _baseScale *= span / _initialSpan!;
        }
      }
      _pointers.remove(event.pointer);
      if (_pinchActive) {
        if (_pointers.length >= 2) {
          final span = _computeSpan();
          _initialSpan = span > 0 ? span : null;
        } else {
          _endPinch();
        }
      } else if (!_accepted) {
        resolvePointer(event.pointer, GestureDisposition.rejected);
      }
    }
    stopTrackingIfPointerNoLongerDown(event);
  }

  @override
  void rejectGesture(int pointer) {
    _pointers.remove(pointer);
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    if (_pinchActive) {
      _endPinch();
    }
    _pointers.clear();
    _initialSpan = null;
    _baseScale = 1.0;
    _accepted = false;
  }

  @override
  void dispose() {
    _pointers.clear();
    _pinchActive = false;
    _accepted = false;
    _initialSpan = null;
    super.dispose();
  }

  @override
  String get debugDescription => 'two-finger pinch';
}
