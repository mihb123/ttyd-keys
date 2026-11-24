import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xterm/xterm.dart';

import 'key_bar.dart';
import 'key_handler.dart';
import 'main.dart';
import 'modifiers.dart';
import 'settings.dart';
import 'terminal_input.dart';
import 'ttyd_client.dart';

enum _Status { connecting, connected, disconnected }

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key, required this.settings, this.initialSession});

  final Settings settings;
  final TtydSession? initialSession;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> with WidgetsBindingObserver {
  final _terminal = Terminal(maxLines: 10000, inputHandler: const FixedKeyHandler());
  final _inputKey = GlobalKey<TerminalInputState>();
  final _controller = TerminalController();
  final _focus = FocusNode();
  final _mods = Modifiers();

  late TtydSession? _session = widget.initialSession;
  TtydConnection? _conn;
  _Status _status = _Status.connecting;
  String? _error;
  String _title = '';
  bool _connecting = false;

  Settings get _settings => widget.settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _terminal.onOutput = _send;
    _terminal.onResize = (w, h, _, _) => _conn?.resize(w, h);
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _conn?.close();
    _focus.dispose();
    _mods.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _status == _Status.disconnected) {
      _connect();
    }
  }

  Future<TtydSession?> _freshSession() async {
    if (!_settings.rememberPassword || _settings.username.isEmpty || _settings.password.isEmpty) return null;
    return login(_settings.host, _settings.username, _settings.password);
  }

  Future<void> _connect() async {
    if (_connecting || (_conn?.isOpen ?? false)) return;
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
      if (!mounted) {
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
      _inputKey.currentState?.show();
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
        await _settings.forgetPassword();
        if (mounted) showLogin(context, _settings, error: e.message);
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

  String _withMods(String data) => applyModifiers(
        data,
        ctrl: _mods.isOn(Mod.ctrl),
        alt: _mods.isOn(Mod.alt),
        shift: _mods.isOn(Mod.shift),
      );

  bool _onTyped(String text) {
    if (!_mods.any || text.runes.length != 1) {
      _terminal.textInput(text);
      return false;
    }
    _terminal.textInput(_withMods(text));
    _mods.consume();
    return true;
  }

  void _onDelete(int count) {
    if (count == 1 && _mods.any) {
      _terminal.keyInput(
        TerminalKey.backspace,
        ctrl: _mods.isOn(Mod.ctrl),
        alt: _mods.isOn(Mod.alt),
      );
      _mods.consume();
      return;
    }
    _terminal.textInput('\x7f' * count);
  }

  void _onEnter() {
    _terminal.keyInput(TerminalKey.enter, alt: _mods.isOn(Mod.alt));
    _mods.consume();
  }

  void _onBarKey(TerminalKey key) {
    _terminal.keyInput(
      key,
      ctrl: _mods.isOn(Mod.ctrl),
      alt: _mods.isOn(Mod.alt),
      shift: _mods.isOn(Mod.shift),
    );
    _mods.consume();
    _inputKey.currentState?.reset();
  }

  void _onBarText(String text) {
    _onTyped(text);
    _inputKey.currentState?.reset();
  }

  void _onBarRaw(String data) {
    _send(data);
    _inputKey.currentState?.reset();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    _terminal.paste(text);
    _inputKey.currentState?.reset();
  }

  void _toggleKeyboard() {
    if (_focus.hasFocus) {
      _focus.unfocus();
    } else {
      _inputKey.currentState?.show();
    }
  }

  Future<void> _openSettings() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(settings: _settings),
    );
    if (changed == true && mounted) setState(() {});
  }

  Future<void> _logout() async {
    await _conn?.close();
    _conn = null;
    await _settings.forgetPassword();
    await _settings.save();
    if (mounted) showLogin(context, _settings);
  }

  @override
  Widget build(BuildContext context) {
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
            IconButton(tooltip: 'Kết nối lại', icon: const Icon(Icons.refresh), onPressed: _connect),
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'settings' => _openSettings(),
              'logout' => _logout(),
              _ => null,
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'settings', child: Text('Cài đặt')),
              PopupMenuItem(value: 'logout', child: Text('Đăng xuất, quên mật khẩu')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [TextButton(onPressed: _connect, child: const Text('Thử lại'))],
            ),
          Expanded(
            child: TerminalInput(
              key: _inputKey,
              focusNode: _focus,
              onTyped: _onTyped,
              onDelete: _onDelete,
              onEnter: _onEnter,
              child: TerminalView(
                _terminal,
                controller: _controller,
                focusNode: _focus,
                hardwareKeyboardOnly: true,
                textStyle: TerminalStyle(fontSize: _settings.fontSize),
                padding: const EdgeInsets.all(4),
                onTapUp: (_, _) => _inputKey.currentState?.show(),
              ),
            ),
          ),
          KeyBar(
            modifiers: _mods,
            onKey: _onBarKey,
            onRaw: _onBarRaw,
            onText: _onBarText,
            onPaste: _paste,
            onToggleKeyboard: _toggleKeyboard,
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
  late double _fontSize = widget.settings.fontSize;
  late final _startup = TextEditingController(text: widget.settings.startupCommand);

  @override
  void dispose() {
    _startup.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    widget.settings
      ..fontSize = _fontSize
      ..startupCommand = _startup.text;
    await widget.settings.save();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Cỡ chữ: ${_fontSize.round()}'),
          Slider(
            value: _fontSize,
            min: 9,
            max: 24,
            divisions: 15,
            onChanged: (v) => setState(() => _fontSize = v),
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
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Lưu')),
        ],
      ),
    );
  }
}
