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
    return GestureDetector(
      onTap: () {
        if (appstate.currentMenuSide != RevealSide.main) {
          OverlappingPanels.of(context)?.setCenter();
        }
      },
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
          body: msg(appstate)),
    );
  }
}

Widget msg(GlobalState appstate) {
  if (appstate.messages == null) {
    return const Center(child: CircularProgressIndicator());
  } else if (appstate.messages!.isEmpty) {
    return const Text("Nothing Here");
  } else {
    return ListView(children: const [Text("hello")]);
  }
}
