import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xterm/xterm.dart';

class TerminalSelectionHandles extends StatefulWidget {
  const TerminalSelectionHandles({
    super.key,
    required this.terminal,
    required this.controller,
    required this.scrollController,
    required this.terminalViewKey,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final Terminal terminal;
  final TerminalController controller;
  final ScrollController scrollController;
  final GlobalKey<TerminalViewState> terminalViewKey;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  State<TerminalSelectionHandles> createState() => _TerminalSelectionHandlesState();
}

class _TerminalSelectionHandlesState extends State<TerminalSelectionHandles> {
  static const _hitSize = 44.0;
  static const _bulbSize = 14.0;
  static const _edgeZone = 36.0;
  static const _handleColor = Color(0xFF3B82F6);

  CellOffset? _fixedOffset;
  CellOffset? _lastDraggedCell;
  bool _draggingStart = false;
  Offset? _lastGlobalPos;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    widget.terminal.addListener(_onTerminalChanged);
  }

  @override
  void didUpdateWidget(covariant TerminalSelectionHandles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.terminal != widget.terminal) {
      oldWidget.terminal.removeListener(_onTerminalChanged);
      widget.terminal.addListener(_onTerminalChanged);
    }
  }

  @override
  void dispose() {
    widget.terminal.removeListener(_onTerminalChanged);
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _onTerminalChanged() {
    if (widget.controller.selection != null && mounted) {
      setState(() {});
    }
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _applyDraggedOffset(Offset globalPos) {
    final fixed = _fixedOffset;
    if (fixed == null) return;
    final state = widget.terminalViewKey.currentState;
    if (state == null || !state.mounted) return;
    final render = state.renderTerminal;
    if (!render.attached) return;

    final maxRow = widget.terminal.buffer.lines.length - 1;
    if (maxRow < 0) return;

    final local = render.globalToLocal(globalPos);
    final adjusted = Offset(local.dx, local.dy - render.cellSize.height * 0.85);
    final raw = render.getCellOffset(adjusted);
    var moved = raw;
    if (!_draggingStart) {
      final cellLeft = render.getOffset(raw).dx;
      final pastHalf = adjusted.dx > cellLeft + render.cellSize.width * 0.35;
      final col = (pastHalf ? raw.x + 1 : raw.x).clamp(0, widget.terminal.viewWidth);
      moved = CellOffset(col, raw.y);
    }

    final clampedFixed = CellOffset(
      fixed.x.clamp(0, widget.terminal.viewWidth),
      fixed.y.clamp(0, maxRow),
    );
    if (moved == clampedFixed) {
      if (_draggingStart && clampedFixed.x > 0) {
        moved = CellOffset(clampedFixed.x - 1, clampedFixed.y);
      } else if (!_draggingStart && clampedFixed.x < widget.terminal.viewWidth) {
        moved = CellOffset(clampedFixed.x + 1, clampedFixed.y);
      } else {
        return;
      }
    }

    if (moved == _lastDraggedCell) return;
    _lastDraggedCell = moved;
    HapticFeedback.selectionClick();

    final begin = moved.isBefore(clampedFixed) ? moved : clampedFixed;
    final end = moved.isBefore(clampedFixed) ? clampedFixed : moved;
    widget.controller.setSelection(
      widget.terminal.buffer.createAnchorFromOffset(begin),
      widget.terminal.buffer.createAnchorFromOffset(end),
      mode: SelectionMode.line,
    );
  }

  void _updateAutoScroll(Offset globalPos) {
    if (widget.terminal.isUsingAltBuffer || !widget.scrollController.hasClients) {
      _stopAutoScroll();
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final delta = local.dy < _edgeZone
        ? -1.0
        : local.dy > box.size.height - _edgeZone
            ? 1.0
            : 0.0;
    if (delta == 0) {
      _stopAutoScroll();
      return;
    }
    _autoScrollTimer ??= Timer.periodic(const Duration(milliseconds: 50), (_) {
      final pos = _lastGlobalPos;
      final state = widget.terminalViewKey.currentState;
      if (!mounted || pos == null || state == null || !state.mounted || !widget.scrollController.hasClients) {
        _stopAutoScroll();
        return;
      }
      final render = state.renderTerminal;
      final boxNow = context.findRenderObject() as RenderBox?;
      if (!render.attached || boxNow == null) return;
      final localNow = boxNow.globalToLocal(pos);
      final dir = localNow.dy < _edgeZone
          ? -1.0
          : localNow.dy > boxNow.size.height - _edgeZone
              ? 1.0
              : 0.0;
      if (dir == 0) {
        _stopAutoScroll();
        return;
      }
      final position = widget.scrollController.position;
      final next = (position.pixels + dir * render.lineHeight).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (next != position.pixels) {
        position.jumpTo(next);
        _applyDraggedOffset(pos);
      }
    });
  }

  void _onPanStart({required bool isStart, required DragStartDetails details}) {
    final selection = widget.controller.selection?.normalized;
    if (selection == null) return;
    _draggingStart = isStart;
    _fixedOffset = isStart ? selection.end : selection.begin;
    _lastDraggedCell = isStart ? selection.begin : selection.end;
    _lastGlobalPos = details.globalPosition;
    HapticFeedback.selectionClick();
    widget.onDragStart();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _lastGlobalPos = details.globalPosition;
    _applyDraggedOffset(details.globalPosition);
    _updateAutoScroll(details.globalPosition);
  }

  void _onPanEnd() {
    _stopAutoScroll();
    _fixedOffset = null;
    _lastDraggedCell = null;
    _lastGlobalPos = null;
    widget.onDragEnd();
  }

  List<Widget> _buildHandle({
    required Offset anchor,
    required double lineHeight,
    required bool isStart,
    required Size stackSize,
  }) {
    if (anchor.dy < -lineHeight || anchor.dy > stackSize.height + lineHeight) {
      return const [];
    }
    final stemTop = anchor.dy;
    final stemBottom = anchor.dy + lineHeight;
    final hitLeft = (anchor.dx - _hitSize / 2).clamp(-_hitSize / 4, stackSize.width - _hitSize * 0.75);
    final hitTop = (stemBottom - 6).clamp(0.0, (stackSize.height - _hitSize).clamp(0.0, double.infinity));

    return [
      Positioned(
        left: anchor.dx - 1,
        top: stemTop,
        width: 2,
        height: lineHeight,
        child: const IgnorePointer(child: ColoredBox(color: _handleColor)),
      ),
      Positioned(
        left: hitLeft,
        top: hitTop,
        width: _hitSize,
        height: _hitSize,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _onPanStart(isStart: isStart, details: d),
          onPanUpdate: _onPanUpdate,
          onPanEnd: (_) => _onPanEnd(),
          onPanCancel: _onPanEnd,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: _bulbSize,
                height: _bulbSize,
                decoration: BoxDecoration(
                  color: _handleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isStart ? _bulbSize : 2),
                    topRight: Radius.circular(isStart ? 2 : _bulbSize),
                    bottomLeft: const Radius.circular(_bulbSize),
                    bottomRight: const Radius.circular(_bulbSize),
                  ),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, widget.scrollController]),
      builder: (context, _) {
        final selection = widget.controller.selection?.normalized;
        if (selection == null) return const SizedBox.shrink();
        final state = widget.terminalViewKey.currentState;
        final box = context.findRenderObject() as RenderBox?;
        if (state == null || !state.mounted || box == null || !box.hasSize) {
          return const SizedBox.shrink();
        }
        final render = state.renderTerminal;
        if (!render.attached) return const SizedBox.shrink();
        final beginGlobal = render.localToGlobal(render.getOffset(selection.begin));
        final endGlobal = render.localToGlobal(render.getOffset(selection.end));
        final beginLocal = box.globalToLocal(beginGlobal);
        final endLocal = box.globalToLocal(endGlobal);
        final lineHeight = render.cellSize.height;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            ..._buildHandle(anchor: beginLocal, lineHeight: lineHeight, isStart: true, stackSize: box.size),
            ..._buildHandle(anchor: endLocal, lineHeight: lineHeight, isStart: false, stackSize: box.size),
          ],
        );
      },
    );
  }
}
