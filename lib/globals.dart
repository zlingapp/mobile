import 'dart:core';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class Globals {
  static late SharedPreferences prefs;
  static User? localUser;

  // Guild ID -> List of channels
  static Map<String, List<Channel>?> channelsCache = {};

  // Channel ID -> List of messages
  static Map<String, List<Message>?> messagesCache = {};

  static Future init() async {
    prefs = await SharedPreferences.getInstance();
  }
}
