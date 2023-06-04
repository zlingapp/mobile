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
  // Attempt to obtain tokens from local memory
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
  // Write a set of tokens to local memory, or remove all if null is passed
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
  // Do the cursed big-endian datetime formatting. Don't ask me how it works
  final base64Url = token.split(".")[1];
  final base64 = const Base64Codec().normalize(base64Url);

  final binary = base64Decode(base64);

  var timestamp = 0;

  for (var i = 0; i < binary.length; i++) {
    timestamp = (timestamp << 8) | binary[i];
  }
  // Lol, there is no fromSeconds factory so we use this
  return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
}

// This is temporary as the current zling servers use self-signed certs
// Definitely todo remove this later, anyone can do a mitm attack
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
    // Strip message to 2000 characters if a longer string somehow gets passed
    // here (it shouldn't)
    if (message.length > 2000) {
      message = message.substring(1, 2000);
    }
    message = message.trim();
    http.Response? resp = await authFetch(
        HttpMethod.post, sendMessageEndpoint(gid, cid), state,
        body: json.encode({"content": message}));
    return resp != null;
  }

  // This is the solution to ensure multiple things don't attempt to reissue
  // tokens simultaneously. It involves adding a new completer to the list
  // every time and then waiting until the first reissue call fulfills them.
  bool loggingIn = false;
  List<Completer> queue = [];
  Future<void> waitUntilLoggedIn() {
    var completer = Completer();
    queue.add(completer);
    return completer.future;
  }

  // Complete all the completers so all the queued requests can proceed
  void completeLogin() {
    loggingIn = false;
    for (var c in queue) {
      c.complete();
    }
  }

  // http wrapper to provide our token authentication
  Future<http.Response?> authFetch(
      HttpMethod method, String endpoint, GlobalState state,
      {Map<String, String>? headers, String? body}) async {
    // Join the queue if someone else is requesting a reisue rn
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
          // Redirect us to the logged out state if any our refresh token is out
          _logger.info("Refresh token expired, requesting logout");
          logOut(state);
          completeLogin();
          return null;
        }
        // If only the access token is out, we can use the refresh token to get a new one
        loggingIn = true;
        _logger.info("Requesting reissue for $endpoint");
        var res = await http.post(Uri.parse(reissueEndpoint),
            headers: {"Content-Type": "application/json"},
            body: '{"refreshToken": "${tokens.refreshToken}"}');
        if (res.statusCode != 200) {
          // Reissue failed for some reason, take me to the login page
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
    // Proceed with actual request after making sure all the tokens are ok
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
    // Fulfill all those completers so the queue can get moving again
    completeLogin();
    return res;
  }

  // Check if we have a set of valid tokens stored.
  // If we do, then set the local user through whoami api, if we dont then back to login page we go
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

  // Do we have some good tokens? (tick y/n)
  Future<bool> ensureLoggedIn(GlobalState state) async {
    if (!(await tryObtainLocalUser(state))) {
      return false;
    }
    return true;
  }

  // Login using a email and password to get new tokens
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

  // Kill all our stored login state and take us to login screen
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
      _logger.warning(e.toString());
    }
    return null;
  }

  // Returns list of messages as well as a bool indicating if we have reached top of the channel.
  // If we haven't, then the user scrolling to the top triggers more messages to be loaded
  Future<(List<Message>?, bool)> getMessages(
      String gid, String cid, int limit, GlobalState state,
      {DateTime? before}) async {
    // Server limit is 50, so clamp the value incase something larger gets passed here (it also shouldn't)
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
        messages.sort((a, b) => a.createdAt.compareTo(b
            .createdAt)); // Sort by date incase the server doesnt do it for us (it does)
        messages = messages
            .map((e) => Message(
                author: e.author,
                content: e.content.trim(),
                createdAt: e.createdAt,
                id: e
                    .id)) // Trim the content lol, this is probably not necessary anymore as all clients should trim sent messages
            .toList();
        if (response.statusCode == 206) {
          // 206 -> there are still more messages above these
          return (messages, true);
        }
        // We have reached the top of the channel, no more above
        return (messages, false);
      }
    } catch (e) {
      _logger.warning(e.toString());
    }
    // Somethings gone wrong, so we probably have no channel selected or something
    return (null, false);
  }

  Future<bool> createGuild(String name, GlobalState state) async {
    var response = await authFetch(HttpMethod.post, guildsEndpoint, state,
        body: jsonEncode({"name": name}));
    if (response == null ||
        !(200 <= response.statusCode && response.statusCode < 300)) {
      return false;
    }
    // make sure we update the locally stored guilds and set the current selected guild to the newly created one
    var g = await state.resolveGuild(json.decode(response.body)["guild_id"]);
    if (g == null) return false;
    state.setGuild(g);
    return true;
  }

  Future<bool> createChannel(
      String name, String type, String gid, GlobalState state) async {
    var response = await authFetch(
        HttpMethod.post, channelsEndpoint(gid), state,
        body: jsonEncode({"name": name, "type": type}));
    if (response == null ||
        !(200 <= response.statusCode && response.statusCode < 300)) {
      return false;
    }
    return true;
  }

  Future<bool> joinGuild(String gid, GlobalState state) async {
    var response =
        await authFetch(HttpMethod.get, joinGuildEndpoint(gid), state);
    if (response == null ||
        !(200 <= response.statusCode && response.statusCode < 300)) {
      return false;
    }
    // Again, update stored guilds and set selected one to newly joined one
    var g = await state.resolveGuild(gid);
    if (g == null) return false;
    state.setGuild(g);
    return true;
  }

  void sendTyping(GlobalState state) async {
    // Send a typing indicator to the server.
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
      // Wait till we have valid tokens to do it
      await waitUntilLoggedIn();
    }
    // Otherwise, we have to reissue ourselves since this function cant use authFetch
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
      loggingIn = true;
      _logger.info("Requesting reissue from websocket connect");
      // Here is why we can't use authFetch -- ws endpoint uses query parameters for tokens
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
    // If we had to reissue here, then we dont need to reissue anywhere else
    completeLogin();
    return WebSocketChannel.connect(Uri.parse(wsEndpoint(tokens!.accessToken)));
  }
}
