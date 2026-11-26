import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'server_drawer.dart';
import 'server_session.dart';
import 'settings.dart';

class ServerTabBar extends StatefulWidget {
  const ServerTabBar({
    super.key,
    required this.servers,
    required this.activeServerId,
    required this.statusOf,
    required this.onSelect,
    required this.onClose,
    required this.onEdit,
    required this.onDisconnect,
    required this.onDelete,
    required this.onAdd,
  });

  final List<ServerProfile> servers;
  final String activeServerId;
  final ServerStatus Function(ServerProfile server) statusOf;
  final void Function(ServerProfile server) onSelect;
  final void Function(ServerProfile server) onClose;
  final void Function(ServerProfile server) onEdit;
  final void Function(ServerProfile server) onDisconnect;
  final void Function(ServerProfile server) onDelete;
  final VoidCallback onAdd;

  @override
  State<ServerTabBar> createState() => _ServerTabBarState();
}

class _ServerTabBarState extends State<ServerTabBar> {
  static const _minTabWidth = 120.0;
  static const _barHeight = 40.0;
  static const _activeTabColor = Color(0xFF2E3036);

  final _scrollController = ScrollController();
  String _lastActiveId = '';
  int _lastActiveIndex = -1;

  List<ServerProfile> get _openTabs => [
        for (final s in widget.servers)
          if (s.id == widget.activeServerId || widget.statusOf(s) != ServerStatus.idle) s,
      ];

  List<ServerProfile> get _closedServers => [
        for (final s in widget.servers)
          if (s.id != widget.activeServerId && widget.statusOf(s) == ServerStatus.idle) s,
      ];

  @override
  void initState() {
    super.initState();
    _syncActiveTracking(scrollIfChanged: true);
  }

  @override
  void didUpdateWidget(covariant ServerTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncActiveTracking(scrollIfChanged: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _syncActiveTracking({required bool scrollIfChanged}) {
    final openTabs = _openTabs;
    final activeIndex = openTabs.indexWhere((s) => s.id == widget.activeServerId);
    final changed = widget.activeServerId != _lastActiveId || activeIndex != _lastActiveIndex;
    _lastActiveId = widget.activeServerId;
    _lastActiveIndex = activeIndex;
    if (scrollIfChanged && changed) {
      _scrollActiveIntoView();
    }
  }

  void _scrollActiveIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final openTabs = _openTabs;
      final activeIndex = openTabs.indexWhere((s) => s.id == widget.activeServerId);
      if (activeIndex == -1) return;
      final pos = _scrollController.position;
      if (pos.maxScrollExtent <= 0) return;
      final targetLeft = activeIndex * _minTabWidth;
      final targetRight = targetLeft + _minTabWidth;
      final current = pos.pixels;
      final viewport = pos.viewportDimension;
      double? nextOffset;
      if (targetLeft < current) {
        nextOffset = targetLeft;
      } else if (targetRight > current + viewport) {
        nextOffset = targetRight - viewport;
      }
      if (nextOffset == null) return;
      final clamped = nextOffset.clamp(pos.minScrollExtent, pos.maxScrollExtent);
      if ((clamped - current).abs() < 0.5) return;
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onAddPressed(BuildContext context, List<ServerProfile> closedServers) {
    if (closedServers.isEmpty) {
      widget.onAdd();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final server in closedServers)
                  ListTile(
                    leading: SizedBox(
                      width: 16,
                      child: Center(
                        child: Icon(Icons.circle, size: 10, color: serverStatusColor(widget.statusOf(server))),
                      ),
                    ),
                    title: Text(server.label, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${server.username}@${server.host}', overflow: TextOverflow.ellipsis),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      widget.onSelect(server);
                    },
                  ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Thêm server mới'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    widget.onAdd();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(
    BuildContext context,
    ServerProfile server, {
    required int index,
    required List<ServerProfile> openTabs,
    required double tabWidth,
  }) {
    final isActive = server.id == widget.activeServerId;
    final showClose = isActive && openTabs.length > 1;
    final showRightDivider =
        !isActive && index < openTabs.length - 1 && openTabs[index + 1].id != widget.activeServerId;
    final status = widget.statusOf(server);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: isActive ? _activeTabColor : Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (!isActive) {
              HapticFeedback.selectionClick();
              widget.onSelect(server);
            }
          },
          onLongPress: () => showServerActions(
            context,
            server,
            status,
            onEdit: () => widget.onEdit(server),
            onDisconnect: () => widget.onDisconnect(server),
            onDelete: () => widget.onDelete(server),
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  if (showClose)
                    Tooltip(
                      message: 'Đóng tab',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => widget.onClose(server),
                        child: const SizedBox(
                          width: 28,
                          height: 36,
                          child: Center(
                            child: Icon(Icons.close, size: 14, color: Colors.white70),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: showClose ? 2 : 0,
                        right: showClose && tabWidth >= 160 ? 28 : 8,
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: serverStatusColor(status),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                server.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                  color: isActive ? Colors.white : Colors.white60,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (showRightDivider)
                const Positioned(
                  right: 0,
                  top: 8,
                  bottom: 8,
                  child: ColoredBox(
                    color: Colors.white12,
                    child: SizedBox(width: 1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openTabs = _openTabs;
    final closedServers = _closedServers;

    return SizedBox(
      height: _barHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final count = openTabs.length;
                if (count == 0) return const SizedBox.shrink();
                final availableWidth = constraints.maxWidth;
                final scrollable = availableWidth < count * _minTabWidth;
                final tabWidth = scrollable ? _minTabWidth : availableWidth / count;

                return SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: scrollable ? null : const NeverScrollableScrollPhysics(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < count; i++)
                        SizedBox(
                          width: tabWidth,
                          child: _buildTab(
                            context,
                            openTabs[i],
                            index: i,
                            openTabs: openTabs,
                            tabWidth: tabWidth,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'Mở server',
            icon: const Icon(Icons.add, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: _barHeight),
            visualDensity: VisualDensity.compact,
            onPressed: () => _onAddPressed(context, closedServers),
          ),
        ],
      ),
    );
  }
}
