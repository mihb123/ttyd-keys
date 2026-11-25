import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const defaultStartupCommand = 'tmux new -A -s mobile';

class Settings {
  Settings({
    this.host = 'remote-ocl.mihb.site',
    this.username = '',
    this.password = '',
    this.rememberPassword = false,
    this.fontSize = 14,
    this.startupCommand = defaultStartupCommand,
    this.showKeyBar = true,
    Set<String>? hiddenKeyBarKeys,
  }) : hiddenKeyBarKeys = Set<String>.from(hiddenKeyBarKeys ?? const <String>{});

  String host;
  String username;
  String password;
  bool rememberPassword;
  double fontSize;
  String startupCommand;
  bool showKeyBar;
  Set<String> hiddenKeyBarKeys;

  static const _secure = FlutterSecureStorage();

  static Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    final s = Settings(
      host: p.getString('host') ?? 'remote-ocl.mihb.site',
      username: p.getString('username') ?? '',
      rememberPassword: p.getBool('rememberPassword') ?? false,
      fontSize: p.getDouble('fontSize') ?? 14,
      startupCommand: p.getString('startupCommand') ?? defaultStartupCommand,
      showKeyBar: p.getBool('showKeyBar') ?? true,
      hiddenKeyBarKeys: (p.getStringList('hiddenKeyBarKeys') ?? const <String>[]).toSet(),
    );
    if (s.rememberPassword) {
      try {
        s.password = await _secure.read(key: 'password') ?? '';
      } catch (_) {
        s.password = '';
      }
    }
    return s;
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('host', host);
    await p.setString('username', username);
    await p.setBool('rememberPassword', rememberPassword);
    await p.setDouble('fontSize', fontSize);
    await p.setString('startupCommand', startupCommand);
    await p.setBool('showKeyBar', showKeyBar);
    await p.setStringList('hiddenKeyBarKeys', hiddenKeyBarKeys.toList()..sort());
    try {
      if (rememberPassword && password.isNotEmpty) {
        await _secure.write(key: 'password', value: password);
      } else {
        await _secure.delete(key: 'password');
      }
    } catch (_) {}
  }

  Future<void> forgetPassword() async {
    password = '';
    try {
      await _secure.delete(key: 'password');
    } catch (_) {}
  }
}
