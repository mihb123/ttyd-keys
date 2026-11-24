import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:xterm/xterm.dart';

import 'modifiers.dart';

class KeyBar extends StatelessWidget {
  const KeyBar({
    super.key,
    required this.modifiers,
    required this.onKey,
    required this.onRaw,
    required this.onText,
    required this.onPaste,
    required this.onToggleKeyboard,
  });

  final Modifiers modifiers;
  final void Function(TerminalKey key) onKey;
  final void Function(String data) onRaw;
  final void Function(String text) onText;
  final VoidCallback onPaste;
  final VoidCallback onToggleKeyboard;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF26282C),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: ListenableBuilder(
            listenable: modifiers,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _Key(label: 'Esc', onPress: () => onKey(TerminalKey.escape)),
                    _Key(label: 'Tab', onPress: () => onKey(TerminalKey.tab)),
                    _ModKey(label: 'Ctrl', mod: Mod.ctrl, modifiers: modifiers),
                    _ModKey(label: 'Alt', mod: Mod.alt, modifiers: modifiers),
                    _ModKey(label: 'Shift', mod: Mod.shift, modifiers: modifiers),
                    _Key(label: '←', repeat: true, onPress: () => onKey(TerminalKey.arrowLeft)),
                    _Key(label: '↓', repeat: true, onPress: () => onKey(TerminalKey.arrowDown)),
                    _Key(label: '↑', repeat: true, onPress: () => onKey(TerminalKey.arrowUp)),
                    _Key(label: '→', repeat: true, onPress: () => onKey(TerminalKey.arrowRight)),
                  ],
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final c in 'CDZRLBAEUW'.split(''))
                        _Key(
                          label: '^$c',
                          width: 44,
                          onPress: () => onRaw(String.fromCharCode(c.codeUnitAt(0) - 0x40)),
                        ),
                      _Key(label: 'Home', width: 52, onPress: () => onKey(TerminalKey.home)),
                      _Key(label: 'End', width: 46, onPress: () => onKey(TerminalKey.end)),
                      _Key(label: 'PgUp', width: 52, onPress: () => onKey(TerminalKey.pageUp)),
                      _Key(label: 'PgDn', width: 52, onPress: () => onKey(TerminalKey.pageDown)),
                      for (final s in ['|', '~', '/', '-', '`', r'\', '*', r'$', '&'])
                        _Key(label: s, width: 40, onPress: () => onText(s)),
                      _Key(icon: Icons.content_paste, width: 48, onPress: onPaste),
                      _Key(icon: Icons.keyboard_hide, width: 48, onPress: onToggleKeyboard),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModKey extends StatelessWidget {
  const _ModKey({required this.label, required this.mod, required this.modifiers});

  final String label;
  final Mod mod;
  final Modifiers modifiers;

  @override
  Widget build(BuildContext context) {
    final state = modifiers[mod];
    return _Key(
      label: label,
      active: state != ModState.off,
      locked: state == ModState.locked,
      onPress: () => modifiers.tap(mod),
    );
  }
}

class _Key extends StatefulWidget {
  const _Key({
    this.label,
    this.icon,
    required this.onPress,
    this.width,
    this.repeat = false,
    this.active = false,
    this.locked = false,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onPress;
  final double? width;
  final bool repeat;
  final bool active;
  final bool locked;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  Timer? _delay;
  Timer? _repeat;
  bool _down = false;

  void _start() {
    _delay?.cancel();
    _repeat?.cancel();
    setState(() => _down = true);
    widget.onPress();
    if (!widget.repeat) return;
    _delay = Timer(const Duration(milliseconds: 400), () {
      _repeat = Timer.periodic(const Duration(milliseconds: 60), (_) => widget.onPress());
    });
  }

  void _stop() {
    _delay?.cancel();
    _repeat?.cancel();
    if (mounted) setState(() => _down = false);
  }

  @override
  void dispose() {
    _delay?.cancel();
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.locked
        ? const Color(0xFF2563EB)
        : widget.active
            ? const Color(0xFF3B82F6)
            : _down
                ? const Color(0xFF52565E)
                : const Color(0xFF3A3D43);
    final fg = widget.active ? Colors.white : const Color(0xFFE5E7EB);
    final face = Container(
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: widget.locked ? Border.all(color: Colors.white, width: 1.5) : null,
        ),
        alignment: Alignment.center,
        child: widget.icon != null
            ? Icon(widget.icon, size: 18, color: fg)
            : Text(
                widget.label!,
                maxLines: 1,
                style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600),
              ),
    );
    final child = widget.repeat
        ? Listener(
            onPointerDown: (_) => _start(),
            onPointerUp: (_) => _stop(),
            onPointerCancel: (_) => _stop(),
            child: face,
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _down = true),
            onTapCancel: _stop,
            onTap: () {
              _stop();
              widget.onPress();
            },
            child: face,
          );
    return widget.width == null ? Expanded(child: child) : SizedBox(width: widget.width, child: child);
  }
}
