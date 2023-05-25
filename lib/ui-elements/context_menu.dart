import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BasicContextMenu extends StatefulWidget {
  const BasicContextMenu({required this.child, required this.id, super.key});
  final String id;
  final Widget child;

  @override
  State<BasicContextMenu> createState() => _BasicContextMenuState();
}

class _BasicContextMenuState extends State<BasicContextMenu> {
  Offset _tapPosition = Offset.zero;

  void _getTapPosition(TapDownDetails details) {
    setState(() {
      _tapPosition = details.globalPosition;
    });
  }

  void _showContextMenu(BuildContext context) async {
    final RenderObject? overlay =
        Overlay.of(context).context.findRenderObject();
    final result = await showMenu(
        context: context,
        position: RelativeRect.fromRect(
            Rect.fromLTWH(_tapPosition.dx, _tapPosition.dy, 30, 30),
            Rect.fromLTWH(0, 0, overlay!.paintBounds.size.width,
                overlay.paintBounds.size.height)),
        items: [const PopupMenuItem(value: "id", child: Text("Copy ID"))]);
    switch (result) {
      case 'id':
        await Clipboard.setData(ClipboardData(text: widget.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        child: widget.child,
        onTapDown: (details) => _getTapPosition(details),
        onLongPress: () => _showContextMenu(context));
  }
}
