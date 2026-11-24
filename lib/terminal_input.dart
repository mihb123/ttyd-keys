import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class TerminalInput extends StatefulWidget {
  const TerminalInput({
    super.key,
    required this.focusNode,
    required this.onTyped,
    required this.onDelete,
    required this.onEnter,
    required this.child,
  });

  final FocusNode focusNode;
  final bool Function(String text) onTyped;
  final void Function(int count) onDelete;
  final VoidCallback onEnter;
  final Widget child;

  @override
  State<TerminalInput> createState() => TerminalInputState();
}

class TerminalInputState extends State<TerminalInput> with TextInputClient {
  static const _zw = '\u200B';
  static const _pad = 16;
  static final _empty = TextEditingValue(
    text: _zw * _pad,
    selection: const TextSelection.collapsed(offset: _pad),
  );
  static const _maxBuffer = 200;

  TextInputConnection? _connection;
  late TextEditingValue _value = _empty;
  String _typed = '';

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    _connection?.close();
    super.dispose();
  }

  void _onFocus() {
    if (widget.focusNode.hasFocus) {
      show();
    } else {
      _connection?.close();
      _connection = null;
    }
  }

  void show() {
    if (!widget.focusNode.hasFocus) {
      widget.focusNode.requestFocus();
      return;
    }
    if (_connection == null || !_connection!.attached) {
      _connection = TextInput.attach(
        this,
        TextInputConfiguration(
          viewId: View.of(context).viewId,
          inputType: TextInputType.text,
          inputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          keyboardAppearance: Brightness.dark,
        ),
      );
      _typed = '';
      _value = _empty;
      _connection!.setEditingState(_value);
    }
    _connection!.show();
  }

  void reset() {
    _typed = '';
    _value = _empty;
    _connection?.setEditingState(_value);
  }

  @override
  TextEditingValue? get currentTextEditingValue => _value;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    _value = value;
    if (value.composing.isValid && !value.composing.isCollapsed) return;

    final text = value.text;
    final padLeft = _zw.allMatches(text).length;
    final newTyped = text.replaceAll(_zw, '');
    final oldRunes = _typed.runes.toList();
    final newRunes = newTyped.runes.toList();
    var p = 0;
    while (p < oldRunes.length && p < newRunes.length && oldRunes[p] == newRunes[p]) {
      p++;
    }
    _typed = newTyped;
    final deleted = oldRunes.length - p + (padLeft < _pad ? _pad - padLeft : 0);
    if (deleted > 0) widget.onDelete(deleted);
    final added = String.fromCharCodes(newRunes.sublist(p));
    final needReset = added.isNotEmpty && _emit(added);
    if (needReset ||
        padLeft < _pad ||
        (added.endsWith(' ') && _typed.runes.length > 40) ||
        _typed.runes.length > _maxBuffer) {
      reset();
    }
  }

  bool _emit(String text) {
    final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    var needReset = false;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].isNotEmpty && widget.onTyped(lines[i])) needReset = true;
      if (i < lines.length - 1) {
        widget.onEnter();
        needReset = true;
      }
    }
    return needReset;
  }

  @override
  void performAction(TextInputAction action) {
    widget.onEnter();
    reset();
  }

  @override
  void connectionClosed() {
    _connection = null;
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  Widget build(BuildContext context) => widget.child;
}
