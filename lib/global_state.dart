import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:zling/ui-elements/overlapping_panels.dart';
import 'package:zling/lib/api.dart';
import 'package:zling/lib/models.dart';
import 'globals.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'package:logging/logging.dart';
import 'lib/voice.dart';

// Global State to be passed around to different widgets
class GlobalState extends ChangeNotifier with WidgetsBindingObserver {
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

    // If we have used this guild before and selected a channel, resume to that channel.
    // Otherwise, unselect channels
    if (prevChannelSelection.containsKey(guild)) {
      setChannel(prevChannelSelection[guild]);
    } else if (currentChannel != null) {
      setChannel(null);
    }
    getChannels();
    getMessages();
    notifyListeners();
    // If our websocket isnt connected, wait until it is before subscribing
    if (ws == null) {
      await _wsFirstInit.future;
    }
    subUnsub(sub: guild, unsub: oldCurrentGuild);
  }

  // Turn a string guild id into a Guild object (only if the user is in that guild)
  Future<Guild?> resolveGuild(String gid) async {
    await getGuilds();
    if (guilds == null) return null;
    if (guilds!.where((element) => element.id == gid).isEmpty) return null;
    return guilds!.where((e) => e.id == gid).toList()[0];
  }

  Future<Channel?> resolveChannel(String cid) async {
    await getChannels();
    if (channels == null) return null;
    if (channels!.where((e) => e.id == cid).isEmpty) return null;
    return channels!.where((e) => e.id == cid).toList()[0];
  }

  Channel? currentChannel;
  void setChannel(Channel? channel) async {
    if (typing.isNotEmpty) {
      // When we change channels we want to clear all the typing timers
      typing.values.map((e) => e.cancel());
      typing.removeWhere(
          (__, _) => true); // Its either make typing non-final or this...
    }
    var oldCurrentChannel = currentChannel;
    currentChannel = channel;
    notifyListeners();
    if (ws == null) {
      await _wsFirstInit.future;
    }
    subUnsub(sub: channel, unsub: oldCurrentChannel);
  }

  // Store whether the panels are currently sliding or not
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
    notifyListeners();
  }

  List<Channel>? channels;
  Future<void> getChannels() async {
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
      messages = null;
      moreMessagesToLoad = false;
      notifyListeners();
      return;
    }
    List<Message>? m;
    bool b; // whether we have more messages above to load
    (m, b) = (await ApiService().getMessages(
        currentGuild!.id, currentChannel!.id, limit, this,
        before: before));
    moreMessagesToLoad = b;
    if (m != null) {
      // Get rid of empty messages (shouldn't do anything anyway tho)
      m = m.where((e) => e.content.trim() != "").toList();
      if (before == null || messages == null) {
        messages = m;
      } else {
        // Add the new messages to the start of the existing messages
        messages = m + messages!;
      }
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
    // Notify listeners of logout, which will take us immediately to the login screen
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
  Completer _wsFirstInit = Completer();
  StreamSubscription? _sub;
  void initStream() async {
    if (socketReconnecting = true) {
      // Don't spam connections if it isnt working
      await Future.delayed(const Duration(seconds: 3));
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
    _sub = ws!.stream.listen(handleEvent, onDone: () {
      _logger.info("Socket closed, attempting reconnect");
      _wsFirstInit = Completer();
      socketReconnecting = true;
      initStream();
    }, onError: (e) {
      _logger.warning("Events socket error, reconnecting - ${e.toString()}");
      socketReconnecting = true;
      _wsFirstInit = Completer();
      initStream();
    });
    ws!.sink.add("heartbeat");
    // notifyListeners();
    _wsFirstInit.complete();
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
      if (typing.containsKey(event.messageEvent.author)) {
        typing[event.messageEvent.author]?.cancel();
        typing.remove(event.messageEvent.author);
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
      return false;
    }
    Globals.localUser = res;
    loggedIn = true;
    getGuilds();
    getChannels();
    initStream();
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
          // _logger.info("Socket heartbeat failed, notifying listeners");
          socketBrokenNotified = true;
          notifyListeners();
        }
      }
    });
    WidgetsBinding.instance.addObserver(this);
    voiceChannelTarget.addListener(() => onTargetChange(this));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (ws == null) {
        _wsFirstInit = Completer();
        initStream();
      }
    }
  }

  VoiceState voiceState = VoiceState.disconected;
  Map<String, Peer> voicePeers = {};
  var voiceChannelTarget =
      ValueNotifier<VoiceChannelTarget>(VoiceChannelTarget.none());
  VoiceChannelInfo? voiceChannelCurrent;
  void set(Function callback) {
    callback();
    notifyListeners();
  }

  @override
  void dispose() {
    timer?.cancel();
    _sub?.cancel();
    ws?.sink.close();
    disconnect(this);
    for (Timer t in typing.values) {
      t.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
