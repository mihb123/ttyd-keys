import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xterm/xterm.dart';

import 'app_lock.dart';
import 'key_bar.dart';
import 'key_handler.dart';
import 'lock_screen.dart';
import 'main.dart';
import 'modifiers.dart';
import 'selection_handles.dart';
import 'settings.dart';
import 'terminal_gestures.dart';
import 'terminal_input.dart';
import 'ttyd_client.dart';

enum _Status { connecting, connected, disconnected }

/// Font nhúng trong app (assets/fonts): đủ dấu tiếng Việt dựng sẵn + icon Nerd Font cho prompt/tmux.
const terminalFontFamily = 'JetBrainsMonoNF';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key, required this.settings, this.initialSession, this.lockOnStart = false});

  final Settings settings;
  final TtydSession? initialSession;

  /// Mở app bằng mật khẩu đã nhớ: tự đăng nhập, nhưng phải qua bước 2 (Face ID/PIN) mới thấy terminal.
  final bool lockOnStart;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _terminal = Terminal(
    maxLines: 10000,
    inputHandler: const FixedKeyHandler(),
    mouseHandler: const FixedMouseHandler(),
  );
  final _terminalViewKey = GlobalKey<TerminalViewState>();
  final _inputKey = GlobalKey<TerminalInputState>();
  final _controller = TerminalController();
  final _scrollController = ScrollController();
  final _focus = FocusNode();
  final _mods = Modifiers();
  final _contextMenuController = ContextMenuController();
  final Set<int> _activePointers = {};
  late final AnimationController _altFling = AnimationController.unbounded(vsync: this)..addListener(_onAltFlingTick);

  late TtydSession? _session = widget.initialSession;
  TtydConnection? _conn;
  _Status _status = _Status.connecting;
  String? _error;
  String _title = '';
  bool _connecting = false;

  final _lock = AppLock();
  late bool _locked = widget.lockOnStart;
  bool _pinSetup = false;
  int _lockRound = 0;
  DateTime? _backgroundAt;
  bool _loggingOut = false;

  /// Màn che đen khi app không ở foreground (không lộ terminal trong trình chuyển app),
  /// và lúc đang kiểm có cần tạo PIN sau khi đăng nhập bằng mật khẩu.
  late bool _curtain = !widget.lockOnStart;

  int? _singlePointer;
  Offset? _pointerDownPos;
  bool _movedBeyondSlop = false;
  bool _multiTouchUsed = false;
  bool _longPressTriggered = false;
  bool _hadSelectionOrMenuOnDown = false;
  bool _wasKeyboardOpenOnDown = false;
  Timer? _longPressTimer;
  bool _lastKeyboardVisible = false;
  bool _pinching = false;
  double _pinchBaseFontSize = 14;
  bool _isAltBuffer = false;
  bool _isScrolledUp = false;
  double _altScrollCarry = 0;
  double _altFlingLast = 0;
  Offset? _altScrollLocalPos;
  bool _draggingHandle = false;
  BufferRangeLine? _longPressOriginWord;
  CellOffset? _lastLongPressCell;

  Settings get _settings => widget.settings;

  bool get _covered => _locked || _pinSetup;

  double get _lineHeight {
    final state = _terminalViewKey.currentState;
    if (state == null || !state.mounted) return 16;
    final render = state.renderTerminal;
    return render.attached ? render.lineHeight : 16;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _terminal.onOutput = _send;
    _terminal.onResize = (w, h, _, _) => _conn?.resize(w, h);
    _terminal.addListener(_onTerminalStateChanged);
    _scrollController.addListener(_onScrollPositionChanged);
    _controller.addListener(_onSelectionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
    if (!widget.lockOnStart) _checkPinSetup();
  }

  /// Chỉ chạy ngay sau khi đăng nhập bằng mật khẩu: máy không có sinh trắc học và chưa có mã PIN
  /// → bắt tạo mã PIN. Không bao giờ chạy khi đang khoá (xem `AppLock.needsPinSetup`).
  Future<void> _checkPinSetup() async {
    final need = await _lock.needsPinSetup();
    if (!mounted) return;
    if (need) FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _pinSetup = need;
      _curtain = false;
    });
  }

  void _lockNow() {
    FocusManager.instance.primaryFocus?.unfocus();
    // Menu Sao chép/Dán nằm trên Overlay riêng, phải gỡ để không nổi trên màn khoá.
    _dismissSelectionAndMenu();
    // Đóng sheet Cài đặt/menu đang mở phía trên, nếu không chúng nằm đè lên màn khoá.
    final route = ModalRoute.of(context);
    if (route != null) Navigator.of(context).popUntil((r) => r == route);
    setState(() {
      _locked = true;
      _lockRound++;
    });
  }

  void _onUnlocked() {
    setState(() {
      _locked = false;
      _pinSetup = false;
    });
    if (_conn?.isOpen ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_covered) _inputKey.currentState?.show();
      });
    } else {
      _connect();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _terminal.removeListener(_onTerminalStateChanged);
    _scrollController.removeListener(_onScrollPositionChanged);
    _controller.removeListener(_onSelectionChanged);
    _longPressTimer?.cancel();
    _altFling.dispose();
    _contextMenuController.remove();
    _conn?.close();
    _scrollController.dispose();
    _controller.dispose();
    _focus.dispose();
    _mods.dispose();
    super.dispose();
  }

  void _onInputAttachChanged() {
    if (mounted) setState(() {});
  }

  void _onTerminalStateChanged() {
    final alt = _terminal.isUsingAltBuffer;
    if (alt == _isAltBuffer) return;
    _altFling.stop();
    _altScrollCarry = 0;
    if (alt && _scrollController.hasClients && _scrollController.position.pixels != 0) {
      _scrollController.jumpTo(0);
    }
    if (mounted) {
      setState(() {
        _isAltBuffer = alt;
        if (alt) _isScrolledUp = false;
      });
    }
  }

  void _onScrollPositionChanged() {
    if (_isAltBuffer || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final threshold = _lineHeight * 1.5;
    final scrolledUp = pos.maxScrollExtent - pos.pixels > threshold;
    if (scrolledUp != _isScrolledUp && mounted) {
      setState(() => _isScrolledUp = scrolledUp);
    }
    if (_contextMenuController.isShown && !_draggingHandle) {
      _contextMenuController.remove();
    }
  }

  void _onSelectionChanged() {
    final wantSuspend = _pinching || _controller.selection != null;
    if (_controller.suspendedPointerInputs != wantSuspend) {
      _controller.setSuspendPointerInput(wantSuspend);
    }
  }

  void _scrollToBottom() {
    if (_isAltBuffer || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent) {
      pos.jumpTo(pos.maxScrollExtent);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // inactive (Face ID, Trung tâm điều khiển) chỉ che màn, không tính là rời app.
      case AppLifecycleState.inactive:
        if (!_curtain) setState(() => _curtain = true);
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _backgroundAt ??= DateTime.now();
        _dismissSelectionAndMenu();
        if (!_curtain) setState(() => _curtain = true);
      case AppLifecycleState.resumed:
        final since = _backgroundAt;
        _backgroundAt = null;
        if (since != null && !_covered) {
          final away = DateTime.now().difference(since);
          // Đồng hồ bị lùi (away âm) cũng khoá.
          if (away.isNegative || away >= AppLock.lockAfter) _lockNow();
        }
        if (_curtain) setState(() => _curtain = false);
        if (_status == _Status.disconnected) _connect();
      default:
    }
  }

  Future<TtydSession?> _freshSession() async {
    if (!_settings.rememberPassword || _settings.username.isEmpty || _settings.password.isEmpty) return null;
    return login(_settings.host, _settings.username, _settings.password);
  }

  Future<void> _reconnect() async {
    if (!mounted || _covered || _loggingOut || _connecting) return;
    final old = _conn;
    _conn = null;
    if (old != null) unawaited(old.close().catchError((Object _) {}));
    await _connect();
  }

  /// Đang khoá thì không mở WS (shell + lệnh tự chạy chỉ chạy sau khi xác thực bước 2);
  /// `_onUnlocked` gọi lại.
  Future<void> _connect() async {
    if (!mounted || _covered || _loggingOut || _connecting || (_conn?.isOpen ?? false)) return;
    _connecting = true;
    setState(() {
      _status = _Status.connecting;
      _error = null;
    });
    try {
      TtydConnection? conn;
      if (_session != null) {
        try {
          conn = await _open(_session!);
        } on WebSocketException catch (e) {
          if (!e.message.contains('401')) rethrow;
          _session = null;
        }
      }
      if (conn == null) {
        _session = await _freshSession();
        if (_session == null) {
          if (mounted) showLogin(context, _settings, error: 'Phiên đã hết hạn, đăng nhập lại.');
          return;
        }
        conn = await _open(_session!);
      }
      if (!mounted || _loggingOut) {
        conn.close();
        return;
      }
      final opened = conn;
      _conn?.close();
      _conn = opened;
      setState(() => _status = _Status.connected);
      final startup = _settings.startupCommand.trim();
      if (startup.isNotEmpty) {
        opened.firstOutput.timeout(const Duration(seconds: 3), onTimeout: () {}).then((_) {
          if (_conn == opened) opened.input('$startup\r');
        });
      }
      if (!_covered) _inputKey.currentState?.show();
      final openedAt = DateTime.now();
      conn.done.then((_) {
        if (!mounted || _conn != conn) return;
        _terminal.write('\r\n\x1b[33m[Mất kết nối]\x1b[0m\r\n');
        setState(() => _status = _Status.disconnected);
        final resumed = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
        if (resumed && DateTime.now().difference(openedAt) > const Duration(seconds: 5)) _connect();
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.wrongCredentials) {
        await _logout(error: e.message);
        return;
      }
      setState(() {
        _status = _Status.disconnected;
        _error = e.message;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.disconnected;
        _error = 'Không kết nối được: $e';
      });
    } finally {
      _connecting = false;
    }
  }

  Future<TtydConnection> _open(TtydSession session) {
    return TtydConnection.open(
      session,
      columns: _terminal.viewWidth,
      rows: _terminal.viewHeight,
      onText: _terminal.write,
      onTitle: (t) {
        if (mounted) setState(() => _title = t);
      },
    );
  }

  void _send(String data) {
    final conn = _conn;
    if (conn == null || !conn.isOpen) return;
    conn.input(data);
  }

  String _withMods(String data) =>
      applyModifiers(data, ctrl: _mods.isOn(Mod.ctrl), alt: _mods.isOn(Mod.alt), shift: _mods.isOn(Mod.shift));

  bool _onTyped(String text) {
    _dismissSelectionAndMenu();
    _scrollToBottom();
    if (!_mods.any || text.runes.length != 1) {
      _terminal.textInput(text);
      return false;
    }
    _terminal.textInput(_withMods(text));
    _mods.consume();
    return true;
  }

  void _onDelete(int count) {
    _dismissSelectionAndMenu();
    _scrollToBottom();
    if (count == 1 && _mods.any) {
      _terminal.keyInput(TerminalKey.backspace, ctrl: _mods.isOn(Mod.ctrl), alt: _mods.isOn(Mod.alt));
      _mods.consume();
      return;
    }
    _terminal.textInput('\x7f' * count);
  }

  void _onEnter() {
    _dismissSelectionAndMenu();
    _scrollToBottom();
    _terminal.keyInput(TerminalKey.enter, alt: _mods.isOn(Mod.alt));
    _mods.consume();
  }

  void _onBarKey(TerminalKey key) {
    _dismissSelectionAndMenu();
    _scrollToBottom();
    _terminal.keyInput(key, ctrl: _mods.isOn(Mod.ctrl), alt: _mods.isOn(Mod.alt), shift: _mods.isOn(Mod.shift));
    _mods.consume();
    _inputKey.currentState?.reset();
  }

  void _onBarText(String text) {
    _onTyped(text);
    _inputKey.currentState?.reset();
  }

  void _onBarRaw(String data) {
    _dismissSelectionAndMenu();
    _scrollToBottom();
    _send(data);
    _inputKey.currentState?.reset();
  }

  Future<void> _paste() async {
    _dismissSelectionAndMenu();
    _scrollToBottom();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    _terminal.paste(text);
    _inputKey.currentState?.reset();
  }

  bool get _isKeyboardOpen =>
      MediaQuery.viewInsetsOf(context).bottom > 0 || (_focus.hasFocus && (_inputKey.currentState?.isAttached ?? false));

  void _hideKeyboard() {
    _inputKey.currentState?.hide();
    if (_focus.hasFocus) _focus.unfocus();
  }

  void _toggleKeyboard() {
    if (_isKeyboardOpen) {
      _hideKeyboard();
    } else {
      _inputKey.currentState?.show();
    }
  }

  void _dismissSelectionAndMenu() {
    if (_contextMenuController.isShown) {
      _contextMenuController.remove();
    }
    if (_controller.selection != null) {
      _controller.clearSelection();
    }
  }

  void _showContextMenu([Offset? fallbackGlobalPos]) {
    if (!mounted) return;
    final selection = _controller.selection?.normalized;
    final hasSelection = selection != null && _terminal.buffer.getText(selection).isNotEmpty;
    final items = <ContextMenuButtonItem>[
      if (hasSelection) ContextMenuButtonItem(label: 'Sao chép', onPressed: _copySelection),
      ContextMenuButtonItem(label: 'Dán', onPressed: _pasteFromMenu),
      ContextMenuButtonItem(label: 'Chọn tất cả', onPressed: _selectAll),
    ];
    final anchors = _menuAnchors(selection, fallbackGlobalPos);
    _contextMenuController.show(
      context: context,
      contextMenuBuilder: (_) => AdaptiveTextSelectionToolbar.buttonItems(
        anchors: anchors,
        buttonItems: items,
      ),
    );
  }

  TextSelectionToolbarAnchors _menuAnchors(BufferRange? selection, Offset? fallbackGlobalPos) {
    final state = _terminalViewKey.currentState;
    if (selection != null && state != null && state.mounted) {
      final render = state.renderTerminal;
      if (render.attached) {
        final beginGlobal = render.localToGlobal(render.getOffset(selection.begin));
        final endGlobal = render.localToGlobal(render.getOffset(selection.end));
        final topLeft = render.localToGlobal(Offset.zero);
        final bottomRight = render.localToGlobal(Offset(render.size.width, render.size.height));
        final topY = math.min(beginGlobal.dy, endGlobal.dy).clamp(topLeft.dy, bottomRight.dy);
        final bottomY = (math.max(beginGlobal.dy, endGlobal.dy) + render.cellSize.height).clamp(topLeft.dy, bottomRight.dy);
        final centerX = selection.begin.y == selection.end.y
            ? ((beginGlobal.dx + endGlobal.dx) / 2).clamp(topLeft.dx + 16, bottomRight.dx - 16)
            : (topLeft.dx + bottomRight.dx) / 2;
        return TextSelectionToolbarAnchors(
          primaryAnchor: Offset(centerX, topY - 12),
          secondaryAnchor: Offset(centerX, bottomY + 36),
        );
      }
    }
    final pos = fallbackGlobalPos ?? MediaQuery.sizeOf(context).center(Offset.zero);
    return TextSelectionToolbarAnchors(
      primaryAnchor: pos - const Offset(0, 12),
      secondaryAnchor: pos + const Offset(0, 16),
    );
  }

  Future<void> _copySelection() async {
    final selection = _controller.selection;
    _dismissSelectionAndMenu();
    if (selection == null) return;
    final text = _terminal.buffer.getText(selection);
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Đã sao chép'), duration: Duration(milliseconds: 1200)));
  }

  void _pasteFromMenu() {
    _paste();
  }

  void _selectAll() {
    final height = _terminal.buffer.height;
    final viewHeight = _terminal.viewHeight;
    if (height <= 0 || _terminal.viewWidth <= 0) return;
    final lineHeight = _lineHeight;
    final int startRow;
    final int endRow;
    if (!_isAltBuffer && _scrollController.hasClients && lineHeight > 0) {
      final firstVisible = (_scrollController.position.pixels ~/ lineHeight).clamp(0, height - 1);
      startRow = firstVisible;
      endRow = (firstVisible + viewHeight - 1).clamp(startRow, height - 1);
    } else {
      startRow = (height - viewHeight).clamp(0, height - 1);
      endRow = height - 1;
    }
    _controller.setSelection(
      _terminal.buffer.createAnchor(0, startRow),
      _terminal.buffer.createAnchor(_terminal.viewWidth, endRow),
      mode: SelectionMode.line,
    );
    _showContextMenu();
  }

  void _startLongPressSelection(Offset globalPos) {
    final state = _terminalViewKey.currentState;
    if (state == null || !state.mounted) return;
    final render = state.renderTerminal;
    if (!render.attached) return;
    final cell = render.getCellOffset(render.globalToLocal(globalPos));
    final word = _terminal.buffer.getWordBoundary(cell);
    if (word != null) {
      _longPressOriginWord = word;
      _lastLongPressCell = cell;
      _controller.setSelection(
        _terminal.buffer.createAnchorFromOffset(word.begin),
        _terminal.buffer.createAnchorFromOffset(word.end),
        mode: SelectionMode.line,
      );
      return;
    }
    if (cell.y < _terminal.buffer.lines.length) {
      final codePoint = _terminal.buffer.lines[cell.y].getCodePoint(cell.x);
      if (codePoint != 0 && codePoint != 0x20) {
        final end = CellOffset((cell.x + 1).clamp(0, _terminal.viewWidth), cell.y);
        final range = BufferRangeLine(cell, end);
        _longPressOriginWord = range;
        _lastLongPressCell = cell;
        _controller.setSelection(
          _terminal.buffer.createAnchorFromOffset(range.begin),
          _terminal.buffer.createAnchorFromOffset(range.end),
          mode: SelectionMode.line,
        );
        return;
      }
    }
    _longPressOriginWord = null;
    _lastLongPressCell = null;
  }

  void _updateLongPressSelection(Offset globalPos) {
    final origin = _longPressOriginWord;
    final state = _terminalViewKey.currentState;
    if (origin == null || state == null || !state.mounted) return;
    final render = state.renderTerminal;
    if (!render.attached) return;
    final cell = render.getCellOffset(render.globalToLocal(globalPos));
    if (cell == _lastLongPressCell) return;
    _lastLongPressCell = cell;
    HapticFeedback.selectionClick();
    final targetWord = _terminal.buffer.getWordBoundary(cell);
    final BufferRangeLine range;
    if (targetWord != null) {
      range = origin.merge(targetWord);
    } else {
      final cellEnd = CellOffset((cell.x + 1).clamp(0, _terminal.viewWidth), cell.y);
      range = cell.isBefore(origin.begin)
          ? BufferRangeLine(cell, origin.end)
          : BufferRangeLine(origin.begin, cellEnd.isAfter(origin.end) ? cellEnd : origin.end);
    }
    _controller.setSelection(
      _terminal.buffer.createAnchorFromOffset(range.begin),
      _terminal.buffer.createAnchorFromOffset(range.end),
      mode: SelectionMode.line,
    );
  }

  void _onAltScrollStart(DragStartDetails details) {
    _altFling.stop();
    _altScrollCarry = 0;
    _dismissSelectionAndMenu();
    final state = _terminalViewKey.currentState;
    if (state != null && state.mounted && state.renderTerminal.attached) {
      _altScrollLocalPos = state.renderTerminal.globalToLocal(details.globalPosition);
    } else {
      _altScrollLocalPos = null;
    }
  }

  void _onAltScrollUpdate(DragUpdateDetails details) {
    final state = _terminalViewKey.currentState;
    if (state == null || !state.mounted || !state.renderTerminal.attached) return;
    _altScrollLocalPos = state.renderTerminal.globalToLocal(details.globalPosition);
    _consumeAltScrollDelta(details.delta.dy);
  }

  void _onAltScrollEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (velocity.abs() < 120) return;
    _altFlingLast = 0;
    _altFling.animateWith(FrictionSimulation(0.08, 0, velocity));
  }

  void _onAltFlingTick() {
    if (!_isAltBuffer) {
      _altFling.stop();
      return;
    }
    final current = _altFling.value;
    final delta = current - _altFlingLast;
    _altFlingLast = current;
    _consumeAltScrollDelta(delta);
  }

  void _consumeAltScrollDelta(double dy) {
    final state = _terminalViewKey.currentState;
    if (state == null || !state.mounted) return;
    final render = state.renderTerminal;
    if (!render.attached) return;
    final lineHeight = render.lineHeight;
    if (lineHeight <= 0) return;
    _altScrollCarry += dy;
    final steps = _altScrollCarry ~/ lineHeight;
    if (steps == 0) return;
    _altScrollCarry -= steps * lineHeight;
    final up = steps > 0;
    final pos = _altScrollLocalPos ?? Offset(render.size.width / 2, render.size.height / 2);
    final cell = render.getCellOffset(pos);
    for (var i = 0; i < steps.abs(); i++) {
      final handled = _terminal.mouseInput(
        up ? TerminalMouseButton.wheelUp : TerminalMouseButton.wheelDown,
        TerminalMouseButtonState.down,
        cell,
      );
      if (!handled) {
        _terminal.keyInput(up ? TerminalKey.arrowUp : TerminalKey.arrowDown);
      }
    }
  }

  double get _touchSlop => MediaQuery.maybeGestureSettingsOf(context)?.touchSlop ?? kTouchSlop;

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse && event.buttons != kPrimaryButton) {
      return;
    }
    _altFling.stop();
    _activePointers.add(event.pointer);
    if (_activePointers.length > 1) {
      _multiTouchUsed = true;
      _longPressTimer?.cancel();
      _longPressTimer = null;
      _longPressTriggered = false;
      _longPressOriginWord = null;
      _lastLongPressCell = null;
      _singlePointer = null;
      return;
    }

    _singlePointer = event.pointer;
    _pointerDownPos = event.position;
    _movedBeyondSlop = false;
    _multiTouchUsed = false;
    _longPressTriggered = false;
    _longPressOriginWord = null;
    _lastLongPressCell = null;
    _hadSelectionOrMenuOnDown = _controller.selection != null || _contextMenuController.isShown;
    _wasKeyboardOpenOnDown = _isKeyboardOpen;

    _longPressTimer?.cancel();
    if (event.kind == PointerDeviceKind.touch) {
      final pointer = event.pointer;
      final downPos = event.position;
      _longPressTimer = Timer(kLongPressTimeout, () {
        if (!mounted || _singlePointer != pointer || _movedBeyondSlop || _multiTouchUsed) {
          return;
        }
        _longPressTriggered = true;
        HapticFeedback.mediumImpact();
        _startLongPressSelection(downPos);
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _singlePointer) return;
    if (_longPressTriggered) {
      _updateLongPressSelection(event.position);
      return;
    }
    if (_movedBeyondSlop) return;
    final downPos = _pointerDownPos;
    if (downPos != null && (event.position - downPos).distance > _touchSlop) {
      _movedBeyondSlop = true;
      _longPressTimer?.cancel();
      _longPressTimer = null;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    final isSingle = event.pointer == _singlePointer;
    final downPos = _pointerDownPos;
    final wasLongPress = _longPressTriggered;
    final wasMoved = _movedBeyondSlop;
    final wasMultiTouch = _multiTouchUsed;
    final hadSelectionOrMenu = _hadSelectionOrMenuOnDown;
    final wasKeyboardOpen = _wasKeyboardOpenOnDown;

    if (isSingle) {
      _longPressTimer?.cancel();
      _longPressTimer = null;
      _longPressTriggered = false;
      _longPressOriginWord = null;
      _lastLongPressCell = null;
      _singlePointer = null;
      _pointerDownPos = null;
    }
    if (_activePointers.isEmpty) {
      _multiTouchUsed = false;
    }

    if (!isSingle || wasMultiTouch) return;

    if (wasLongPress) {
      _showContextMenu(event.position);
      return;
    }

    if (wasMoved || downPos == null || (event.position - downPos).distance > _touchSlop) {
      return;
    }

    if (hadSelectionOrMenu) {
      _dismissSelectionAndMenu();
      return;
    }

    if (_controller.selection != null) {
      _showContextMenu(event.position);
      return;
    }

    if (wasKeyboardOpen) {
      _hideKeyboard();
    } else {
      _inputKey.currentState?.show();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (event.pointer == _singlePointer) {
      _longPressTimer?.cancel();
      _longPressTimer = null;
      _longPressTriggered = false;
      _longPressOriginWord = null;
      _lastLongPressCell = null;
      _singlePointer = null;
      _pointerDownPos = null;
    }
    if (_activePointers.isEmpty) {
      _multiTouchUsed = false;
    }
  }

  void _onPinchStart() {
    _altFling.stop();
    _dismissSelectionAndMenu();
    _pinching = true;
    _controller.setSuspendPointerInput(true);
    _pinchBaseFontSize = _settings.fontSize;
    setState(() {});
  }

  void _onPinchUpdate(double scale) {
    final next = snapFontSize(_pinchBaseFontSize * scale);
    if (next != _settings.fontSize) {
      setState(() => _settings.fontSize = next);
    }
  }

  void _onPinchEnd() {
    _pinching = false;
    _controller.setSuspendPointerInput(_controller.selection != null);
    setState(() {});
    _settings.save();
  }

  Future<void> _openSettings() async {
    _dismissSelectionAndMenu();
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(settings: _settings),
    );
    if (changed == true && mounted) setState(() {});
  }

  /// Đăng xuất: đóng WS, quên mật khẩu và mã PIN (đăng nhập lại bằng mật khẩu thì tạo PIN mới).
  Future<void> _logout({String? error}) async {
    if (_loggingOut) return;
    _loggingOut = true;
    _dismissSelectionAndMenu();
    final conn = _conn;
    _conn = null;
    await conn?.close();
    await _settings.forgetPassword();
    await _settings.save();
    await _lock.clear();
    if (mounted) showLogin(context, _settings, error: error);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Màn khoá phủ lên: terminal phía dưới không nhận chạm, focus (bàn phím cứng), VoiceOver.
        ExcludeSemantics(
          excluding: _covered,
          child: ExcludeFocus(
            excluding: _covered,
            child: IgnorePointer(ignoring: _covered, child: _terminalScaffold(context)),
          ),
        ),
        if (_curtain && !_covered) const Positioned.fill(child: ColoredBox(color: Color(0xFF111214))),
        if (_covered)
          Positioned.fill(
            child: LockScreen(
              key: ValueKey((_lockRound, _pinSetup)),
              lock: _lock,
              setup: _pinSetup,
              onUnlocked: _onUnlocked,
              onLogout: (error) => _logout(error: error),
            ),
          ),
      ],
    );
  }

  Widget _terminalScaffold(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = keyboardInset > 0;
    final showKeyBar = keyboardVisible && (_inputKey.currentState?.isAttached ?? false);
    if (_lastKeyboardVisible && !keyboardVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && MediaQuery.viewInsetsOf(context).bottom == 0 && (_inputKey.currentState?.isAttached ?? false)) {
          _hideKeyboard();
        }
      });
    }
    _lastKeyboardVisible = keyboardVisible;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        toolbarHeight: 40,
        titleSpacing: 12,
        title: Row(
          children: [
            Icon(
              Icons.circle,
              size: 10,
              color: switch (_status) {
                _Status.connected => const Color(0xFF22C55E),
                _Status.connecting => const Color(0xFFF59E0B),
                _Status.disconnected => const Color(0xFFEF4444),
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _title.isNotEmpty ? _title : _settings.host,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          if (_status == _Status.disconnected)
            IconButton(tooltip: 'Kết nối lại', icon: const Icon(Icons.refresh), onPressed: _reconnect),
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'reconnect' => _reconnect(),
              'settings' => _openSettings(),
              'logout' => _logout(),
              _ => null,
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'reconnect', enabled: !_connecting, child: const Text('Kết nối lại')),
              const PopupMenuItem(value: 'settings', child: Text('Cài đặt')),
              const PopupMenuItem(value: 'logout', child: Text('Đăng xuất, quên mật khẩu')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [TextButton(onPressed: _reconnect, child: const Text('Thử lại'))],
            ),
          Expanded(
            child: Stack(
              children: [
                Listener(
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  onPointerCancel: _onPointerCancel,
                  child: RawGestureDetector(
                    gestures: {
                      PinchGestureRecognizer: GestureRecognizerFactoryWithHandlers<PinchGestureRecognizer>(
                        () => PinchGestureRecognizer(debugOwner: this),
                        (instance) {
                          instance
                            ..onPinchStart = _onPinchStart
                            ..onPinchUpdate = _onPinchUpdate
                            ..onPinchEnd = _onPinchEnd;
                        },
                      ),
                      if (_isAltBuffer)
                        VerticalDragGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
                          () => VerticalDragGestureRecognizer(debugOwner: this),
                          (instance) {
                            instance
                              ..onStart = _onAltScrollStart
                              ..onUpdate = _onAltScrollUpdate
                              ..onEnd = _onAltScrollEnd;
                          },
                        ),
                    },
                    child: TerminalInput(
                      key: _inputKey,
                      focusNode: _focus,
                      onTyped: _onTyped,
                      onDelete: _onDelete,
                      onEnter: _onEnter,
                      onAttachChanged: _onInputAttachChanged,
                      child: ScrollConfiguration(
                        behavior: TerminalScrollBehavior(altBuffer: _isAltBuffer),
                        child: Scrollbar(
                          controller: _scrollController,
                          child: TerminalView(
                            _terminal,
                            key: _terminalViewKey,
                            controller: _controller,
                            scrollController: _scrollController,
                            focusNode: _focus,
                            hardwareKeyboardOnly: true,
                            textStyle: TerminalStyle(fontSize: _settings.fontSize, fontFamily: terminalFontFamily),
                            padding: const EdgeInsets.all(4),
                            onKeyEvent: (_, event) {
                              if (event is KeyDownEvent &&
                                  !HardwareKeyboard.instance.isControlPressed &&
                                  !HardwareKeyboard.instance.isMetaPressed) {
                                _dismissSelectionAndMenu();
                              }
                              return KeyEventResult.ignored;
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!_covered && _status != _Status.connected)
                  Positioned(
                    left: 16,
                    right: _isScrolledUp && !_isAltBuffer ? 72 : 16,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      minimum: const EdgeInsets.only(bottom: 16),
                      child: Center(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: _status == _Status.disconnected
                              ? () {
                                  HapticFeedback.lightImpact();
                                  _reconnect();
                                }
                              : null,
                          icon: _status == _Status.connecting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(_status == _Status.connecting ? 'Đang kết nối…' : 'Kết nối lại'),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: TerminalSelectionHandles(
                    terminal: _terminal,
                    controller: _controller,
                    scrollController: _scrollController,
                    terminalViewKey: _terminalViewKey,
                    onDragStart: () {
                      _draggingHandle = true;
                      _contextMenuController.remove();
                    },
                    onDragEnd: () {
                      _draggingHandle = false;
                      if (_controller.selection != null) _showContextMenu();
                    },
                  ),
                ),
                if (_isScrolledUp && !_isAltBuffer)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Material(
                      color: const Color(0xCC26282C),
                      shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
                      child: IconButton(
                        tooltip: 'Cuộn xuống cuối',
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _scrollToBottom();
                        },
                      ),
                    ),
                  ),
                if (_pinching)
                  IgnorePointer(
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xCC000000),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            '${formatFontSize(_settings.fontSize)} pt',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              heightFactor: showKeyBar ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: KeyBar(
                    modifiers: _mods,
                    hiddenKeys: _settings.hiddenKeyBarKeys,
                    showSecondRow: _settings.showSecondKeyRow,
                    onKey: _onBarKey,
                    onRaw: _onBarRaw,
                    onText: _onBarText,
                    onPaste: _paste,
                    onToggleKeyboard: _toggleKeyboard,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.settings});

  final Settings settings;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late double _fontSize = snapFontSize(widget.settings.fontSize);
  late final _startup = TextEditingController(text: widget.settings.startupCommand);
  late bool _showSecondKeyRow = widget.settings.showSecondKeyRow;
  late Set<String> _hiddenKeys = Set<String>.from(widget.settings.hiddenKeyBarKeys);

  @override
  void dispose() {
    _startup.dispose();
    super.dispose();
  }

  Future<void> _customizeKeyBar() async {
    final updated = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => KeyBarCustomizationSheet(initialHiddenKeys: _hiddenKeys, showSecondRow: _showSecondKeyRow),
    );
    if (updated != null && mounted) {
      setState(() => _hiddenKeys = updated);
    }
  }

  Future<void> _save() async {
    widget.settings
      ..fontSize = _fontSize
      ..startupCommand = _startup.text
      ..showSecondKeyRow = _showSecondKeyRow
      ..hiddenKeyBarKeys = Set<String>.from(_hiddenKeys);
    await widget.settings.save();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final available = [
      for (final item in keyBarCatalog)
        if (_showSecondKeyRow || item.row == 1) item,
    ];
    final visibleKeys = available.where((e) => !_hiddenKeys.contains(e.id)).length;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cỡ chữ: ${formatFontSize(_fontSize)} pt'),
              Slider(
                value: _fontSize,
                min: minTerminalFontSize,
                max: maxTerminalFontSize,
                divisions: terminalFontSizeDivisions,
                onChanged: (v) => setState(() => _fontSize = snapFontSize(v)),
              ),
              TextField(
                controller: _startup,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Lệnh tự chạy khi kết nối',
                  hintText: 'vd: tmux new -A -s main',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hiện hàng phím thứ hai'),
                subtitle: const Text('^C, Home/End, ký tự, Dán…'),
                value: _showSecondKeyRow,
                onChanged: (v) => setState(() => _showSecondKeyRow = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tuỳ chỉnh phím hiển thị'),
                subtitle: Text('$visibleKeys/${available.length} phím đang hiện'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _customizeKeyBar,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: const Text('Lưu')),
            ],
          ),
        ),
      ),
    );
  }
}
