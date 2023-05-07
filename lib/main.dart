import 'dart:io';

import 'package:blurrycontainer/blurrycontainer.dart';
import 'package:flutter/material.dart';
import 'package:zling/overlapping_panels.dart';
import 'package:provider/provider.dart';
import 'package:zling/themes.dart';
import 'package:zling/api.dart';
import 'package:zling/models.dart';
import 'globals.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Globals.init().then((value) => {runApp(const App())});
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    HttpOverrides.global = AllowSelfSigned();
    return ChangeNotifierProvider(
      create: (context) => GlobalState(),
      child: MaterialApp(
        title: 'Zling Chat',
        theme: lightTheme,
        darkTheme: darkTheme,
        home: const DefaultPage(),
      ),
    );
  }
}

// Global State to be passed around to different widgets
class GlobalState extends ChangeNotifier {
  bool? loggedIn;

  // Selected guild from the left sidebar
  var selectedGuildIndex = 0;
  Guild? currentGuild;
  void setGuildIndex(int idx) {
    selectedGuildIndex = idx;
    if (guilds == null) {
      currentGuild == null;
    } else {
      currentGuild == guilds![idx];
    }
    notifyListeners();
  }

  var selectedChannelIndex = 0;
  Channel? currentChannel;
  void setChannelIndex(int idx) {
    selectedChannelIndex = idx;
    if (channels != null && channels!.isNotEmpty) {
      currentChannel = channels![idx];
    }
    notifyListeners();
  }

  // Current menu in the foreground (left,main,right)
  RevealSide currentMenuSide = RevealSide.main;
  void setMenuSide(RevealSide side) {
    currentMenuSide = side;
    notifyListeners();
  }

  List<Guild>? guilds;
  List<int>? prevChannelSelection;
  void _getGuilds() async {
    guilds = (await ApiService().getGuilds(this));
    if (guilds == null) {
      notifyListeners();
      return null;
    }
    prevChannelSelection = List.filled(guilds!.length, 0);
    notifyListeners();
  }

  List<Channel>? channels;
  void _getChannels() async {
    if (guilds == null || guilds!.isEmpty) {
      return;
    }
    channels =
        (await ApiService().getChannels(guilds![selectedGuildIndex].id, this));
    notifyListeners();
  }

  // List<Message>? messages = [];

  void _ensureLoggedIn() async {
    loggedIn = (await ApiService().ensureLoggedIn(this));
  }

  void logOut() {
    loggedIn = false;
    notifyListeners();
  }

  Future<bool> _login(String email, String password) async {
    User? res = (await ApiService().logIn(email, password, this));
    if (res == null) {
      notifyListeners();
      return false;
    }
    Globals.localUser = res;
    loggedIn = true;
    _getGuilds();
    _getChannels();
    notifyListeners();
    return true;
  }

  GlobalState() {
    _ensureLoggedIn();
    _getGuilds();
    _getChannels();
  }
}

// Root widget housing all the other components
class DefaultPage extends StatelessWidget {
  const DefaultPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Watch global state and get rebuilt on changes
    var appstate = context.watch<GlobalState>();

    final theme = Theme.of(context);

    Widget page;
    if (appstate.loggedIn == null) {
      page = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (!appstate.loggedIn!) {
      page = LoginView(appstate: appstate);
    } else {
      page = Stack(
        children: [
          OverlappingPanels(
            restWidth:
                50, // Width of the main panel still shown if a side panel is focused
            main: Builder(builder: (context) {
              return const MessagesView();
            }),
            left: Scaffold(
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
            ),
            right: Scaffold(
                backgroundColor: theme.colorScheme.background,
                body: const SafeArea(
                    child: Center(child: Text("this is the right")))),
            onSideChange: (side) {
              appstate.setMenuSide(side);
            },
          ),
        ],
      );
    }
    return page;
  }
}

class ChannelsView extends StatelessWidget {
  const ChannelsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appstate = context.watch<GlobalState>();
    appstate._getChannels();
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
                            child: appstate.guilds == null ||
                                    appstate.guilds!.isEmpty
                                ? const Text("...",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18))
                                : Text(
                                    appstate
                                        .guilds![appstate.selectedGuildIndex]
                                        .name,
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
                                        appstate.channels!.indexOf(channel) ==
                                            appstate.selectedChannelIndex,
                                    horizontalTitleGap: 0,
                                    visualDensity: const VisualDensity(
                                        horizontal: 0, vertical: -4),
                                    title: Text(channel.name),
                                    onTap: () {
                                      appstate.setChannelIndex(
                                          appstate.channels!.indexOf(channel));
                                      appstate.prevChannelSelection![
                                              appstate.selectedGuildIndex] =
                                          appstate.channels!.indexOf(channel);
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
                                        appstate.channels!.indexOf(channel) ==
                                            appstate.selectedChannelIndex,
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
                    child: NavigationRail(
                        extended: false,
                        selectedIndex: appstate.selectedGuildIndex,
                        destinations:
                            appstate.guilds!.asMap().entries.map((entry) {
                          int idx = entry.key;
                          Guild x = entry.value;
                          return NavigationRailDestination(
                            label: Text(x.name),
                            icon: GuildIcon(
                                iconURL: "https://placeholder.com/32",
                                selected: (idx == appstate.selectedGuildIndex)),
                          );
                        }).toList(),
                        onDestinationSelected: (value) {
                          appstate.setGuildIndex(value);
                          appstate.currentGuild = appstate.guilds![value];
                          appstate._getChannels();
                          appstate.setChannelIndex(
                              appstate.prevChannelSelection![value]);
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

class MessagesView extends StatelessWidget {
  const MessagesView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var appstate = context.watch<GlobalState>();
    var theme = Theme.of(context);
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
                    foregroundImage: NetworkImage(chatEntry['user']['avatar']),
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
  }
}

class LoginView extends StatefulWidget {
  const LoginView({super.key, required this.appstate});
  final GlobalState appstate;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  String _emailField = "";
  String _passwordField = "";
  bool? _loadingOrFailed = false; // True if loading, null if login failed.
  bool _invalidPassword = false;
  bool _invalidEmail = false;
  bool _passwordVisible = false;

  static final emailRegex = RegExp(
      r"""^(([^<>()[\]\.,;:\s@\"]+(\.[^<>()[\]\.,;:\s@\"]+)*)|(\".+\"))@(([^<>()[\]\.,;:\s@\"]+\.)+[^<>()[\]\.,;:\s@\"]{2,})$""");
  static final passwordRegex = RegExp(r"""^[a-zA-Z0-9_]{3,16}$""");

  void validateEmail() {
    RegExpMatch? match = emailRegex.firstMatch(_emailField);
    if (match == null) {
      _invalidEmail = true;
    } else {
      _invalidEmail = false;
    }
  }

  void validatePassword() {
    RegExpMatch? match = passwordRegex.firstMatch(_passwordField);
    if (match == null) {
      _invalidPassword = true;
    } else {
      _invalidPassword = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    var appstate = context.watch<GlobalState>();
    var theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            image: DecorationImage(
                image: AssetImage("assets/login-background.jpg"),
                fit: BoxFit.cover)),
        child: Center(
          child: BlurryContainer(
            borderRadius: BorderRadius.zero,
            color: const Color.fromARGB(150, 50, 50, 50),
            blur: 64,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Welcome Back!",
                    style: theme.primaryTextTheme.displayMedium!
                        .copyWith(fontSize: 32, fontWeight: FontWeight.bold)),
                Text("Log into you account to continue",
                    style: theme.primaryTextTheme.labelMedium!
                        .copyWith(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 48),
                TextField(
                  autocorrect: false,
                  style: theme.primaryTextTheme.bodyMedium!
                      .copyWith(fontSize: 18, decoration: TextDecoration.none),
                  onChanged: (value) {
                    setState(() {
                      _emailField = value;
                      validateEmail();
                    });
                  },
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), hintText: "Email"),
                ),
                if (_emailField != "" && _invalidEmail)
                  Row(
                    children: [
                      Text("INVALID EMAIL",
                          textAlign: TextAlign.left,
                          style: theme.primaryTextTheme.labelSmall!.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: theme.colorScheme.error)),
                    ],
                  ),
                const SizedBox(height: 12),
                TextField(
                    autocorrect: false,
                    style: theme.primaryTextTheme.bodyMedium!.copyWith(
                        fontSize: 18, decoration: TextDecoration.none),
                    onChanged: (value) {
                      setState(() {
                        _passwordField = value;
                        validatePassword();
                      });
                    },
                    obscureText: !_passwordVisible,
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: "Password",
                        suffixIcon: IconButton(
                            onPressed: () {
                              setState(
                                  () => (_passwordVisible = !_passwordVisible));
                            },
                            icon: Icon(_passwordVisible
                                ? Icons.visibility
                                : Icons.visibility_off)))),
                if (_passwordField != "" && _invalidPassword)
                  Row(
                    children: [
                      Text("INVALID PASSWORD",
                          textAlign: TextAlign.left,
                          style: theme.primaryTextTheme.labelSmall!.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: theme.colorScheme.error)),
                    ],
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary),
                    onPressed: () {
                      if (_loadingOrFailed != true &&
                          !_invalidEmail &&
                          !_invalidPassword) {
                        _loadingOrFailed = true;
                        appstate
                            ._login(_emailField, _passwordField)
                            .then((value) => (setState(() {
                                  if (value) {
                                    _loadingOrFailed = false;
                                  } else {
                                    _loadingOrFailed = null;
                                  }
                                })));
                      }
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width / 3,
                      child: Center(
                          child: Text("Log In",
                              style: theme.primaryTextTheme.labelLarge!
                                  .copyWith(
                                      color: theme.colorScheme.onPrimary))),
                    )),
                if (_loadingOrFailed == true)
                  const Center(child: CircularProgressIndicator()),
                if (_loadingOrFailed == null)
                  Text("Login Failed, please try again",
                      style: theme.textTheme.bodyLarge!
                          .copyWith(color: theme.colorScheme.error))
              ],
            ),
          ),
        ),
      ),
    );
  }
}
