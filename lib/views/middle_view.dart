import 'package:flutter/material.dart';
// import 'package:flutter_markdown/flutter_markdown.dart';
// import 'package:markdown/markdown.dart' as md;
import 'package:zling/ui-elements/overlapping_panels.dart';
import 'package:provider/provider.dart';
import '../global_state.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import '../ui-elements/typing_indicator.dart';
import 'package:zling/lib/api.dart';
import 'package:zling/lib/models.dart';
import 'package:zling/lib/latex.dart';

class MessagesView extends StatelessWidget {
  const MessagesView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final logger = Logger("MessagesView");

    var appstate = context.watch<GlobalState>();
    var theme = Theme.of(context);
    var panels = OverlappingPanels.of(context);
    int dim;
    // We want the main panel to be dimmed if either of the side panels are foregrounded
    if (panels == null) {
      // Somehow there is no OverlappingPanels object, default to no dim
      dim = 0;
    } else {
      // Only dim if we on the side and the screen isnt moving
      dim = (appstate.currentMenuSide != RevealSide.main && !appstate.inMove)
          ? 1
          : 0;
    }
    return WillPopScope(
      // This is how we handle android back event. Return false so the app doesnt close
      // and slide us to the center panel.
      onWillPop: () async {
        OverlappingPanels.of(context)?.setCenter();
        return false;
      },
      child: GestureDetector(
          onTap: () {
            // If we tap on the center panel while the side panel is foreground, slide us to center
            if (appstate.currentMenuSide != RevealSide.main) {
              OverlappingPanels.of(context)?.setCenter();
            }
          },
          child: ColorFiltered(
            // Apply dim if necessary,otherwise just give us normal panel
            colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.5 * dim), BlendMode.darken),
            child: Scaffold(
              backgroundColor: theme.colorScheme.background,
              appBar: AppBar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                // Title bar includes channel name, as well as nav buttons
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
                // Menu button will slide us to left side view
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    OverlappingPanels.of(context)?.reveal(RevealSide.left);
                  },
                ),
                // Once voice and calls and stuff are implemented, change these
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
              // Stack here so we can place elements arbitrarily on top of each other
              // (so we can overlay typing indicator without shifting other stuff)
              body: Stack(children: [
                Column(children: [
                  // If our websocket is somehow dead and not reconneceting, give us a big connect button
                  // This should really never happen though...
                  if (appstate.ws == null &&
                      appstate.socketReconnecting == false)
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
                  // Only load the message send box if we have a selected channel
                  if (appstate.currentChannel != null)
                    const MessageSendDialog(),
                ]),
                // Typing indicator positioned on top of other stuff so the message list doesnt shift around
                if (appstate.typing.isNotEmpty)
                  Positioned(
                    // 64 is the height of the message send dialog, might be changed later
                    bottom: 64,
                    child: Opacity(
                      opacity: 0.8,
                      child: Container(
                          width: MediaQuery.of(context).size.width,
                          color: theme.colorScheme.background,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                const TypingIndicator(),
                                Text(typingText(appstate.typing.keys.toList()),
                                    overflow: TextOverflow.fade)
                              ],
                            ),
                          )),
                    ),
                  )
              ]),
            ),
          )),
    );
  }
}

class MessageList extends StatefulWidget {
  const MessageList({super.key});

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    // When the frame is first built we want to add a listener to the scroll event
    // This means we can hear when the user has scrolled to the top of the list we can
    // get new messages if they exist
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      // We dont want to listen to state here, we only want to check the
      // current value on the event of user scroll to top
      GlobalState appstate = Provider.of(context, listen: false);
      _controller.addListener(() {
        // At edge, edge is top, we have more messages to load, current messages exist
        if (_controller.position.atEdge &&
            _controller.position.pixels != 0 &&
            appstate.moreMessagesToLoad == true &&
            appstate.messages != null &&
            appstate.messages!.isNotEmpty) {
          // Before the oldest message already loaded
          appstate.getMessages(before: appstate.messages![0].createdAt);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final appstate = context.watch<GlobalState>();
    final theme = Theme.of(context);
    // Blank screen if we have loading messages or no current selected channel
    if (appstate.messages == null || appstate.currentChannel == null) {
      return const SizedBox();
    }
    // If messages is not null but is empty, the channel just has no messages in it
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
    // Size of user avatars in pixels
    double imgsize = 18.0;

    return Expanded(
      child: ListView(
        controller: _controller,
        // We want messages to load bottom to top
        reverse: true,
        shrinkWrap: true,
        scrollDirection: Axis.vertical,
        children: [
          const SizedBox(height: 12),
          ...appstate.messages!
              .asMap()
              .entries
              .map((entry) {
                int idx = entry.key;
                Message message = entry.value;
                Widget text = Text(
                  message.content,
                  style: theme.textTheme.bodyLarge,
                );
                // If we have some maths stuff then render it through our latex processer
                if (message.content.split("\$").length >= 3) {
                  text = latexToRT(text as Text);
                } else {
                  // Markdown processing otherwise, idk if this is a good idea tho

                  // text = MarkdownBody(
                  //   data: message.content,
                  //   extensionSet: md.ExtensionSet(
                  //       md.ExtensionSet.gitHubFlavored.blockSyntaxes, [
                  //     md.EmojiSyntax(),
                  //     ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes
                  //   ]),
                  // );
                }

                // If the message is less than 10 minutes before the previous message
                // and from the same author, dont show username and icon again
                Message? prevMessage =
                    (idx == 0 ? null : appstate.messages![idx - 1]);
                if (prevMessage == null ||
                    (prevMessage.author != message.author) ||
                    (prevMessage.author.id == message.author.id &&
                        message.createdAt.isAfter(prevMessage.createdAt
                            .add(const Duration(minutes: 10))))) {
                  // Here we need an icon and username
                  return InkWell(
                    // InkWell provides the cool ripple effect ontap
                    // We dont actually need any tap behavior tho... so set to (){}
                    onTap: appstate.currentMenuSide == RevealSide.main
                        ? () {}
                        : null,
                    child: Padding(
                      padding:
                          const EdgeInsets.only(left: 24, top: 8, right: 16),
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
                                    // Change this
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
                                          // If we have a guild nickname use it, otherwise username
                                          message.author.nickname ??
                                              message.author.name,
                                          style: theme
                                              .primaryTextTheme.bodyLarge!
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
                                  // After the icon and username we need the actual content
                                  text,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                // just message here
                return InkWell(
                  onTap: () {},
                  child: Padding(
                    padding: EdgeInsets.only(left: imgsize + 50, right: 16),
                    child: text,
                  ),
                );
              })
              .toList()
              // This counteracts the reversed=true listview to make the list
              // load from bottom to top while retaining correct order
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
    // We dont want to be able to send whitespace only messages
    if (_currentMessage.trim() == "") {
      return;
    }
    ApiService()
        .sendMessage(appstate.currentGuild!.id, appstate.currentChannel!.id,
            _currentMessage, appstate)
        .then((value) {
      if (value == true) {
        // If the message was successfully sent then empty the buffer
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
        height: 64,
        width: MediaQuery.of(context).size.width,
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
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
                        // Send the typing indicator if the last typing indicator was sent
                        // more than 4 seconds ago (or if we've never sent one before)
                        setState(() {
                          if (lastTyped == null ||
                              lastTyped!.isBefore(DateTime.now())) {
                            lastTyped =
                                DateTime.now().add(const Duration(seconds: 4));
                            appstate.sendTyping();
                          }
                          _currentMessage = value;
                        });
                      },
                      // onEditingComplete: () =>
                      // FocusScope.of(context).unfocus(),
                      onSubmitted: ((_) => {_send(appstate)}),
                      // onTapOutside: ((_) =>
                      //     {FocusScope.of(context).unfocus()}),
                      decoration: InputDecoration(
                          contentPadding:
                              const EdgeInsets.only(left: 12, right: 12),
                          counterText:
                              "", // Set the text of the character counter to empty bc it kinda messes up our spacing
                          // We can add it back manually later if we want
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
                  // Button for emoji picker
                  // Weird, its almost like its not implemented yet
                  onPressed: () {},
                  icon: const Icon(Icons.emoji_emotions, size: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

// Give us the names of people who are typing, or just give us a number if lots of people are
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

// Format those timestamps so it'll tell us today, yesterday, or just a date
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
