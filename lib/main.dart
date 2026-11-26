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
      home: settings.rememberPassword && settings.username.isNotEmpty && settings.password.isNotEmpty
          ? TerminalScreen(settings: settings, lockOnStart: true)
          : LoginScreen(settings: settings),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.settings, this.error});

  final Settings settings;
  final String? error;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _host = TextEditingController(text: widget.settings.host);
  late final _user = TextEditingController(text: widget.settings.username);
  late final _pass = TextEditingController(text: widget.settings.password);
  late bool _remember = widget.settings.rememberPassword;
  late String? _error = widget.error;
  bool _busy = false;

  Future<void> _submit() async {
    final s = widget.settings;
    s
      ..host = normalizeHost(_host.text)
      ..username = _user.text.trim()
      ..password = _pass.text
      ..rememberPassword = _remember;
    if (s.host.isEmpty || s.username.isEmpty || s.password.isEmpty) {
      setState(() => _error = 'Nhập đủ host, username, mật khẩu.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await login(s.host, s.username, s.password);
      await s.save();
      if (!s.rememberPassword) s.password = '';
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TerminalScreen(settings: s, initialSession: session)),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } on Object catch (e) {
      setState(() => _error = 'Lỗi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _host.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    Text('Terminal', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Color(0xFFF87171))),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _host,
                      decoration: const InputDecoration(labelText: 'Host', border: OutlineInputBorder()),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _user,
                      decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                      autofillHints: const [AutofillHints.username],
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      decoration: const InputDecoration(labelText: 'Mật khẩu', border: OutlineInputBorder()),
                      autofillHints: const [AutofillHints.password],
                      obscureText: true,
                      onSubmitted: (_) => _submit(),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v ?? false),
                      title: const Text('Nhớ mật khẩu (Keychain), tự đăng nhập lại'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _busy
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Đăng nhập'),
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

void showLogin(BuildContext context, Settings settings, {String? error}) {
  SystemChannels.textInput.invokeMethod('TextInput.hide');
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => LoginScreen(settings: settings, error: error)),
  );
}
