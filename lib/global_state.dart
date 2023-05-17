import 'package:flutter/material.dart';
import 'package:zling/overlapping_panels.dart';
import 'package:zling/api.dart';
import 'package:zling/models.dart';
import 'globals.dart';

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
  void getGuilds() async {
    guilds = (await ApiService().getGuilds(this));
    if (guilds == null) {
      notifyListeners();
      return null;
    }
    prevChannelSelection = List.filled(guilds!.length, 0);
    notifyListeners();
  }

  List<Channel>? channels;
  void getChannels() async {
    if (guilds == null || guilds!.isEmpty) {
      return;
    }
    channels =
        (await ApiService().getChannels(guilds![selectedGuildIndex].id, this));
    notifyListeners();
  }

  // List<Message>? messages = [];

  void ensureLoggedIn() async {
    loggedIn = (await ApiService().ensureLoggedIn(this));
  }

  void logOut() {
    loggedIn = false;
    notifyListeners();
  }

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
    ensureLoggedIn();
    getGuilds();
    getChannels();
  }
}
