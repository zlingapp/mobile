import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zling/ui-elements/overlapping_panels.dart';
import '../global_state.dart';
import 'package:zling/lib/api.dart';
import '../ui-elements/context_menu.dart';

class LeftView extends StatelessWidget {
  const LeftView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        color: theme.colorScheme.background,
        child: Row(
          children: [
            const GuildScrollBar(),
            const ChannelsView(),
            // Add some space for the peeking out main panel
            Container(width: 60)
          ],
        ),
      ),
    );
  }
}

class ChannelsView extends StatelessWidget {
  const ChannelsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appstate = context.watch<GlobalState>();
    // Take up the rest of the space available to us
    return Expanded(
      child: SafeArea(
        // And dont get covered by any device features plaease
        child: Container(
          decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                    border: Border(
                        // Divisor between guild name and channel list
                        bottom: BorderSide(color: theme.colorScheme.outline))),
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            // Server name
                            child: appstate.currentGuild == null
                                ? const Text("No Server Selected",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18))
                                : Text(
                                    appstate.currentGuild!.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18),
                                  )),
                        IconButton(
                            // Server options button - not implemented
                            onPressed: () {},
                            icon: const Icon(Icons.more_horiz))
                      ],
                    ),
                    //const Text(
                    //  "server description",
                    //  style: TextStyle(color: Colors.grey),
                    // )
                  ],
                ),
              ),
              Expanded(
                child: Material(
                  color: theme.colorScheme.secondaryContainer,
                  child: ListView(
                    children: [
                      if (appstate.channels != null &&
                          appstate.channels!.isEmpty)
                        Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                              const SizedBox(height: 30),
                              Icon(Icons.bedtime,
                                  color: theme.colorScheme.onPrimaryContainer,
                                  size: 48),
                              const Text("No Channels Here") // Empty server
                            ])),

                      // Text channel category label only if there is a textchannel
                      if (appstate.channels != null &&
                          appstate.channels!
                              .where((i) => (i.type == "text"))
                              .isNotEmpty)
                        const Padding(
                          padding:
                              EdgeInsets.only(top: 16, left: 16, right: 16),
                          child: Text(
                            'TEXT CHANNELS',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.grey),
                          ),
                        ),
                      if (appstate.currentGuild != null)
                        ...(appstate.channels == null
                            ? const [
                                Center(child: CircularProgressIndicator())
                              ] // This means our channels are loading
                            : appstate.channels!
                                .where((i) => (i.type == "text"))
                                .map((channel) => BasicContextMenu(
                                      // Wrap our tiles in the context menu so we can long tap to copy id
                                      id: channel.id,
                                      child: ListTile(
                                        leading: const Icon(Icons.tag),
                                        selected: (appstate.currentChannel ==
                                            channel),
                                        horizontalTitleGap: 0,
                                        visualDensity: const VisualDensity(
                                            horizontal: 0, vertical: -4),
                                        title: Text(channel.name),
                                        onTap: () {
                                          if (channel !=
                                              appstate.currentChannel) {
                                            appstate.setChannel(channel);
                                            appstate.prevChannelSelection[
                                                    appstate.currentGuild!] =
                                                channel;
                                          } // When we change channels, save it so it can be remembered on guild switches
                                          appstate.getMessages().then((value) =>
                                              {
                                                // When we get our messages we want to slide to center
                                                OverlappingPanels.of(context)
                                                    ?.setCenter()
                                              });
                                        },
                                      ),
                                    ))
                                .toList()),
                      if (appstate.channels != null &&
                          appstate.channels!
                              .where((i) => (i.type == "voice"))
                              .isNotEmpty)
                        const Padding(
                          padding:
                              EdgeInsets.only(top: 16, left: 16, right: 16),
                          child: Text(
                            'VOICE CHANNELS',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.grey),
                          ),
                        ),
                      if (appstate.currentGuild != null)
                        ...(appstate.channels == null
                            ? const []
                            : appstate.channels!
                                .where((i) => i.type == "voice")
                                .map((channel) => ListTile(
                                      leading: const Icon(Icons.headphones),
                                      selected:
                                          // REPLACE HERE WITH VOICE INDEX
                                          appstate.currentChannel != null &&
                                              appstate.currentChannel ==
                                                  channel,
                                      horizontalTitleGap: 0,
                                      visualDensity: const VisualDensity(
                                          horizontal: 0, vertical: -4),
                                      title: Text(channel.name),
                                      onTap: () {
                                        // Voice Stuff Here
                                      },
                                    ))),
                    ],
                  ),
                ),
              ),
              // Buttons to create new channels
              if (appstate.channels != null) ...[
                Center(
                  child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                            context: context,
                            builder: (context) =>
                                const CreateChannelDialog(type: "Text"));
                      },
                      child: const Text("Create text channel")),
                ),
                Center(
                  child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                            context: context,
                            builder: (context) =>
                                const CreateChannelDialog(type: "Voice"));
                      },
                      child: const Text("Create voice channel")),
                ),
                const SizedBox(height: 8)
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class GuildScrollBar extends StatelessWidget {
  const GuildScrollBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final appstate = context.watch<GlobalState>();
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.background,
      child: SafeArea(
        // Dont get covered by device features
        child: appstate.guilds == null || appstate.guilds!.isEmpty
            ? const Center(
                child: CircularProgressIndicator()) // Guilds are loading in
            : SingleChildScrollView(
                // Clamping scroll phys so the icons dont go off the screen
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  // Make it take up the whole height available to us
                  constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      ...appstate.guilds!.map(
                        (e) {
                          // We want to be able to long tap and copy our guild ids
                          return BasicContextMenu(
                            id: e.id,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  left: 8, right: 8, top: 4, bottom: 4),
                              child: GestureDetector(
                                  onTap: () {
                                    // Dont waste time with more requests if that guild is already selected
                                    if (e == appstate.currentGuild) {
                                      return;
                                    }
                                    if (appstate.guilds == null ||
                                        appstate.guilds!.isEmpty) return;
                                    appstate.setGuild(e);
                                  },
                                  child: GuildIcon(
                                    // Replace with real icon later
                                    iconURL: "https://via.placeholder.com/32",
                                    selected: e == appstate.currentGuild,
                                  )),
                            ),
                          );
                        },
                      ).toList(),
                      // Plus button to add or join a server
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (BuildContext context) =>
                                  const CreateOrJoinGuildDialog());
                        },
                      )
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// Rounded guild icon who's border radius changes when its selected
class GuildIcon extends StatelessWidget {
  const GuildIcon({required this.iconURL, required this.selected, Key? key})
      : super(key: key);
  final String iconURL;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(selected ? 20 : 48), // Image border
      child: SizedBox.fromSize(
        size: const Size.fromRadius(28), // Image radius
        child: Image.network(iconURL, fit: BoxFit.cover),
      ),
    );
  }
}

// Dialog prompting to join or create a server. The buttons will spawn subsequent dialogs
class CreateOrJoinGuildDialog extends StatelessWidget {
  const CreateOrJoinGuildDialog({super.key});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var regStyle = theme.textTheme.bodyMedium;
    var emphStyle = theme.textTheme.bodyMedium!.copyWith(
        fontWeight: FontWeight.bold, color: theme.colorScheme.primary);
    return SimpleDialog(
        contentPadding: const EdgeInsets.all(20),
        title: Container(
            padding: const EdgeInsets.only(bottom: 8),
            width: MediaQuery.of(context)
                .size
                .width, // We want our title divisor to take up the whole dialog width
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: theme.colorScheme.outline))),
            child: const Center(child: Text("Create Server?"))),
        children: [
          RichText(
              text: TextSpan(
                  // Bold for "create a server"
                  text: "Do you want to ",
                  style: regStyle,
                  children: [
                TextSpan(text: "create a server?", style: emphStyle)
              ])),
          const SizedBox(height: 6),
          RichText(
              text: TextSpan(text: "Servers", style: emphStyle, children: [
            TextSpan(
                style: regStyle,
                text:
                    " are invite-only communities where you can chat in channels, organize roles, and manage a list of members.")
          ])),
          const SizedBox(height: 6),
          RichText(
              text: TextSpan(
                  text:
                      "Alternatively, you can join someone else's server as a member instead.",
                  style: regStyle)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                        context); // When the buttons are pressed, kill the current dialog and spawn a new one
                    showDialog(
                        context: context,
                        builder: (BuildContext context) =>
                            const CreateServerDialog());
                  },
                  style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(
                          theme.colorScheme.primaryContainer)),
                  child: Text("Create Server",
                      style: theme.textTheme.labelLarge!.copyWith(
                          color: theme.colorScheme.onPrimaryContainer))),
              const SizedBox(width: 12),
              ElevatedButton(
                  style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(
                          theme.colorScheme.background)),
                  onPressed: () {
                    Navigator.of(context).pop(context);
                    showDialog(
                        context: context,
                        builder: (BuildContext context) =>
                            const JoinServerDialog());
                  },
                  child: Text("Join Server",
                      style: theme.textTheme.labelLarge!
                          .copyWith(color: theme.colorScheme.onBackground)))
            ],
          )
        ]);
  }
}

class JoinServerDialog extends StatefulWidget {
  const JoinServerDialog({super.key});

  @override
  State<JoinServerDialog> createState() => _JoinServerDialogState();
}

class _JoinServerDialogState extends State<JoinServerDialog> {
  String _currentText = "";
  bool? _success;

  Future<void> _submit(GlobalState state, {String? text}) async {
    text ??= _currentText;
    if (text == "") return;
    var res = await ApiService().joinGuild(text, state);
    setState(() {
      _success = res;
    });
    return;
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var appstate = context.watch<GlobalState>();
    return SimpleDialog(contentPadding: const EdgeInsets.all(20), children: [
      TextField(
        autocorrect: false,
        decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            labelText: "Server ID"),
        onChanged: (value) => setState(() {
          _currentText = value;
        }),
        onSubmitted: (value) => _submit(appstate, text: value).then((_) {
          if (_success == true) Navigator.of(context).pop(context);
          // If we joined guild successfully, kill the dialog
        }),
      ),
      const SizedBox(height: 22),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
              onPressed: () => _submit(appstate).then((_) {
                    if (_success == true) Navigator.of(context).pop(context);
                  }),
              style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(
                      theme.colorScheme.primaryContainer)),
              child: Text("Join",
                  style: theme.textTheme.labelLarge!
                      .copyWith(color: theme.colorScheme.onPrimaryContainer))),
          const SizedBox(width: 12),
          ElevatedButton(
              style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all(theme.colorScheme.background)),
              onPressed: () {
                Navigator.of(context).pop(context);
              },
              child: Text("Cancel",
                  style: theme.textTheme.labelLarge!
                      .copyWith(color: theme.colorScheme.onBackground)))
        ],
      ),
      if (_success == false)
        Center(
            // Join request failed, show an error to user and keep dialog open
            child: Text("Joining server failed. Check the ID and try again.",
                style: theme.textTheme.labelMedium!
                    .copyWith(color: theme.colorScheme.error)))
    ]);
  }
}

class CreateServerDialog extends StatefulWidget {
  const CreateServerDialog({super.key});

  @override
  State<CreateServerDialog> createState() => _CreateServerDialogState();
}

class _CreateServerDialogState extends State<CreateServerDialog> {
  String _currentText = "";
  bool? _success;

  Future<void> _submit(GlobalState state, {String? text}) async {
    text ??= _currentText;
    var res = await ApiService().createGuild(text, state);
    setState(() {
      _success = res;
    });
    return;
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var appstate = context.watch<GlobalState>();
    return SimpleDialog(
      contentPadding: const EdgeInsets.all(20),
      title: Container(
          padding: const EdgeInsets.only(bottom: 8),
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: theme.colorScheme.outline))),
          child: const Center(child: Text("Create Your Server"))),
      children: [
        // Change here when file uploads are implemented
        Text("SERVER ICON", style: theme.textTheme.labelSmall),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(48), // Image border
              child: SizedBox.fromSize(
                size: const Size.fromRadius(36), // Image radius
                child: Image.network("https://via.placeholder.com/32",
                    fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 24),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                    onPressed: () {},
                    child: Text("Browse", style: theme.textTheme.bodyLarge)),
                const SizedBox(height: 4),
                const Text("Maximum 25MB"),
                const Text("At least 64x64")
              ],
            )
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          autocorrect: false,
          decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              labelText: "Server Name"),
          onChanged: (value) => setState(() {
            _currentText = value;
          }),
          onSubmitted: (value) => _submit(appstate, text: value).then((_) {
            if (_success == true) {
              Navigator.of(context).pop(context); // Kill dialog if it worked
            }
          }),
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
                onPressed: () {
                  _submit(appstate).then((_) {
                    if (_success == true) {
                      Navigator.of(context).pop(context);
                    }
                  });
                },
                style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                        theme.colorScheme.primaryContainer)),
                child: Text("Join",
                    style: theme.textTheme.labelLarge!.copyWith(
                        color: theme.colorScheme.onPrimaryContainer))),
            const SizedBox(width: 12),
            ElevatedButton(
                style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                        theme.colorScheme.background)),
                onPressed: () {
                  Navigator.of(context).pop(context);
                },
                child: Text("Cancel",
                    style: theme.textTheme.labelLarge!
                        .copyWith(color: theme.colorScheme.onBackground)))
          ],
        ),
        if (_success == false)
          Center(
              // Server creation failed. idk why this would happen, maybe the server name was too long or something
              child: Text("Server creation failed. Uh oh",
                  style: theme.textTheme.labelMedium!
                      .copyWith(color: theme.colorScheme.error)))
      ],
    );
  }
}

class CreateChannelDialog extends StatefulWidget {
  const CreateChannelDialog({required this.type, super.key});
  final String type;

  @override
  State<CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends State<CreateChannelDialog> {
  String _currentText = "";
  bool? _success;

  Future<void> _submit(GlobalState state, {String? text}) async {
    text ??= _currentText;
    if (text == "") return;
    if (state.currentGuild == null) return;
    var res = await ApiService().createChannel(
        text, widget.type.toLowerCase(), state.currentGuild!.id, state);
    setState(() {
      _success = res;
    });
    return;
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var appstate = context.watch<GlobalState>();
    return SimpleDialog(contentPadding: const EdgeInsets.all(20), children: [
      TextField(
        autocorrect: false,
        decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            labelText: "${widget.type} Channel Name"),
        onChanged: (value) => setState(() {
          _currentText = value;
        }),
        onSubmitted: (value) => _submit(appstate, text: value).then((_) {
          if (_success == true) Navigator.of(context).pop(context);
        }),
      ),
      const SizedBox(height: 22),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
              onPressed: () => _submit(appstate).then((_) {
                    if (_success == true) Navigator.of(context).pop(context);
                  }),
              style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(
                      theme.colorScheme.primaryContainer)),
              child: Text("Create",
                  style: theme.textTheme.labelLarge!
                      .copyWith(color: theme.colorScheme.onPrimaryContainer))),
          const SizedBox(width: 12),
          ElevatedButton(
              style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all(theme.colorScheme.background)),
              onPressed: () {
                Navigator.of(context).pop(context);
              },
              child: Text("Cancel",
                  style: theme.textTheme.labelLarge!
                      .copyWith(color: theme.colorScheme.onBackground)))
        ],
      ),
      if (_success == false)
        Center(
            child: Text("Channel creation failed.",
                style: theme.textTheme.labelMedium!
                    .copyWith(color: theme.colorScheme.error)))
    ]);
  }
}
