import 'package:flutter/foundation.dart';

enum Mod { ctrl, alt, shift }

enum ModState { off, once, locked }

class Modifiers extends ChangeNotifier {
  final Map<Mod, ModState> _state = {for (final m in Mod.values) m: ModState.off};

  ModState operator [](Mod m) => _state[m]!;
  bool isOn(Mod m) => _state[m] != ModState.off;
  bool get any => _state.values.any((s) => s != ModState.off);

  void tap(Mod m) {
    _state[m] = switch (_state[m]!) {
      ModState.off => ModState.once,
      ModState.once => ModState.locked,
      ModState.locked => ModState.off,
    };
    notifyListeners();
  }

  void consume() {
    var changed = false;
    for (final m in Mod.values) {
      if (_state[m] == ModState.once) {
        _state[m] = ModState.off;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void reset() {
    for (final m in Mod.values) {
      _state[m] = ModState.off;
    }
    notifyListeners();
  }
}

String? _ctrlChar(String c) {
  final code = c.codeUnitAt(0);
  if (code >= 0x61 && code <= 0x7a) return String.fromCharCode(code - 0x60);
  if (code >= 0x40 && code <= 0x5f) return String.fromCharCode(code - 0x40);
  return switch (c) {
    ' ' || '2' => '\x00',
    '3' => '\x1b',
    '4' => '\x1c',
    '5' => '\x1d',
    '6' => '\x1e',
    '7' || '-' || '/' => '\x1f',
    '8' || '?' => '\x7f',
    '\x7f' => '\x08',
    _ => null,
  };
}

String applyModifiers(String data, {required bool ctrl, required bool alt, required bool shift}) {
  if (data.length != 1) return data;
  var out = data;
  if (shift) out = out.toUpperCase();
  if (ctrl) out = _ctrlChar(out) ?? out;
  if (alt) out = '\x1b$out';
  return out;
}
