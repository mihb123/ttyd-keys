import 'package:material_ui/material_ui.dart';

import 'server_session.dart';
import 'settings.dart';

Color serverStatusColor(ServerStatus status) => switch (status) {
      ServerStatus.connected => const Color(0xFF22C55E),
      ServerStatus.connecting => const Color(0xFFF59E0B),
      ServerStatus.disconnected => const Color(0xFFEF4444),
      ServerStatus.idle => const Color(0xFF6B7280),
    };

Future<void> showServerActions(
  BuildContext context,
  ServerProfile server,
  ServerStatus status, {
  required VoidCallback onEdit,
  required VoidCallback onDisconnect,
  required VoidCallback onDelete,
}) {
  final canDisconnect = status == ServerStatus.connected || status == ServerStatus.connecting;
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(server.label, overflow: TextOverflow.ellipsis),
            subtitle: Text('${server.username}@${server.host}', overflow: TextOverflow.ellipsis),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Sửa'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              onEdit();
            },
          ),
          if (canDisconnect)
            ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text('Ngắt kết nối'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onDisconnect();
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Color(0xFFF87171)),
            title: const Text('Xoá server', style: TextStyle(color: Color(0xFFF87171))),
            onTap: () {
              Navigator.of(sheetContext).pop();
              onDelete();
            },
          ),
        ],
      ),
    ),
  );
}

class ServerDrawer extends StatelessWidget {
  const ServerDrawer({
    super.key,
    required this.servers,
    required this.activeServerId,
    required this.statusOf,
    required this.onSelect,
    required this.onEdit,
    required this.onDisconnect,
    required this.onDelete,
    required this.onAdd,
  });

  final List<ServerProfile> servers;
  final String activeServerId;
  final ServerStatus Function(ServerProfile server) statusOf;
  final void Function(ServerProfile server) onSelect;
  final void Function(ServerProfile server) onEdit;
  final void Function(ServerProfile server) onDisconnect;
  final void Function(ServerProfile server) onDelete;
  final VoidCallback onAdd;

  void _showActions(BuildContext context, ServerProfile server) {
    showServerActions(
      context,
      server,
      statusOf(server),
      onEdit: () {
        Navigator.of(context).pop();
        onEdit(server);
      },
      onDisconnect: () => onDisconnect(server),
      onDelete: () => onDelete(server),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Text('Server', style: Theme.of(context).textTheme.titleMedium),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: servers.length,
                itemBuilder: (context, index) {
                  final server = servers[index];
                  final status = statusOf(server);
                  final selected = server.id == activeServerId;
                  return ListTile(
                    selected: selected,
                    selectedTileColor: colorScheme.primary.withValues(alpha: 0.16),
                    leading: SizedBox(
                      width: 16,
                      child: Center(
                        child: Icon(Icons.circle, size: 10, color: serverStatusColor(status)),
                      ),
                    ),
                    title: Text(server.label, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${server.username}@${server.host}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelect(server);
                    },
                    onLongPress: () => _showActions(context, server),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.tonal(
                onPressed: () {
                  Navigator.of(context).pop();
                  onAdd();
                },
                child: const Text('+ Thêm server'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
