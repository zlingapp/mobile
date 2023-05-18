import 'package:flutter/material.dart';
import 'package:zling/overlapping_panels.dart';
import 'package:zling/api.dart';
import 'package:zling/models.dart';
import 'globals.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';

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
  void getMessages({int limit = 50}) async {
    if (currentGuild == null || currentChannel == null) {
      messages = [];
      notifyListeners();
      return;
    }
    messages = (await ApiService()
        .getMessages(currentGuild!.id, currentChannel!.id, limit, this));
    notifyListeners();
  }

  void ensureLoggedIn() async {
    loggedIn = (await ApiService().ensureLoggedIn(this));
    notifyListeners();
  }

  void logOut() {
    loggedIn = false;
    notifyListeners();
  }

  WebSocketChannel? ws;
  void initStream() async {
    ws = await ApiService().wsConnect(this);
    ws!.stream.listen(handleEvent,
        onError: (error) => print(error), onDone: () => initStream());
    ws!.sink.add("heartbeat");
    return;
  }

  void handleEvent(dynamic response) {
    var event = eventResponseFromJson(response.toString());
    if (event.topic.type == "channel") {
      if (currentChannel == null || event.topic.id != currentChannel!.id) {
        // Log useless subscription
        return;
      }
      messages ??= [];
      messages!.add(Message(
          author: event.event.author,
          content: event.event.content,
          createdAt: event.event.createdAt,
          id: event.event.id));
      notifyListeners();
    } else if (event.topic.type == "guild") {
      // NOT IMPLEMENTED
    } else {
      //Log uncaught type
    }
  }

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
    notifyListeners();
    return true;
  }

  GlobalState() {
    prevChannelSelection = {};
    ensureLoggedIn();
    getGuilds();
    timer = Timer.periodic(
        const Duration(seconds: 5),
        (Timer t) => {
              if (ws != null) {ws!.sink.add("heartbeat")}
            });
  }

  @override
  void dispose() {
    timer?.cancel;
    ws?.sink.close();
    super.dispose();
  }
}
