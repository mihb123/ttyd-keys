import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const defaultStartupCommand = 'tmux new -A -s mobile';
const defaultHost = 'remote-ocl.mihb.site';

class ServerProfile {
  ServerProfile({
    required this.id,
    this.name = '',
    required this.host,
    required this.username,
    this.password = '',
    this.startupCommand = defaultStartupCommand,
  });

  final String id;
  String name;
  String host;
  String username;
  String password;
  String startupCommand;

  String get label => name.trim().isNotEmpty ? name.trim() : host;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'username': username,
        'startupCommand': startupCommand,
      };

  static ServerProfile? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final host = json['host'];
    final username = json['username'];
    if (id is! String || id.isEmpty || host is! String || username is! String) return null;
    final name = json['name'];
    final startup = json['startupCommand'];
    return ServerProfile(
      id: id,
      name: name is String ? name : '',
      host: host,
      username: username,
      startupCommand: startup is String ? startup : defaultStartupCommand,
    );
  }
}

class Settings {
  Settings({
    this.fontSize = 14,
    this.showSecondKeyRow = true,
    Set<String>? hiddenKeyBarKeys,
    List<ServerProfile>? servers,
    this.activeServerId,
  })  : hiddenKeyBarKeys = Set<String>.from(hiddenKeyBarKeys ?? const <String>{}),
        servers = servers ?? <ServerProfile>[];

  double fontSize;
  bool showSecondKeyRow;
  Set<String> hiddenKeyBarKeys;
  List<ServerProfile> servers;
  String? activeServerId;

  static const _secure = FlutterSecureStorage();

  static String _passwordKey(String id) => 'password.$id';

  static String newServerId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  ServerProfile? serverById(String? id) {
    if (id == null) return null;
    for (final s in servers) {
      if (s.id == id) return s;
    }
    return null;
  }

  ServerProfile? get activeServer => serverById(activeServerId) ?? servers.firstOrNull;

  bool get hasAnyPassword => servers.any((s) => s.password.isNotEmpty);

  static Future<String> _readSecure(String key) async {
    try {
      return await _secure.read(key: key) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    final s = Settings(
      fontSize: p.getDouble('fontSize') ?? 14,
      showSecondKeyRow: p.getBool('showSecondKeyRow') ?? p.getBool('showKeyBar') ?? true,
      hiddenKeyBarKeys: (p.getStringList('hiddenKeyBarKeys') ?? const <String>[]).toSet(),
      activeServerId: p.getString('activeServerId'),
    );
    final raw = p.getString('servers');
    if (raw != null) {
      try {
        final list = jsonDecode(raw);
        if (list is List) {
          for (final item in list) {
            final server = ServerProfile.fromJson(item);
            if (server != null) s.servers.add(server);
          }
        }
      } catch (_) {}
      for (final server in s.servers) {
        server.password = await _readSecure(_passwordKey(server.id));
      }
    } else {
      await s._migrateSingleHost(p);
    }
    return s;
  }

  Future<void> _migrateSingleHost(SharedPreferences p) async {
    final username = p.getString('username') ?? '';
    if (username.isNotEmpty) {
      final server = ServerProfile(
        id: newServerId(),
        host: p.getString('host') ?? defaultHost,
        username: username,
        password: (p.getBool('rememberPassword') ?? false) ? await _readSecure('password') : '',
        startupCommand: p.getString('startupCommand') ?? defaultStartupCommand,
      );
      servers.add(server);
      activeServerId = server.id;
    }
    await save();
    for (final key in const ['host', 'username', 'rememberPassword', 'startupCommand']) {
      await p.remove(key);
    }
    try {
      await _secure.delete(key: 'password');
    } catch (_) {}
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('fontSize', fontSize);
    await p.setBool('showSecondKeyRow', showSecondKeyRow);
    await p.remove('showKeyBar');
    await p.setStringList('hiddenKeyBarKeys', hiddenKeyBarKeys.toList()..sort());
    await p.setString('servers', jsonEncode([for (final s in servers) s.toJson()]));
    final active = activeServerId;
    if (active != null && serverById(active) != null) {
      await p.setString('activeServerId', active);
    } else {
      await p.remove('activeServerId');
    }
    for (final s in servers) {
      try {
        if (s.password.isNotEmpty) {
          await _secure.write(key: _passwordKey(s.id), value: s.password);
        } else {
          await _secure.delete(key: _passwordKey(s.id));
        }
      } catch (_) {}
    }
  }

  Future<void> removeServer(String id) async {
    servers.removeWhere((s) => s.id == id);
    if (activeServerId == id) activeServerId = servers.firstOrNull?.id;
    try {
      await _secure.delete(key: _passwordKey(id));
    } catch (_) {}
    await save();
  }

  Future<void> forgetPassword(ServerProfile server) async {
    server.password = '';
    try {
      await _secure.delete(key: _passwordKey(server.id));
    } catch (_) {}
  }

  Future<void> forgetAllPasswords() async {
    for (final s in servers) {
      await forgetPassword(s);
    }
  }
}
