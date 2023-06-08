import 'dart:core';
import 'package:shared_preferences/shared_preferences.dart';
import 'lib/models.dart';

class Globals {
  static late SharedPreferences prefs;
  static User? localUser;

  static Future init() async {
    prefs = await SharedPreferences.getInstance();
  }
}

enum HttpMethod { post, get }

const String hostURL = String.fromEnvironment("API_HOST");
const String baseURL = "https://$hostURL/api";
const String guildsEndpoint = "$baseURL/guilds";
const String authEndpoint = "$baseURL/auth";
const String eventsEndpoint = "$baseURL/events/ws";
const String logOutEndpoint = "$baseURL/auth/logout";
const String reissueEndpoint = "$baseURL/auth/reissue";
const String whoamiEndpoint = "$baseURL/auth/whoami";
const String logInEndpoint = "$baseURL/auth/login";

const String voicePeersEndpoint = "$baseURL/voice/peers";

const String voiceConsumeEndpoint = "$baseURL/voice/consume";

const String voiceLeaveEndpoint = "$baseURL/voice/leave";

const String voiceSendTransportCreateEndpoint =
    "$baseURL/voice/transport/create?type=send";
const String voiceSendTransportConnectEndpoint =
    "$baseURL/voice/transport/connect?type=send";

const String voiceProduceEndpoint = "$baseURL/voice/produce";

const String voiceRecvTransportCreateEndpoint =
    "$baseURL/voice/transport/create?type=recv";
const String voiceRecvTransportConnectEndpoint =
    "$baseURL/voice/transport/connect?type=recv";

Function joinVoiceEndpoint = (String cid) => "$baseURL/voice/join?c=$cid";

Function joinGuildEndpoint = (String gid) => "$baseURL/guilds/$gid/join";

Function typingEndpoint =
    (String gid, String cid) => "$baseURL/guilds/$gid/channels/$cid/typing";

Function wsEndpoint =
    (accessToken) => "ws://$hostURL/api/events/ws/?auth=$accessToken";

Function voiceSocketEndpoint = (String identity, String token) =>
    "wss://$hostURL/api/voice/ws/?i=$identity&t=$token";

Function channelsEndpoint = (String id) => "$baseURL/guilds/$id/channels";

Function messagesEndpoint =
    (String gid, String cid, int limit, DateTime? before) => (before == null)
        ? "$baseURL/guilds/$gid/channels/$cid/messages?limit=$limit"
        : "$baseURL/guilds/$gid/channels/$cid/messages?limit=$limit&before=${before.toUtc().toIso8601String()}";

Function sendMessageEndpoint =
    (String gid, String cid) => "$baseURL/guilds/$gid/channels/$cid/messages";
