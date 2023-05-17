import 'dart:io';
import 'package:flutter/material.dart';
import 'package:zling/overlapping_panels.dart';
import 'package:provider/provider.dart';
import 'themes.dart';
import 'views/login_view.dart';
import 'api.dart';
import 'views/left_view.dart';
import 'global_state.dart';
import 'globals.dart';
import 'views/middle_view.dart';
import 'views/right_view.dart';

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
        themeMode: ThemeMode.light,
        home: const DefaultPage(),
      ),
    );
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
            main: const MessagesView(),
            left: const LeftView(),
            right: const RightView(),
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
