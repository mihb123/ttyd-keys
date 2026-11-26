import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'fixed_terminal.dart';
import 'key_handler.dart';
import 'output_throttle.dart';
import 'settings.dart';
import 'ttyd_client.dart';

enum ServerStatus { idle, connecting, connected, disconnected }

class ServerSession extends ChangeNotifier {
  ServerSession({
    required this.profile,
    required this._settings,
    required this._canConnect,
    required this._isActive,
    required this._onNeedPassword,
    required this._onConnected,
    TtydSession? initialSession,
  }) : session = initialSession {
    terminal.onOutput = send;
    terminal.onResize = (w, h, _, _) => conn?.resize(w, h);
  }

  final ServerProfile profile;
  final Settings _settings;
  final bool Function() _canConnect;
  final bool Function() _isActive;
  final void Function(ServerSession session, String message) _onNeedPassword;
  final void Function(ServerSession session) _onConnected;

  final FixedTerminal terminal = FixedTerminal(
    maxLines: 10000,
    inputHandler: const FixedKeyHandler(),
    mouseHandler: const FixedMouseHandler(),
  );
  late final OutputThrottle output = OutputThrottle(
    write: terminal.write,
    onPause: () => conn?.pause(),
    onResume: () => conn?.resume(),
  );

  TtydSession? session;
  TtydConnection? conn;
  ServerStatus status = ServerStatus.idle;
  String? error;
  String title = '';
  bool connecting = false;
  bool needsPassword = false;

  int _connectGen = 0;
  bool _disposed = false;

  Future<TtydSession?> _freshSession() async {
    if (profile.username.isEmpty || profile.password.isEmpty) return null;
    return login(profile.host, profile.username, profile.password);
  }

  Future<void> reconnect() async {
    if (_disposed || !_canConnect() || connecting) return;
    final old = conn;
    conn = null;
    if (old != null) unawaited(old.close().catchError((Object _) {}));
    await connect();
  }

  Future<void> replaceSession(TtydSession newSession) async {
    if (_disposed) return;
    _connectGen++;
    connecting = false;
    session = newSession;
    title = '';
    needsPassword = false;
    error = null;
    final old = conn;
    conn = null;
    if (old != null) unawaited(old.close().catchError((Object _) {}));
    await connect();
  }

  /// Đang khoá thì không mở WS (shell + lệnh tự chạy chỉ chạy sau khi xác thực bước 2);
  /// `_onUnlocked` gọi lại.
  Future<void> connect() async {
    if (_disposed || !_canConnect() || connecting || (conn?.isOpen ?? false)) return;
    final gen = ++_connectGen;
    connecting = true;
    status = ServerStatus.connecting;
    error = null;
    needsPassword = false;
    notifyListeners();
    try {
      TtydConnection? nextConn;
      if (session != null) {
        try {
          nextConn = await _open(session!);
        } on WebSocketException catch (e) {
          if (!e.message.contains('401')) rethrow;
          session = null;
        }
      }
      if (_disposed || gen != _connectGen) {
        if (nextConn != null) unawaited(nextConn.close().catchError((Object _) {}));
        return;
      }
      if (nextConn == null) {
        session = await _freshSession();
        if (_disposed || gen != _connectGen) return;
        if (session == null) {
          final message = 'Nhập mật khẩu cho ${profile.label}.';
          status = ServerStatus.disconnected;
          error = message;
          needsPassword = true;
          connecting = false;
          notifyListeners();
          _onNeedPassword(this, message);
          return;
        }
        nextConn = await _open(session!);
      }
      if (_disposed || gen != _connectGen) {
        unawaited(nextConn.close().catchError((Object _) {}));
        return;
      }
      final opened = nextConn;
      conn?.close();
      conn = opened;
      output.resetFlow();
      status = ServerStatus.connected;
      connecting = false;
      notifyListeners();
      final startup = profile.startupCommand.trim();
      if (startup.isNotEmpty) {
        opened.firstOutput.timeout(const Duration(seconds: 3), onTimeout: () {}).then((_) {
          if (!_disposed && conn == opened) opened.input('$startup\r');
        });
      }
      _onConnected(this);
      final openedAt = DateTime.now();
      opened.done.then((_) {
        if (_disposed || conn != opened) return;
        output.add('\r\n\x1b[33m[Mất kết nối]\x1b[0m\r\n');
        status = ServerStatus.disconnected;
        notifyListeners();
        final resumed = SchedulerBinding.instance.lifecycleState == AppLifecycleState.resumed;
        if (resumed && _isActive() && DateTime.now().difference(openedAt) > const Duration(seconds: 5)) {
          connect();
        }
      });
    } on AuthException catch (e) {
      if (_disposed || gen != _connectGen) return;
      if (e.wrongCredentials) {
        session = null;
        await _settings.forgetPassword(profile);
        if (_disposed || gen != _connectGen) return;
        status = ServerStatus.disconnected;
        error = e.message;
        needsPassword = true;
        connecting = false;
        notifyListeners();
        _onNeedPassword(this, e.message);
        return;
      }
      status = ServerStatus.disconnected;
      error = e.message;
      connecting = false;
      notifyListeners();
    } on Object catch (e) {
      if (_disposed || gen != _connectGen) return;
      status = ServerStatus.disconnected;
      error = 'Không kết nối được: $e';
      connecting = false;
      notifyListeners();
    } finally {
      if (gen == _connectGen) connecting = false;
    }
  }

  Future<TtydConnection> _open(TtydSession s) {
    return TtydConnection.open(
      s,
      columns: terminal.viewWidth,
      rows: terminal.viewHeight,
      onText: output.add,
      onTitle: (t) {
        if (_disposed || title == t) return;
        title = t;
        notifyListeners();
      },
    );
  }

  void send(String data) {
    final c = conn;
    if (c == null || !c.isOpen) return;
    c.input(data);
  }

  void disconnect() {
    _connectGen++;
    connecting = false;
    final old = conn;
    conn = null;
    if (old != null) unawaited(old.close().catchError((Object _) {}));
    status = ServerStatus.idle;
    error = null;
    needsPassword = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectGen++;
    connecting = false;
    terminal.onOutput = null;
    terminal.onResize = null;
    final old = conn;
    conn = null;
    if (old != null) unawaited(old.close().catchError((Object _) {}));
    output.dispose();
    super.dispose();
  }
}
