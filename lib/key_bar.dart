import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xterm/xterm.dart';

import 'modifiers.dart';

enum KeyBarGroup {
  main('Hàng chính'),
  ctrl('Tổ hợp Ctrl'),
  nav('Điều hướng'),
  symbol('Ký tự'),
  action('Tiện ích');

  const KeyBarGroup(this.title);
  final String title;
}

enum KeyBarActionKind { key, mod, raw, text, paste, toggleKeyboard }

class KeyBarItem {
  const KeyBarItem({
    required this.id,
    this.label,
    this.icon,
    required this.settingLabel,
    required this.group,
    required this.row,
    required this.kind,
    this.width,
    this.repeat = false,
    this.terminalKey,
    this.mod,
    this.data,
  });

  final String id;
  final String? label;
  final IconData? icon;
  final String settingLabel;
  final KeyBarGroup group;
  final int row;
  final KeyBarActionKind kind;
  final double? width;
  final bool repeat;
  final TerminalKey? terminalKey;
  final Mod? mod;
  final String? data;
}

const List<KeyBarItem> keyBarCatalog = [
  KeyBarItem(id: 'esc', label: 'Esc', settingLabel: 'Esc', group: KeyBarGroup.main, row: 1, kind: KeyBarActionKind.key, terminalKey: TerminalKey.escape),
  KeyBarItem(id: 'tab', label: 'Tab', settingLabel: 'Tab', group: KeyBarGroup.main, row: 1, kind: KeyBarActionKind.key, terminalKey: TerminalKey.tab),
  KeyBarItem(id: 'ctrl', label: 'Ctrl', settingLabel: 'Ctrl', group: KeyBarGroup.main, row: 1, kind: KeyBarActionKind.mod, mod: Mod.ctrl),
  KeyBarItem(id: 'alt', label: 'Alt', settingLabel: 'Alt', group: KeyBarGroup.main, row: 1, kind: KeyBarActionKind.mod, mod: Mod.alt),
  KeyBarItem(id: 'shift', label: 'Shift', settingLabel: 'Shift', group: KeyBarGroup.main, row: 1, kind: KeyBarActionKind.mod, mod: Mod.shift),
  KeyBarItem(id: 'left', label: '←', settingLabel: '←', group: KeyBarGroup.main, row: 1, kind: KeyBarActionKind.key, terminalKey: TerminalKey.arrowLeft, repeat: true),
  KeyBarItem(id: 'down', label: '↓', settingLabel: '↓', group: KeyBarGroup.main, row: 1, kind: KeyBarActionKind.key, terminalKey: TerminalKey.arrowDown, repeat: true),
  KeyBarItem(id: 'up', label: '↑', settingLabel: '↑', group: KeyBarGroup.main, row: 1, kind: KeyBarActionKind.key, terminalKey: TerminalKey.arrowUp, repeat: true),
  KeyBarItem(id: 'right', label: '→', settingLabel: '→', group: KeyBarGroup.main, row: 1, kind: KeyBarActionKind.key, terminalKey: TerminalKey.arrowRight, repeat: true),
  KeyBarItem(id: 'ctrl_c', label: '^C', settingLabel: '^C', group: KeyBarGroup.ctrl, row: 2, width: 44, kind: KeyBarActionKind.raw, data: '\x03'),
  KeyBarItem(id: 'ctrl_d', label: '^D', settingLabel: '^D', group: KeyBarGroup.ctrl, row: 2, width: 44, kind: KeyBarActionKind.raw, data: '\x04'),
  KeyBarItem(id: 'ctrl_z', label: '^Z', settingLabel: '^Z', group: KeyBarGroup.ctrl, row: 2, width: 44, kind: KeyBarActionKind.raw, data: '\x1a'),
  KeyBarItem(id: 'ctrl_r', label: '^R', settingLabel: '^R', group: KeyBarGroup.ctrl, row: 2, width: 44, kind: KeyBarActionKind.raw, data: '\x12'),
  KeyBarItem(id: 'ctrl_l', label: '^L', settingLabel: '^L', group: KeyBarGroup.ctrl, row: 2, width: 44, kind: KeyBarActionKind.raw, data: '\x0c'),
  KeyBarItem(id: 'ctrl_b', label: '^B', settingLabel: '^B', group: KeyBarGroup.ctrl, row: 2, width: 44, kind: KeyBarActionKind.raw, data: '\x02'),
  KeyBarItem(id: 'ctrl_a', label: '^A', settingLabel: '^A', group: KeyBarGroup.ctrl, row: 2, width: 44, kind: KeyBarActionKind.raw, data: '\x01'),
  KeyBarItem(id: 'ctrl_e', label: '^E', settingLabel: '^E', group: KeyBarGroup.ctrl, row: 2, width: 44, kind: KeyBarActionKind.raw, data: '\x05'),
  KeyBarItem(id: 'ctrl_u', label: '^U', settingLabel: '^U', group: KeyBarGroup.ctrl, row: 2, width: 44, kind: KeyBarActionKind.raw, data: '\x15'),
  KeyBarItem(id: 'ctrl_w', label: '^W', settingLabel: '^W', group: KeyBarGroup.ctrl, row: 2, width: 44, kind: KeyBarActionKind.raw, data: '\x17'),
  KeyBarItem(id: 'home', label: 'Home', settingLabel: 'Home', group: KeyBarGroup.nav, row: 2, width: 52, kind: KeyBarActionKind.key, terminalKey: TerminalKey.home),
  KeyBarItem(id: 'end', label: 'End', settingLabel: 'End', group: KeyBarGroup.nav, row: 2, width: 46, kind: KeyBarActionKind.key, terminalKey: TerminalKey.end),
  KeyBarItem(id: 'pgup', label: 'PgUp', settingLabel: 'PgUp', group: KeyBarGroup.nav, row: 2, width: 52, kind: KeyBarActionKind.key, terminalKey: TerminalKey.pageUp),
  KeyBarItem(id: 'pgdn', label: 'PgDn', settingLabel: 'PgDn', group: KeyBarGroup.nav, row: 2, width: 52, kind: KeyBarActionKind.key, terminalKey: TerminalKey.pageDown),
  KeyBarItem(id: 'sym_pipe', label: '|', settingLabel: '|', group: KeyBarGroup.symbol, row: 2, width: 40, kind: KeyBarActionKind.text, data: '|'),
  KeyBarItem(id: 'sym_tilde', label: '~', settingLabel: '~', group: KeyBarGroup.symbol, row: 2, width: 40, kind: KeyBarActionKind.text, data: '~'),
  KeyBarItem(id: 'sym_slash', label: '/', settingLabel: '/', group: KeyBarGroup.symbol, row: 2, width: 40, kind: KeyBarActionKind.text, data: '/'),
  KeyBarItem(id: 'sym_dash', label: '-', settingLabel: '-', group: KeyBarGroup.symbol, row: 2, width: 40, kind: KeyBarActionKind.text, data: '-'),
  KeyBarItem(id: 'sym_backtick', label: '`', settingLabel: '`', group: KeyBarGroup.symbol, row: 2, width: 40, kind: KeyBarActionKind.text, data: '`'),
  KeyBarItem(id: 'sym_backslash', label: r'\', settingLabel: r'\', group: KeyBarGroup.symbol, row: 2, width: 40, kind: KeyBarActionKind.text, data: r'\'),
  KeyBarItem(id: 'sym_star', label: '*', settingLabel: '*', group: KeyBarGroup.symbol, row: 2, width: 40, kind: KeyBarActionKind.text, data: '*'),
  KeyBarItem(id: 'sym_dollar', label: r'$', settingLabel: r'$', group: KeyBarGroup.symbol, row: 2, width: 40, kind: KeyBarActionKind.text, data: r'$'),
  KeyBarItem(id: 'sym_amp', label: '&', settingLabel: '&', group: KeyBarGroup.symbol, row: 2, width: 40, kind: KeyBarActionKind.text, data: '&'),
  KeyBarItem(id: 'paste', icon: Icons.content_paste, settingLabel: 'Dán', group: KeyBarGroup.action, row: 2, width: 48, kind: KeyBarActionKind.paste),
  KeyBarItem(id: 'hide_kb', icon: Icons.keyboard_hide, settingLabel: 'Ẩn bàn phím', group: KeyBarGroup.action, row: 2, width: 48, kind: KeyBarActionKind.toggleKeyboard),
];

class KeyBar extends StatelessWidget {
  const KeyBar({
    super.key,
    required this.modifiers,
    required this.onKey,
    required this.onRaw,
    required this.onText,
    required this.onPaste,
    required this.onToggleKeyboard,
    this.hiddenKeys = const {},
  });

  final Modifiers modifiers;
  final void Function(TerminalKey key) onKey;
  final void Function(String data) onRaw;
  final void Function(String text) onText;
  final VoidCallback onPaste;
  final VoidCallback onToggleKeyboard;
  final Set<String> hiddenKeys;

  Widget _buildItem(KeyBarItem item) {
    return switch (item.kind) {
      KeyBarActionKind.mod => _ModKey(label: item.label!, mod: item.mod!, modifiers: modifiers),
      KeyBarActionKind.key => _Key(
          label: item.label,
          icon: item.icon,
          width: item.width,
          repeat: item.repeat,
          onPress: () => onKey(item.terminalKey!),
        ),
      KeyBarActionKind.raw => _Key(
          label: item.label,
          width: item.width,
          onPress: () => onRaw(item.data!),
        ),
      KeyBarActionKind.text => _Key(
          label: item.label,
          width: item.width,
          onPress: () => onText(item.data!),
        ),
      KeyBarActionKind.paste => _Key(
          icon: item.icon,
          width: item.width,
          onPress: onPaste,
        ),
      KeyBarActionKind.toggleKeyboard => _Key(
          icon: item.icon,
          width: item.width,
          onPress: onToggleKeyboard,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final row1 = [
      for (final item in keyBarCatalog)
        if (item.row == 1 && !hiddenKeys.contains(item.id)) item,
    ];
    final row2 = [
      for (final item in keyBarCatalog)
        if (item.row == 2 && !hiddenKeys.contains(item.id)) item,
    ];
    if (row1.isEmpty && row2.isEmpty) return const SizedBox.shrink();

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
                if (row1.isNotEmpty)
                  Row(children: [for (final item in row1) _buildItem(item)]),
                if (row1.isNotEmpty && row2.isNotEmpty) const SizedBox(height: 3),
                if (row2.isNotEmpty)
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [for (final item in row2) _buildItem(item)],
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
      onHaptic: () {
        if (state == ModState.once) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      },
      onPress: () => modifiers.tap(mod),
    );
  }
}

class _Key extends StatefulWidget {
  const _Key({
    this.label,
    this.icon,
    required this.onPress,
    this.onHaptic,
    this.width,
    this.repeat = false,
    this.active = false,
    this.locked = false,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onPress;
  final VoidCallback? onHaptic;
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

  void _triggerHaptic() {
    if (widget.onHaptic != null) {
      widget.onHaptic!();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _start() {
    _delay?.cancel();
    _repeat?.cancel();
    setState(() => _down = true);
    _triggerHaptic();
    widget.onPress();
    if (!widget.repeat) return;
    _delay = Timer(const Duration(milliseconds: 400), () {
      _repeat = Timer.periodic(const Duration(milliseconds: 60), (_) {
        HapticFeedback.selectionClick();
        widget.onPress();
      });
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
              _triggerHaptic();
              widget.onPress();
            },
            child: face,
          );
    return widget.width == null ? Expanded(child: child) : SizedBox(width: widget.width, child: child);
  }
}

class KeyBarCustomizationSheet extends StatefulWidget {
  const KeyBarCustomizationSheet({super.key, required this.initialHiddenKeys});

  final Set<String> initialHiddenKeys;

  @override
  State<KeyBarCustomizationSheet> createState() => _KeyBarCustomizationSheetState();
}

class _KeyBarCustomizationSheetState extends State<KeyBarCustomizationSheet> {
  late final Set<String> _hidden = Set<String>.from(widget.initialHiddenKeys);

  void _toggleKey(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_hidden.remove(id)) {
        _hidden.add(id);
      }
    });
  }

  void _toggleGroup(List<KeyBarItem> items) {
    HapticFeedback.selectionClick();
    final allShown = items.every((e) => !_hidden.contains(e.id));
    setState(() {
      if (allShown) {
        for (final item in items) {
          _hidden.add(item.id);
        }
      } else {
        for (final item in items) {
          _hidden.remove(item.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = keyBarCatalog.length - _hidden.length;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tuỳ chỉnh thanh phím ($visibleCount/${keyBarCatalog.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _hidden.isEmpty
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            setState(_hidden.clear);
                          },
                    child: const Text('Mặc định'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final group in KeyBarGroup.values) ...[
                      Builder(
                        builder: (context) {
                          final items = [
                            for (final item in keyBarCatalog)
                              if (item.group == group) item,
                          ];
                          final allShown = items.every((e) => !_hidden.contains(e.id));
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      group.title,
                                      style: Theme.of(context).textTheme.labelLarge,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _toggleGroup(items),
                                    child: Text(allShown ? 'Ẩn nhóm' : 'Hiện hết'),
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final item in items)
                                    FilterChip(
                                      label: Text(item.settingLabel),
                                      selected: !_hidden.contains(item.id),
                                      onSelected: (_) => _toggleKey(item.id),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_hidden),
                  child: const Text('Xong'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
