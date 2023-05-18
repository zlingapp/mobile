import 'package:flutter/material.dart';
import 'package:zling/overlapping_panels.dart';
import 'package:provider/provider.dart';
import '../global_state.dart';
import 'dart:ui';
import '../models.dart';

class MessagesView extends StatelessWidget {
  const MessagesView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var appstate = context.watch<GlobalState>();
    var theme = Theme.of(context);
    var panels = OverlappingPanels.of(context);
    double blur;
    if (panels == null) {
      blur = 0;
    } else {
      blur = (appstate.currentMenuSide != RevealSide.main && !appstate.inMove)
          ? 1
          : 0;
    }
    return GestureDetector(
      onTap: () {
        if (appstate.currentMenuSide != RevealSide.main) {
          OverlappingPanels.of(context)?.setCenter();
        }
      },
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Scaffold(
          backgroundColor: theme.colorScheme.background,
          appBar: AppBar(
            backgroundColor: theme.colorScheme.secondaryContainer,
            title: Row(
              children: [
                if (appstate.currentChannel != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text(
                          '#',
                          style: TextStyle(color: Colors.white54),
                        ),
                        Text(appstate.currentChannel!.name)
                      ]),
                    ],
                  ),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                OverlappingPanels.of(context)?.reveal(RevealSide.left);
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.call),
                onPressed: () {
                  OverlappingPanels.of(context)?.reveal(RevealSide.right);
                },
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt),
                onPressed: () {
                  OverlappingPanels.of(context)?.reveal(RevealSide.right);
                },
              ),
              IconButton(
                icon: const Icon(Icons.group),
                onPressed: () {
                  OverlappingPanels.of(context)?.reveal(RevealSide.right);
                },
              )
            ],
          ),
          body: const MessageList(),
        ),
      ),
    );
  }
}

class MessageList extends StatelessWidget {
  const MessageList({super.key});

  @override
  Widget build(BuildContext context) {
    final appstate = context.watch<GlobalState>();
    final theme = Theme.of(context);
    if (appstate.messages == null) return const SizedBox();
    if (appstate.messages!.isEmpty) return const Text("Empty");
    double imgsize = 18.0;

    return ListView(
      children: [
        ...appstate.messages!.asMap().entries.map((entry) {
          int idx = entry.key;
          Message message = entry.value;
          Message? prevMessage =
              (idx == 0 ? null : appstate.messages![idx - 1]);
          if (prevMessage == null ||
              (prevMessage.author != message.author) ||
              (prevMessage.author.id == message.author.id &&
                  message.createdAt.isAfter(prevMessage.createdAt
                      .add(const Duration(minutes: 10))))) {
            // Here we need an icon and username
            return Padding(
              padding: const EdgeInsets.only(left: 24, top: 8),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(48), // Image border
                      child: SizedBox.fromSize(
                        size: Size.fromRadius(imgsize), // Image radius
                        child: Image.network(
                            "https://upload.wikimedia.org/wikipedia/commons/7/7c/Profile_avatar_placeholder_large.png",
                            fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message.author.nickname ?? message.author.name,
                            style: theme.textTheme.bodyLarge!
                                .copyWith(color: Colors.grey)),
                        Text(message.content, style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          // just message here
          return Padding(
            padding: EdgeInsets.only(left: imgsize + 50),
            child: Text(message.content, style: theme.textTheme.bodyLarge),
          );
        }).toList()
      ],
    );
  }
}
