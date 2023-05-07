import 'dart:convert';

// Converts JSON responses to objects

List<Guild> guildFromJson(String str) =>
    List<Guild>.from(json.decode(str).map((x) => Guild.fromJson(x)));

String guildToJson(List<Guild> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class Guild {
  String id;
  String name;

  Guild({
    required this.id,
    required this.name,
  });

  factory Guild.fromJson(Map<String, dynamic> json) => Guild(
        id: json["id"],
        name: json["name"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
      };
}

List<Channel> channelFromJson(String str) =>
    List<Channel>.from(json.decode(str).map((x) => Channel.fromJson(x)));

String channelToJson(List<Channel> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class Channel {
  String id;
  String name;
  String type;

  Channel({
    required this.id,
    required this.name,
    required this.type,
  });

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: json["id"],
        name: json["name"],
        type: json["type"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "type": type,
      };
}

List<Message> messageFromJson(String str) =>
    List<Message>.from(json.decode(str).map((x) => Message.fromJson(x)));

String messageToJson(List<Message> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class Message {
  Author author;
  String content;
  DateTime createdAt;
  String id;

  Message({
    required this.author,
    required this.content,
    required this.createdAt,
    required this.id,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        author: Author.fromJson(json["author"]),
        content: json["content"],
        createdAt: DateTime.parse(json["created_at"]),
        id: json["id"],
      );

  Map<String, dynamic> toJson() => {
        "author": author.toJson(),
        "content": content,
        "created_at": createdAt.toIso8601String(),
        "id": id,
      };
}

class Author {
  String avatar;
  String id;
  String? nickname;
  String username;

  Author({
    required this.avatar,
    required this.id,
    this.nickname,
    required this.username,
  });

  factory Author.fromJson(Map<String, dynamic> json) => Author(
        avatar: json["avatar"],
        id: json["id"],
        nickname: json["nickname"],
        username: json["username"],
      );

  Map<String, dynamic> toJson() => {
        "avatar": avatar,
        "id": id,
        "nickname": nickname,
        "username": username,
      };
}

User userFromJson(String str) => User.fromJson(json.decode(str));

String userToJson(User data) => json.encode(data.toJson());

class User {
  String id;
  String name;
  String avatar;
  String email;

  User({
    required this.id,
    required this.name,
    required this.avatar,
    required this.email,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json["id"],
        name: json["name"],
        avatar: json["avatar"],
        email: json["email"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "avatar": avatar,
        "email": email,
      };
}

LoginResponse loginResponseFromJson(String str) =>
    LoginResponse.fromJson(json.decode(str));

String loginResponseToJson(LoginResponse data) => json.encode(data.toJson());

class LoginResponse {
  String accessToken;
  String refreshToken;
  User user;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        accessToken: json["accessToken"],
        refreshToken: json["refreshToken"],
        user: User.fromJson(json["user"]),
      );

  Map<String, dynamic> toJson() => {
        "accessToken": accessToken,
        "refreshToken": refreshToken,
        "user": user.toJson(),
      };
}
