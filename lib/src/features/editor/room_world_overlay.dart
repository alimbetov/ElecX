import 'package:flutter/material.dart';

import 'editor_controller.dart';
import 'room_world_canvas.dart';

Future<void> showRoomWorldOverlay(
  BuildContext context,
  EditorController controller,
) async {
  if (controller.selectedSpace == null) return;
  await Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _RoomWorldOverlay(controller: controller),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      settings: const RouteSettings(name: 'room-world'),
    ),
  );
}

class _RoomWorldOverlay extends StatefulWidget {
  const _RoomWorldOverlay({required this.controller});

  final EditorController controller;

  @override
  State<_RoomWorldOverlay> createState() => _RoomWorldOverlayState();
}

class _RoomWorldOverlayState extends State<_RoomWorldOverlay> {
  EditorController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (controller.viewMode == EditorViewMode.surface) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 44,
          leading: IconButton(
            tooltip: 'Назад на план',
            onPressed: () {
              controller.showPlan();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back, size: 19),
          ),
          title: Text(
            controller.selectedSpace == null
                ? 'ROOM WORLD'
                : '${controller.selectedSpace!.name} · ROOM WORLD',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                child: Text(
                  'Потолок ↑   стены ↔   пол ↓',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ],
        ),
        body: RoomWorldCanvas(controller: controller),
      );
}
