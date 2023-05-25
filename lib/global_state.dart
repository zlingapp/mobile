import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:zling/ui-elements/overlapping_panels.dart';
import 'package:zling/lib/api.dart';
import 'package:zling/lib/models.dart';
import 'globals.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'package:logging/logging.dart';

// Global State to be passed around to different widgets
class GlobalState extends ChangeNotifier {
  bool? loggedIn;

  // Selected guild from the left sidebar
  Guild? currentGuild;

  void subUnsub({dynamic sub, dynamic unsub}) {
    if (ws == null) {
      return;
    }
    if (sub is Guild && unsub == null) {
      ws!.sink.add(json.encode({
        "sub": ["guild:${sub.id}"]
      }));
      return;
    }
    if (sub is Guild && unsub is Guild) {
      ws!.sink.add(json.encode({
        "sub": ["guild:${sub.id}"],
        "unsub": ["guild:${unsub.id}"]
      }));
      return;
    }
    if (sub == null && unsub is Guild) {
      ws!.sink.add(json.encode({
        "unsub": ["guild:${unsub.id}"]
      }));
      return;
    }

    if (sub is Channel && unsub == null) {
      ws!.sink.add(json.encode({
        "sub": ["channel:${sub.id}"]
      }));
      return;
    }
    if (sub is Channel && unsub is Channel) {
      ws!.sink.add(json.encode({
        "sub": ["channel:${sub.id}"],
        "unsub": ["channel:${unsub.id}"]
      }));
      return;
    }
    if (sub == null && unsub is Channel) {
      ws!.sink.add(json.encode({
        "unsub": ["channel:${unsub.id}"]
      }));
      return;
    }
    _logger.warning(
        "Uncaught subscription type-${sub.runtimeType}-${unsub.runtimeType}");
  }

  void setGuild(Guild guild) async {
    var oldCurrentGuild = currentGuild;
    currentGuild = guild;
    if (prevChannelSelection.containsKey(guild)) {
      setChannel(prevChannelSelection[guild]);
    } else if (currentChannel != null) {
      setChannel(null);
    }
    getChannels();
    getMessages();
    notifyListeners();
    if (ws == null) {
      await wsFirstInit.future;
    }
    subUnsub(sub: guild, unsub: oldCurrentGuild);
  }

  Future<Guild?> resolveGuild(String gid) async {
    await getGuilds();
    if (guilds == null) return null;
    if (guilds!.where((element) => element.id == gid).isEmpty) return null;
    return guilds!.where((e) => e.id == gid).toList()[0];
  }

  Channel? currentChannel;
  void setChannel(Channel? channel) async {
    var oldCurrentChannel = currentChannel;
    currentChannel = channel;
    notifyListeners();
    if (ws == null) {
      await wsFirstInit.future;
    }
    subUnsub(sub: channel, unsub: oldCurrentChannel);
  }

  bool inMove = false;
  void stationary() {
    inMove = false;
    notifyListeners();
  }

  void moving() {
    inMove = true;
    notifyListeners();
  }

  // Current menu in the foreground (left,main,right)
  RevealSide currentMenuSide = RevealSide.main;
  void setMenuSide(RevealSide side) {
    currentMenuSide = side;
    notifyListeners();
  }

  List<Guild>? guilds;
  late Map<Guild, Channel> prevChannelSelection;
  Future<void> getGuilds() async {
    guilds = (await ApiService().getGuilds(this));
    if (guilds == null) {
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  List<Channel>? channels;
  void getChannels() async {
    if (currentGuild == null) {
      return;
    }
    channels = (await ApiService().getChannels(currentGuild!.id, this));
    notifyListeners();
  }

  List<Message>? messages = [];
  bool moreMessagesToLoad = false;
  Future<void> getMessages({int limit = 50, DateTime? before}) async {
    if (currentGuild == null || currentChannel == null) {
      messages = [];
      moreMessagesToLoad = false;
      notifyListeners();
      return;
    }
    List<Message>? m;
    bool b;
    (m, b) = (await ApiService().getMessages(
        currentGuild!.id, currentChannel!.id, limit, this,
        before: before));
    moreMessagesToLoad = b;
    if (m != null) {
      m = m.where((e) => e.content.trim() != "").toList();
      messages = (before == null && messages != null) ? m : m + messages!;
    } else {
      messages = null;
    }
    notifyListeners();
  }

  void ensureLoggedIn() async {
    loggedIn = (await ApiService().ensureLoggedIn(this));
    if (loggedIn == true) {
      initStream();
      getGuilds();
    }
    notifyListeners();
  }

  void logOut() {
    loggedIn = false;
    notifyListeners();
  }

  bool socketConnectingFromBroken = false;
  void reconnectingFromBroken() {
    socketConnectingFromBroken = true;
    notifyListeners();
  }

  WebSocketChannel? ws;
  bool socketReconnecting = false;
  Completer wsFirstInit = Completer();
  void initStream() async {
    if (socketReconnecting = true) {
      await Future.delayed(const Duration(seconds: 5));
    }
    socketReconnecting = false;
    ws = await ApiService().wsConnect(this);
    if (ws == null) {
      _logger.info(
          "Socket initialisation request returned not successful, retrying");
      socketReconnecting = true;
      initStream();
      return;
    }
    ws!.stream.listen(handleEvent, onDone: () {
      _logger.info("Socket closed, attempting reconnect");
      wsFirstInit = Completer();
      socketReconnecting = true;
      initStream();
    });
    ws!.sink.add("heartbeat");
    notifyListeners();
    wsFirstInit.complete();
    return;
  }

  void handleEvent(dynamic response) {
    var msg = jsonDecode(response);
    if (msg["event"]["type"] == "message") {
      var event = messageEventResponseFromJson(response);
      if (currentChannel == null || event.topic.id != currentChannel!.id) {
        _logger.info("Useless guild subscription detected (message)");
        return;
      }
      messages ??= [];
      messages!.add(Message(
          author: event.messageEvent.author,
          content: event.messageEvent.content,
          createdAt: event.messageEvent.createdAt,
          id: event.messageEvent.id));
      notifyListeners();
    } else if (msg["event"]["type"] == "channel_list_update") {
      getChannels();
    } else if (msg["event"]["type"] == "typing") {
      var event = typingEventResponseFromJson(response);
      if (currentChannel == null || event.topic.id != currentChannel!.id) {
        _logger.info("Useless guild subscription detected (typing)");
      }
      var user = event.typingEvent.user;
      if (user.id == Globals.localUser?.id) {
        return;
      }
      if (typing.containsKey(user)) {
        typing[event.typingEvent.user]?.cancel();
      }
      typing[user] = typingTimer(event.typingEvent.user);
      notifyListeners();
    } else {
      //Log uncaught type
      _logger.info("Uncaught websocket event of type ${msg['event']['type']}");
    }
  }

  final Map<Member, Timer> typing = {};
  Timer typingTimer(Member user) {
    return timer = Timer(const Duration(seconds: 5), () {
      typing.remove(user);
      notifyListeners();
    });
  }

  void sendTyping() async {
    ApiService().sendTyping(this);
  }

  final msgScrollController = ScrollController();
  Timer? timer;

  Future<bool> login(String email, String password) async {
    User? res = (await ApiService().logIn(email, password, this));
    if (res == null) {
      notifyListeners();
      return false;
    }
    Globals.localUser = res;
    loggedIn = true;
    getGuilds();
    getChannels();
    initStream();
    notifyListeners();
    return true;
  }

  bool socketBrokenNotified = false;
  final _logger = Logger("GlobalState");
  GlobalState() {
    prevChannelSelection = {};
    ensureLoggedIn();
    timer = Timer.periodic(const Duration(seconds: 5), (Timer t) {
      if (ws != null && loggedIn == true) {
        if (socketBrokenNotified) {
          socketBrokenNotified = false;
        }
        ws!.sink.add("heartbeat");
      } else {
        if (!socketBrokenNotified &&
            !socketConnectingFromBroken &&
            !socketReconnecting) {
          _logger.info("Socket heartbeat failed, notifying listeners");
          socketBrokenNotified = true;
          notifyListeners();
        }
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    ws?.sink.close();
    for (Timer t in typing.values) {
      t.cancel();
    }
    super.dispose();
  }
}
