import 'package:flutter/material.dart';
import 'package:zling/overlapping_panels.dart';
import 'package:provider/provider.dart';
import '../global_state.dart';

class MessagesView extends StatelessWidget {
  const MessagesView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var appstate = context.watch<GlobalState>();
    var theme = Theme.of(context);
    return Builder(builder: (context) {
      return Scaffold(
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
        body: ListView(
          children: []
              .map((chatEntry) => ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    leading: CircleAvatar(
                      foregroundImage:
                          NetworkImage(chatEntry['user']['avatar']),
                    ),
                    title: Row(
                      children: [
                        Text(
                          chatEntry['user']['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(
                          width: 16,
                        ),
                        Text(
                          chatEntry["time"],
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        )
                      ],
                    ),
                    subtitle: Text(
                      chatEntry['message'],
                      style: const TextStyle(fontSize: 16),
                    ),
                    onTap: () {},
                    onLongPress: () {},
                  ))
              .toList(),
        ),
      );
    });
  }
}
