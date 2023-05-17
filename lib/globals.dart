import 'dart:core';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class Globals {
  static late SharedPreferences prefs;
  static User? localUser;

  static Future init() async {
    prefs = await SharedPreferences.getInstance();
  }
}
