import 'dart:core';
import 'dart:io';
import 'package:zling/models.dart';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'globals.dart';
import 'main.dart';

class ApiTokens {
  String accessToken;
  DateTime accessTokenExpiry;
  String refreshToken;
  DateTime refreshTokenExpiry;
  ApiTokens(this.accessToken, this.accessTokenExpiry, this.refreshToken,
      this.refreshTokenExpiry);
}

ApiTokens? getTokens() {
  var prefs = Globals.prefs;
  String? accessToken = prefs.getString("accessToken");
  String? refreshToken = prefs.getString("refreshToken");
  int? accessTokenExpiry = prefs.getInt("accessTokenExpiry");
  int? refreshTokenExpiry = prefs.getInt("refreshTokenExpiry");

  if (accessToken == null ||
      refreshToken == null ||
      accessTokenExpiry == null ||
      refreshTokenExpiry == null) {
    return null;
  }
  return ApiTokens(
      accessToken,
      DateTime.fromMillisecondsSinceEpoch(accessTokenExpiry),
      refreshToken,
      DateTime.fromMillisecondsSinceEpoch(refreshTokenExpiry));
}

void setTokens(ApiTokens? tokens) {
  var prefs = Globals.prefs;
  if (tokens == null) {
    prefs.remove("accessToken");
    prefs.remove("refreshToken");
    prefs.remove("accessTokenExpiry");
    prefs.remove("refreshTokenExpiry");
    return;
  }
  prefs.setString("accessToken", tokens.accessToken);
  prefs.setString("refreshToken", tokens.refreshToken);
  prefs.setInt(
      "accessTokenExpiry", tokens.accessTokenExpiry.millisecondsSinceEpoch);
  prefs.setInt(
      "refreshTokenExpiry", tokens.refreshTokenExpiry.millisecondsSinceEpoch);
}

enum HttpMethod { post, get }

const String baseURL = String.fromEnvironment("API_BASE_URL");
const String guildsEndpoint = "$baseURL/guilds";
const String authEndpoint = "$baseURL/auth";
const String eventsEndpoint = "$baseURL/events/ws";
const String logOutEndpoint = "$baseURL/auth/logout";
const String reissueEndpoint = "$baseURL/auth/reissue";
const String whoamiEndpoint = "$baseURL/auth/whoami";
const String logInEndpoint = "$baseURL/auth/login";

Function channelsEndpoint = (String id) => "$baseURL/guilds/$id/channels";

Function messagesEndpoint = (String gid, String cid, int limit) =>
    "$baseURL/guilds/$gid/channels/$cid/messages?limit=$limit";

DateTime tokenExpiry(String token) {
  final base64Url = token.split(".")[1];
  final base64 = const Base64Codec().normalize(base64Url);

  final binary = base64Decode(base64);

  var timestamp = 0;

  for (var i = 0; i < binary.length; i++) {
    timestamp = (timestamp << 8) | binary[i];
  }
  return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
}

class AllowSelfSigned extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => (true);
  }
}

class ApiService {
  Future<List<Guild>?> getGuilds(GlobalState state) async {
    try {
      var response = await authFetch(HttpMethod.get, guildsEndpoint, state);
      if (response == null) {
        return null;
      }
      if (response.statusCode == 200) {
        List<Guild> guilds = guildFromJson(response.body);
        return guilds;
      }
    } catch (e) {
      log(e.toString());
    }
    return null;
  }

  Future<http.Response?> authFetch(
      HttpMethod method, String endpoint, GlobalState state,
      {Map<String, String>? headers, String? body}) async {
    ApiTokens? tokens = getTokens();
    if (tokens != null) {
      final hasAccessTokenExpired =
          tokens.accessTokenExpiry.isBefore(DateTime.now());
      final hasRefreshTokenExpired =
          tokens.refreshTokenExpiry.isBefore(DateTime.now());
      if (hasAccessTokenExpired) {
        if (hasRefreshTokenExpired) {
          logOut(state);
          return null;
        }

        var res = await http.post(Uri.parse(reissueEndpoint),
            headers: {"Content-Type": "application/json"},
            body: '{"refreshToken": "${tokens.refreshToken}"}');
        if (res.statusCode != 200) {
          logOut(state);
          return null;
        }

        var json = jsonDecode(res.body);
        setTokens(ApiTokens(
            json["accessToken"],
            tokenExpiry(json["accessToken"]),
            json["refreshToken"],
            tokenExpiry(json["refreshToken"])));
        tokens = getTokens();
      }
      headers ??= {};
      if (tokens != null) {
        headers = {...headers, "Authorization": "Bearer ${tokens.accessToken}"};
      }
    }
    http.Response res;
    switch (method) {
      case HttpMethod.get:
        res = await http.get(Uri.parse(endpoint), headers: headers);
        break;
      case HttpMethod.post:
        body ??= "";
        res =
            await http.post(Uri.parse(endpoint), headers: headers, body: body);
        break;
    }
    return res;
  }

  Future<bool> tryObtainLocalUser(GlobalState state) async {
    if (Globals.localUser == null) {
      try {
        var res = await authFetch(HttpMethod.get, whoamiEndpoint, state);
        if (res != null && res.statusCode == 200) {
          Globals.localUser = userFromJson(res.body);
        }
      } catch (e) {
        log(e.toString());
      }
      if (Globals.localUser == null) {
        return false;
      }
    }
    return true;
  }

  Future<bool> ensureLoggedIn(GlobalState state) async {
    if (!(await tryObtainLocalUser(state))) {
      return false;
    }
    return true;
  }

  Future<User?> logIn(String email, String password, GlobalState state) async {
    var res = await authFetch(HttpMethod.post, logInEndpoint, state,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}));
    if (res == null || res.statusCode != 200) {
      return null;
    }
    var resObj = loginResponseFromJson(res.body);
    setTokens(ApiTokens(resObj.accessToken, tokenExpiry(resObj.accessToken),
        resObj.refreshToken, tokenExpiry(resObj.refreshToken)));
    return resObj.user;
  }

  void logOut(GlobalState state) async {
    final tokens = getTokens();
    if (tokens != null && tokens.refreshTokenExpiry.isBefore(DateTime.now())) {
      await authFetch(HttpMethod.get, logOutEndpoint, state);
    }
    state.logOut();
    setTokens(null);
    Globals.localUser = null;
  }

  Future<List<Channel>?> getChannels(String id, GlobalState state) async {
    if (Globals.channelsCache.containsKey(id)) {
      return Globals.channelsCache[id];
    }
    try {
      var response =
          await authFetch(HttpMethod.get, channelsEndpoint(id), state);
      if (response == null) {
        return null;
      }
      if (response.statusCode == 200) {
        List<Channel> channels = channelFromJson(response.body);
        Globals.channelsCache[id] = channels;
        return channels;
      }
    } catch (e) {
      log(e.toString());
    }
    return null;
  }

  Future<List<Message>?> getMessages(
      String gid, String cid, int limit, GlobalState state) async {
    if (limit > 50) {
      limit = 50;
    }
    if (Globals.messagesCache.containsKey(cid) &&
        Globals.messagesCache[cid] != null) {
      // Cache hit
      if (limit <= Globals.messagesCache[cid]!.length) {
        return Globals.messagesCache[cid];
      }
    }
    try {
      var response = await authFetch(
          HttpMethod.get, messagesEndpoint(gid, cid, limit), state);
      if (response == null) {
        return null;
      }
      if (response.statusCode == 200) {
        List<Message> messages = messageFromJson(response.body);
        messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return messages;
      }
    } catch (e) {
      log(e.toString());
    }
    return null;
  }
}
