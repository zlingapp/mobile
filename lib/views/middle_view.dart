import 'package:flutter/material.dart';
import 'package:zling/overlapping_panels.dart';
import 'package:provider/provider.dart';
import '../global_state.dart';
import '../models.dart';
import '../api.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import '../typing_indicator.dart';

class MessagesView extends StatelessWidget {
  const MessagesView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final logger = Logger("MessagesView");

    var appstate = context.watch<GlobalState>();
    var theme = Theme.of(context);
    var panels = OverlappingPanels.of(context);
    int dim;
    if (panels == null) {
      dim = 0;
    } else {
      dim = (appstate.currentMenuSide != RevealSide.main && !appstate.inMove)
          ? 1
          : 0;
    }
    return GestureDetector(
        onTap: () {
          if (appstate.currentMenuSide != RevealSide.main) {
            OverlappingPanels.of(context)?.setCenter();
          }
        },
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.5 * dim), BlendMode.darken),
          child: Scaffold(
            resizeToAvoidBottomInset: true,
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
            body: Column(children: [
              if (appstate.ws == null && appstate.socketReconnecting == false)
                Container(
                    color: theme.colorScheme.errorContainer,
                    child: Row(children: [
                      const SizedBox(width: 12),
                      Text("Socket not connected (?!?)",
                          style: theme.textTheme.bodyLarge!.copyWith(
                              color: theme.colorScheme.onErrorContainer)),
                      const Spacer(),
                      if (appstate.socketConnectingFromBroken)
                        const CircularProgressIndicator(),
                      ElevatedButton(
                          onPressed: () {
                            if (!appstate.socketConnectingFromBroken) {
                              logger.info(
                                  "Socket reconnecting from broken state");
                              appstate.reconnectingFromBroken();
                              appstate.initStream();
                              appstate.socketConnectingFromBroken = false;
                            }
                          },
                          child: Text(
                            "Connect",
                            style: theme.textTheme.bodyLarge!.copyWith(
                                color: theme.colorScheme.onErrorContainer),
                          ))
                    ])),
              const MessageList(),
              if (appstate.currentChannel != null) const MessageSendDialog(),
            ]),
          ),
        ));
  }
}

class MessageList extends StatelessWidget {
  const MessageList({super.key});

  @override
  Widget build(BuildContext context) {
    final appstate = context.watch<GlobalState>();
    final theme = Theme.of(context);
    if (appstate.messages == null || appstate.currentChannel == null) {
      return const SizedBox();
    }
    if (appstate.messages!.isEmpty) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "No Messages Here",
                  style: theme.textTheme.displaySmall?.copyWith(fontSize: 24),
                ),
                const SizedBox(
                  height: 16,
                ),
                const Icon(Icons.bedtime, color: Colors.grey, size: 48),
              ],
            ),
          ),
        ),
      );
    }
    double imgsize = 18.0;

    return Expanded(
      child: ListView(
        reverse: true,
        shrinkWrap: true,
        scrollDirection: Axis.vertical,
        children: [
          const SizedBox(height: 24),
          ...appstate.messages!
              .asMap()
              .entries
              .map((entry) {
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
                    padding: const EdgeInsets.only(left: 24, top: 8, right: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(48), // Image border
                            child: SizedBox.fromSize(
                              size: Size.fromRadius(imgsize), // Image radius
                              child: Image.network(
                                  "https://upload.wikimedia.org/wikipedia/commons/7/7c/Profile_avatar_placeholder_large.png",
                                  fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                        message.author.nickname ??
                                            message.author.name,
                                        style: theme.primaryTextTheme.bodyLarge!
                                            .copyWith(
                                                color: const Color.fromARGB(
                                                    255, 170, 170, 170),
                                                fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 4),
                                    Text(formatTime(message.createdAt),
                                        style: theme
                                            .primaryTextTheme.labelMedium!
                                            .copyWith(
                                                color: const Color.fromARGB(
                                                    255, 132, 131, 131)))
                                  ],
                                ),
                                Text(
                                  message.content,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                // just message here
                return Padding(
                  padding: EdgeInsets.only(left: imgsize + 50, right: 16),
                  child: Text(
                    message.content,
                    style: theme.textTheme.bodyLarge,
                  ),
                );
              })
              .toList()
              .reversed
              .toList(),
        ],
      ),
    );
  }
}

class MessageSendDialog extends StatefulWidget {
  const MessageSendDialog({super.key});

  @override
  State<MessageSendDialog> createState() => _MessageSendDialogState();
}

class _MessageSendDialogState extends State<MessageSendDialog> {
  String _currentMessage = "";
  final _controller = TextEditingController();
  DateTime? lastTyped;

  void _send(GlobalState appstate) {
    if (_currentMessage.trim() == "") {
      return;
    }
    ApiService()
        .sendMessage(appstate.currentGuild!.id, appstate.currentChannel!.id,
            _currentMessage, appstate)
        .then((value) {
      if (value == true) {
        setState(() {
          _currentMessage = "";
          _controller.clear();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var appstate = context.watch<GlobalState>();
    var theme = Theme.of(context);
    if (appstate.inMove) {
      // Close keyboard when moving
      FocusScope.of(context).unfocus();
    }
    return SafeArea(
      child: Container(
        width: MediaQuery.of(context).size.width,
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                      onPressed: () {}, icon: const Icon(Icons.add, size: 24)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(28)),
                      child: Container(
                        color: theme.colorScheme.onInverseSurface,
                        child: TextField(
                          maxLines: 1,
                          maxLength: 2000,
                          controller: _controller,
                          autocorrect: false,
                          style: theme.primaryTextTheme.bodyMedium!
                              .copyWith(fontSize: 14),
                          onChanged: (value) {
                            setState(() {
                              if (lastTyped == null ||
                                  lastTyped!.isBefore(DateTime.now())) {
                                lastTyped = DateTime.now()
                                    .add(const Duration(seconds: 4));
                                appstate.sendTyping();
                              }
                              _currentMessage = value;
                            });
                          },
                          onEditingComplete: () =>
                              FocusScope.of(context).unfocus(),
                          onSubmitted: ((_) => {_send(appstate)}),
                          // onTapOutside: ((_) =>
                          //     {FocusScope.of(context).unfocus()}),
                          decoration: InputDecoration(
                              counterText: "",
                              border: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(28))),
                              hintText:
                                  "Message #${appstate.currentChannel?.name}"),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                      onPressed: () {
                        _send(appstate);
                      },
                      icon: const Icon(Icons.send, size: 24)),
                  IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.emoji_emotions, size: 24)),
                ],
              ),
              appstate.typing.isEmpty
                  ? const SizedBox(height: 20)
                  : Padding(
                      padding: const EdgeInsets.only(left: 60),
                      child: SizedBox(
                          height: 20,
                          child: Row(
                            children: [
                              const TypingIndicator(),
                              Text(typingText(appstate.typing.keys.toList()),
                                  overflow: TextOverflow.fade)
                            ],
                          )),
                    )
            ],
          ),
        ),
      ),
    );
  }
}

String typingText(List<Member> users) {
  if (users.length == 1) {
    return "${users[0].nickname ?? users[0].name} is typing";
  } else if (users.length == 2) {
    return "${users[0].nickname ?? users[0].name} and ${users[1].nickname ?? users[1].name} are typing";
  } else if (users.length < 5) {
    return "${users[0].nickname ?? users[0].name}, ${users[1].nickname ?? users[1].name}, and ${users.length - 2} more are typing";
  } else {
    return "${users.length} people are tying";
  }
}

final timeF = DateFormat("HH:mm");
final dateF = DateFormat("dd/MM");
final dateYearF = DateFormat("dd/MM/yyyy");
String formatTime(DateTime time) {
  time = time.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  final day = DateTime(time.year, time.month, time.day);
  if (day == today) {
    return "Today at ${timeF.format(time)}";
  } else if (day == yesterday) {
    return "Yesterday at ${timeF.format(time)}";
  } else {
    if (time.year == now.year) {
      return "${dateF.format(time)} at ${timeF.format(time)}";
    } else {
      return "${dateYearF.format(time)} at ${timeF.format(time)}";
    }
  }
}
