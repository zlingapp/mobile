import 'dart:async';
import 'dart:core';
import 'dart:io';
import 'package:zling/lib/models.dart';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart';
import '../global_state.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logging/logging.dart';

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
  final _logger = Logger("ApiService");
  Future<List<Guild>?> getGuilds(GlobalState state) async {
    try {
      var response = await authFetch(HttpMethod.get, guildsEndpoint, state);
      if (response == null) {
        return null;
      }
      if (200 <= response.statusCode && response.statusCode < 300) {
        List<Guild> guilds = guildFromJson(response.body);
        return guilds;
      }
    } catch (e) {
      log(e.toString());
    }
    return null;
  }

  Future<bool> sendMessage(
      String gid, String cid, String message, GlobalState state) async {
    if (message.length > 2000) {
      message = message.substring(1, 2000);
    }
    message = message.trim();
    http.Response? resp = await authFetch(
        HttpMethod.post, sendMessageEndpoint(gid, cid), state,
        body: json.encode({"content": message}));
    return resp != null;
  }

  bool loggingIn = false;
  List<Completer> queue = [];
  Future<void> waitUntilLoggedIn() {
    var completer = Completer();
    queue.add(completer);
    return completer.future;
  }

  void completeLogin() {
    loggingIn = false;
    for (var c in queue) {
      c.complete();
    }
  }

  Future<http.Response?> authFetch(
      HttpMethod method, String endpoint, GlobalState state,
      {Map<String, String>? headers, String? body}) async {
    if (loggingIn == true) {
      await waitUntilLoggedIn();
    }
    ApiTokens? tokens = getTokens();
    if (tokens != null) {
      final hasAccessTokenExpired =
          tokens.accessTokenExpiry.isBefore(DateTime.now());
      final hasRefreshTokenExpired =
          tokens.refreshTokenExpiry.isBefore(DateTime.now());
      if (hasAccessTokenExpired) {
        if (hasRefreshTokenExpired) {
          _logger.info("Refresh token expired, requesting logout");
          logOut(state);
          completeLogin();
          return null;
        }
        loggingIn = true;
        _logger.info("Requesting reissue for $endpoint");
        var res = await http.post(Uri.parse(reissueEndpoint),
            headers: {"Content-Type": "application/json"},
            body: '{"refreshToken": "${tokens.refreshToken}"}');
        if (res.statusCode != 200) {
          _logger.info("Reissue failed, logging out");
          logOut(state);
          completeLogin();
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
        headers = {
          ...headers,
          "Content-Type": "application/json",
          "Authorization": "Bearer ${tokens.accessToken}"
        };
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
    completeLogin();
    return res;
  }

  Future<bool> tryObtainLocalUser(GlobalState state) async {
    if (Globals.localUser == null) {
      try {
        var res = await authFetch(HttpMethod.get, whoamiEndpoint, state);
        if (res != null && 200 <= res.statusCode && res.statusCode < 300) {
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
      completeLogin();
      return null;
    }
    var resObj = loginResponseFromJson(res.body);
    setTokens(ApiTokens(resObj.accessToken, tokenExpiry(resObj.accessToken),
        resObj.refreshToken, tokenExpiry(resObj.refreshToken)));
    completeLogin();
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
    try {
      var response =
          await authFetch(HttpMethod.get, channelsEndpoint(id), state);
      if (response == null) {
        return null;
      }
      if (200 <= response.statusCode && response.statusCode < 300) {
        List<Channel> channels = channelFromJson(response.body);
        return channels;
      }
    } catch (e) {
      log(e.toString());
    }
    return null;
  }

  Future<(List<Message>?, bool)> getMessages(
      String gid, String cid, int limit, GlobalState state,
      {DateTime? before}) async {
    if (limit > 50) {
      limit = 50;
    }
    try {
      var response = await authFetch(
          HttpMethod.get, messagesEndpoint(gid, cid, limit, before), state);
      if (response == null) {
        return (null, false);
      }
      if (200 <= response.statusCode && response.statusCode < 300) {
        List<Message> messages = messageFromJson(response.body);
        messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        messages = messages
            .map((e) => Message(
                author: e.author,
                content: e.content.trim(),
                createdAt: e.createdAt,
                id: e.id))
            .toList();
        if (response.statusCode == 206) {
          return (messages, true);
        }
        return (messages, false);
      }
    } catch (e) {
      log(e.toString());
    }
    return (null, false);
  }

  Future<bool> createGuild(String name, GlobalState state) async {
    var response = await authFetch(HttpMethod.post, guildsEndpoint, state,
        body: jsonEncode({"name": name}));
    if (response == null ||
        !(200 <= response.statusCode && response.statusCode < 300)) {
      return false;
    }
    var g = await state.resolveGuild(json.decode(response.body)["guild_id"]);
    if (g == null) return false;
    state.setGuild(g);
    return true;
  }

  Future<bool> joinGuild(String gid, GlobalState state) async {
    var response =
        await authFetch(HttpMethod.get, joinGuildEndpoint(gid), state);
    if (response == null ||
        !(200 <= response.statusCode && response.statusCode < 300)) {
      return false;
    }
    var g = await state.resolveGuild(gid);
    if (g == null) return false;
    state.setGuild(g);
    return true;
  }

  void sendTyping(GlobalState state) async {
    if (state.currentChannel == null || state.currentGuild == null) {
      return;
    }
    authFetch(
        HttpMethod.post,
        typingEndpoint(state.currentGuild!.id, state.currentChannel!.id),
        state);
  }

  Future<WebSocketChannel?> wsConnect(GlobalState state) async {
    if (loggingIn == true) {
      await waitUntilLoggedIn();
    }
    var tokens = getTokens();
    if (tokens == null) {
      logOut(state);
      completeLogin();
      return null;
    }
    final hasAccessTokenExpired =
        tokens.accessTokenExpiry.isBefore(DateTime.now());
    final hasRefreshTokenExpired =
        tokens.refreshTokenExpiry.isBefore(DateTime.now());
    if (hasAccessTokenExpired) {
      if (hasRefreshTokenExpired) {
        _logger.info("Refresh token expired, requesting logout");
        logOut(state);
        completeLogin();
        return null;
      }
      _logger.info("Requesting reissue from websocket connect");
      var res = await http.post(Uri.parse(reissueEndpoint),
          headers: {"Content-Type": "application/json"},
          body: '{"refreshToken": "${tokens.refreshToken}"}');
      if (res.statusCode != 200) {
        logOut(state);
        completeLogin();
        return null;
      }

      var json = jsonDecode(res.body);
      setTokens(ApiTokens(json["accessToken"], tokenExpiry(json["accessToken"]),
          json["refreshToken"], tokenExpiry(json["refreshToken"])));
      tokens = getTokens();
    }
    completeLogin();
    return WebSocketChannel.connect(Uri.parse(wsEndpoint(tokens!.accessToken)));
  }
}
