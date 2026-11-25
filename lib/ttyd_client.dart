import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class AuthException implements Exception {
  AuthException(this.message, {this.wrongCredentials = false});
  final String message;
  final bool wrongCredentials;
  @override
  String toString() => message;
}

class TtydSession {
  TtydSession({required this.host, required this.cookie, required this.tabKey});
  final String host;
  final String cookie;
  final String tabKey;
}

final _tabKeyPattern = RegExp(r'var k="([^"]+)"');

HttpClient _httpClient() => HttpClient()..connectionTimeout = const Duration(seconds: 15);

String normalizeHost(String input) {
  var h = input.trim();
  h = h.replaceFirst(RegExp(r'^[a-zA-Z]+://'), '');
  final slash = h.indexOf('/');
  return slash < 0 ? h : h.substring(0, slash);
}

Future<TtydSession> login(String host, String username, String password) {
  return _login(host, username, password).timeout(
    const Duration(seconds: 30),
    onTimeout: () => throw AuthException('Hết thời gian chờ server.'),
  );
}

Future<TtydSession> _login(String host, String username, String password) async {
  final client = _httpClient();
  try {
    final post = await client.postUrl(Uri.https(host, '/login'));
    post.followRedirects = false;
    post.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    post.write(Uri(queryParameters: {'username': username, 'password': password}).query);
    final res = await post.close();
    await res.drain<void>();
    if (res.statusCode == 429) {
      throw AuthException('Sai quá nhiều lần, thử lại sau 15 phút.');
    }
    if (res.statusCode == 401) {
      throw AuthException('Sai username hoặc mật khẩu.', wrongCredentials: true);
    }
    final cookie = res.cookies.where((c) => c.name.startsWith('ttyd_')).lastOrNull;
    if (res.statusCode != 303 || cookie == null) {
      throw AuthException('Đăng nhập lỗi (HTTP ${res.statusCode}).');
    }
    final cookieHeader = '${cookie.name}=${cookie.value}';

    final get = await client.getUrl(Uri.https(host, '/'));
    get.followRedirects = false;
    get.headers.set(HttpHeaders.cookieHeader, cookieHeader);
    final page = await get.close();
    final html = await page.transform(utf8.decoder).join();
    final key = _tabKeyPattern.firstMatch(html)?.group(1);
    if (page.statusCode != 200 || key == null) {
      throw AuthException('Không lấy được khóa phiên (HTTP ${page.statusCode}).');
    }
    return TtydSession(host: host, cookie: cookieHeader, tabKey: key);
  } on SocketException catch (e) {
    throw AuthException('Không kết nối được $host: ${e.message}');
  } on HandshakeException catch (e) {
    throw AuthException('Lỗi TLS: ${e.message}');
  } on HttpException catch (e) {
    throw AuthException('Lỗi HTTP: ${e.message}');
  } on FormatException catch (e) {
    throw AuthException('Host không hợp lệ: ${e.message}');
  } finally {
    client.close();
  }
}

class _Utf8ToTerminal implements Sink<String> {
  _Utf8ToTerminal(this.onText);
  final void Function(String) onText;
  @override
  void add(String data) => onText(data);
  @override
  void close() {}
}

class TtydConnection {
  TtydConnection._(this._ws, void Function(String) onText, this.onTitle) {
    _decoder = const Utf8Decoder(allowMalformed: true).startChunkedConversion(_Utf8ToTerminal(onText));
  }

  final WebSocket _ws;
  final void Function(String)? onTitle;
  late final ByteConversionSink _decoder;
  final _closed = Completer<void>();
  final _firstOutput = Completer<void>();
  StreamSubscription<dynamic>? _sub;

  Future<void> get firstOutput => _firstOutput.future;

  Future<void> get done => _closed.future;
  bool get isOpen => _ws.readyState == WebSocket.open;

  static Future<TtydConnection> open(
    TtydSession session, {
    required int columns,
    required int rows,
    required void Function(String) onText,
    void Function(String)? onTitle,
  }) async {
    final uri = Uri(scheme: 'wss', host: session.host, path: '/ws', queryParameters: {'k': session.tabKey});
    final ws = await WebSocket.connect(
      uri.toString(),
      protocols: const ['tty'],
      headers: {HttpHeaders.cookieHeader: session.cookie, 'Origin': 'https://${session.host}'},
    ).timeout(const Duration(seconds: 15));
    ws.pingInterval = const Duration(seconds: 10);
    final conn = TtydConnection._(ws, onText, onTitle);
    ws.add(utf8.encode(jsonEncode({'AuthToken': '', 'columns': columns, 'rows': rows})));
    conn._sub = ws.listen(conn._onMessage, onDone: conn._finish, onError: (_) => conn._finish(), cancelOnError: true);
    return conn;
  }

  void _onMessage(dynamic message) {
    final bytes = message is String ? utf8.encode(message) : message as List<int>;
    if (bytes.isEmpty) return;
    switch (bytes[0]) {
      case 0x30:
        _decoder.add(bytes.sublist(1));
        if (!_firstOutput.isCompleted) _firstOutput.complete();
      case 0x31:
        onTitle?.call(utf8.decode(bytes.sublist(1), allowMalformed: true));
    }
  }

  void _finish() {
    if (!_closed.isCompleted) _closed.complete();
  }

  void _send(int type, List<int> payload) {
    if (!isOpen) return;
    _ws.add(Uint8List.fromList([type, ...payload]));
  }

  void input(String data) => _send(0x30, utf8.encode(data));

  void resize(int columns, int rows) => _send(0x31, utf8.encode(jsonEncode({'columns': columns, 'rows': rows})));

  Future<void> close() async {
    await _sub?.cancel();
    await _ws.close();
    _finish();
  }
}
