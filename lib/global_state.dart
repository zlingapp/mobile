import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:zling/overlapping_panels.dart';
import 'package:zling/api.dart';
import 'package:zling/models.dart';
import 'globals.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'package:logging/logging.dart';

// Global State to be passed around to different widgets
class GlobalState extends ChangeNotifier {
  bool? loggedIn;

  // Selected guild from the left sidebar
  Guild? currentGuild;

  void setGuild(Guild guild) {
    if (ws != null) {
      if (currentGuild == null) {
        ws!.sink.add('{"sub":["guild:${guild.id}"]}');
      } else {
        ws!.sink.add(
            '{"sub":["guild:${guild.id}"],"unsub":["guild:${currentGuild!.id}"]}');
      }
    }
    currentGuild = guild;
    notifyListeners();
  }

  Channel? currentChannel;
  void setChannel(Channel? channel) {
    if (ws != null && channel != null) {
      if (currentChannel == null) {
        ws!.sink.add('{"sub":["channel:${channel.id}"]}');
      } else {
        ws!.sink.add(
            '{"sub":["channel:${channel.id}"],"unsub":["channel:${currentChannel!.id}"]}');
      }
    } else if (ws != null && currentChannel != null) {
      ws!.sink.add('{"unsub":["channel:${currentChannel!.id}"]}');
    }
    currentChannel = channel;
    notifyListeners();
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
  void getGuilds() async {
    guilds = (await ApiService().getGuilds(this));
    if (guilds == null) {
      notifyListeners();
      return null;
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
  Future<void> getMessages({int limit = 50}) async {
    if (currentGuild == null || currentChannel == null) {
      messages = [];
      notifyListeners();
      return;
    }
    messages = (await ApiService()
        .getMessages(currentGuild!.id, currentChannel!.id, limit, this));
    if (messages != null) {
      messages = messages?.where((e) => e.content.trim() != "").toList();
    }
    notifyListeners();
  }

  void ensureLoggedIn() async {
    loggedIn = (await ApiService().ensureLoggedIn(this));
    if (loggedIn == true) {
      initStream();
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
      socketReconnecting = true;
      initStream();
    });
    ws!.sink.add("heartbeat");
    notifyListeners();
    return;
  }

  void handleEvent(dynamic response) {
    var msg = jsonDecode(response);
    if (msg["topic"]["type"] == "channel") {
      var event = eventResponseFromJson(response.toString());
      if (currentChannel == null || event.topic.id != currentChannel!.id) {
        _logger.info("Useless message subscription recorded");
        return;
      }
      messages ??= [];
      messages!.add(Message(
          author: event.event.author,
          content: event.event.content,
          createdAt: event.event.createdAt,
          id: event.event.id));
      notifyListeners();
    } else if (msg["topic"]["type"] == "guild") {
      // NOT IMPLEMENTED
    } else {
      //Log uncaught type
    }
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
    initStream();
    getGuilds();
    getChannels();
    notifyListeners();
    return true;
  }

  bool socketBrokenNotified = false;
  final _logger = Logger("GlobalState");
  GlobalState() {
    prevChannelSelection = {};
    ensureLoggedIn();
    getGuilds();
    timer = Timer.periodic(const Duration(seconds: 5), (Timer t) {
      if (ws != null) {
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
    super.dispose();
  }
}
