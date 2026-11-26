import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'settings.dart';
import 'terminal_screen.dart';
import 'ttyd_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await Settings.load();
  runApp(TtydKeysApp(settings: settings));
}

class TtydKeysApp extends StatelessWidget {
  const TtydKeysApp({super.key, required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TapShell',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF3B82F6), brightness: Brightness.dark),
      home: settings.hasAnyPassword
          ? TerminalScreen(settings: settings, lockOnStart: true)
          : LoginScreen(settings: settings, server: settings.activeServer),
    );
  }
}

class LoginResult {
  const LoginResult({required this.profile, required this.session});

  final ServerProfile profile;
  final TtydSession session;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.settings,
    this.server,
    this.error,
    this.isRoot = true,
  });

  final Settings settings;
  final ServerProfile? server;
  final String? error;
  final bool isRoot;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _name = TextEditingController(text: widget.server?.name ?? '');
  late final _host = TextEditingController(
    text: widget.server?.host ?? (widget.settings.servers.isEmpty ? defaultHost : ''),
  );
  late final _user = TextEditingController(text: widget.server?.username ?? '');
  late final _pass = TextEditingController(text: widget.server?.password ?? '');
  late final _startup = TextEditingController(text: widget.server?.startupCommand ?? defaultStartupCommand);
  late String? _error = widget.error;
  bool _busy = false;

  Future<void> _submit() async {
    final s = widget.settings;
    final editing = widget.server;
    final name = _name.text.trim();
    final host = normalizeHost(_host.text);
    final username = _user.text.trim();
    final password = _pass.text;
    final startupCommand = _startup.text;

    if (host.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Nhập đủ host, username, mật khẩu.');
      return;
    }

    final duplicate = s.servers.any(
      (item) =>
          item.id != editing?.id &&
          item.host.toLowerCase() == host.toLowerCase() &&
          item.username == username,
    );
    if (duplicate) {
      setState(() => _error = 'Server này đã có trong danh sách.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await login(host, username, password);
      final ServerProfile profile;
      if (editing != null) {
        editing
          ..name = name
          ..host = host
          ..username = username
          ..password = password
          ..startupCommand = startupCommand;
        profile = editing;
      } else {
        profile = ServerProfile(
          id: Settings.newServerId(),
          name: name,
          host: host,
          username: username,
          password: password,
          startupCommand: startupCommand,
        );
        s.servers.add(profile);
      }
      s.activeServerId = profile.id;
      await s.save();
      if (!mounted) return;
      if (widget.isRoot) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => TerminalScreen(settings: s, initialSession: session)),
        );
      } else {
        Navigator.of(context).pop(LoginResult(profile: profile, session: session));
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Lỗi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _user.dispose();
    _pass.dispose();
    _startup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.server != null;
    final submitLabel = isEdit && widget.server!.password.isNotEmpty ? 'Lưu' : 'Đăng nhập';
    return Scaffold(
      appBar: widget.isRoot ? null : AppBar(title: Text(isEdit ? 'Sửa server' : 'Thêm server')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.isRoot) ...[
                      Text(isEdit ? 'Đăng nhập' : 'Terminal', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                    ],
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Color(0xFFF87171))),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Tên hiển thị (tuỳ chọn)',
                        hintText: 'vd: VPS công ty',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _host,
                      decoration: const InputDecoration(
                        labelText: 'Host',
                        hintText: 'vd: ttyd.example.com',
                        helperText: 'Tên miền trang ttyd, dán cả link https://… cũng được',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _user,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'vd: admin',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: OutlineInputBorder(),
                      ),
                      autofillHints: const [AutofillHints.username],
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu',
                        hintText: 'Mật khẩu đăng nhập ttyd',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: OutlineInputBorder(),
                      ),
                      autofillHints: const [AutofillHints.password],
                      obscureText: true,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _startup,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Lệnh tự chạy khi kết nối',
                        hintText: 'vd: tmux new -A -s main',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _busy
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(submitLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showLogin(BuildContext context, Settings settings, {ServerProfile? server, String? error}) {
  SystemChannels.textInput.invokeMethod('TextInput.hide');
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => LoginScreen(settings: settings, server: server, error: error)),
  );
}
