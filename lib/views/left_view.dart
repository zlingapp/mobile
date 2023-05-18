import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zling/models.dart';
import '../global_state.dart';

class LeftView extends StatelessWidget {
  const LeftView({super.key});

  @override
  Widget build(BuildContext context) {
    final appstate = context.watch<GlobalState>();
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        color: theme.colorScheme.background,
        child: Row(
          children: [
            GuildScrollBar(appstate: appstate),
            const ChannelsView(),
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
    appstate.getChannels();
    return Expanded(
      child: SafeArea(
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
                        bottom: BorderSide(color: theme.colorScheme.outline))),
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: appstate.currentGuild == null
                                ? const Text("...",
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
                            onPressed: () {},
                            icon: const Icon(Icons.more_horiz))
                      ],
                    ),
                    const Text(
                      "server description",
                      style: TextStyle(color: Colors.grey),
                    )
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
                              const Text("No Channels Here")
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
                      ...(appstate.channels == null
                          ? const [Center(child: CircularProgressIndicator())]
                          : appstate.channels!
                              .where((i) => (i.type == "text"))
                              .map((channel) => ListTile(
                                    leading: const Icon(Icons.tag),
                                    selected:
                                        (appstate.currentChannel == channel),
                                    horizontalTitleGap: 0,
                                    visualDensity: const VisualDensity(
                                        horizontal: 0, vertical: -4),
                                    title: Text(channel.name),
                                    onTap: () {
                                      appstate.setChannel(channel);
                                      // appstate.prevChannelSelection![appstate
                                      // .channels!
                                      // .indexOf(channel)] =
                                      // appstate.channels!.indexOf(channel);
                                      appstate.getMessages();
                                    },
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
                      ...(appstate.channels == null
                          ? const [Center(child: CircularProgressIndicator())]
                          : appstate.channels!
                              .where((i) => i.type == "voice")
                              .map((channel) => ListTile(
                                    leading: const Icon(Icons.headphones),
                                    selected:
                                        // REPLACE HERE WITH VOICE INDEX
                                        appstate.currentChannel != null &&
                                            appstate.currentChannel == channel,
                                    horizontalTitleGap: 0,
                                    title: Text(channel.name),
                                    onTap: () {
                                      // Voice Stuff Here
                                    },
                                  )))
                    ],
                  ),
                ),
              )
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
    required this.appstate,
  });

  final GlobalState appstate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.background,
      child: SafeArea(
        child: appstate.guilds == null || appstate.guilds!.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height),
                  child: IntrinsicHeight(
                    // TODO Replace this with a listview for more fluency - remove guildIndex
                    child: NavigationRail(
                        extended: false,
                        selectedIndex: appstate.selectedGuildIndex,
                        destinations: [
                          ...appstate.guilds!.asMap().entries.map((entry) {
                            int idx = entry.key;
                            Guild x = entry.value;
                            return NavigationRailDestination(
                              label: Text(x.name),
                              icon: GuildIcon(
                                  iconURL: "https://placeholder.com/32",
                                  selected:
                                      (idx == appstate.selectedGuildIndex)),
                            );
                          }).toList(),
                          const NavigationRailDestination(
                              label: Text("sus"), icon: Icon(Icons.add))
                        ],
                        onDestinationSelected: (value) {
                          if (appstate.guilds == null ||
                              value >= appstate.guilds!.length) {
                            return;
                          }
                          appstate.setGuild(appstate.guilds![value]);
                          appstate.getChannels();
                          // appstate.setChannelIndex(
                          // appstate.prevChannelSelection![value]);
                        }),
                  ),
                ),
              ),
      ),
    );
  }
}

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
