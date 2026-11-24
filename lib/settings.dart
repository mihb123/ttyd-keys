import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  Settings({
    this.host = 'remote-ocl.mihb.site',
    this.username = '',
    this.password = '',
    this.rememberPassword = true,
    this.fontSize = 14,
    this.startupCommand = '',
  });

  String host;
  String username;
  String password;
  bool rememberPassword;
  double fontSize;
  String startupCommand;

  static const _secure = FlutterSecureStorage();

  static Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    final s = Settings(
      host: p.getString('host') ?? 'remote-ocl.mihb.site',
      username: p.getString('username') ?? '',
      rememberPassword: p.getBool('rememberPassword') ?? true,
      fontSize: p.getDouble('fontSize') ?? 14,
      startupCommand: p.getString('startupCommand') ?? '',
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
