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

  @override
  bool operator ==(Object other) {
    return other is Guild && other.id == id;
  }

  @override
  int get hashCode => Object.hash(id, "");

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
  @override
  bool operator ==(Object other) {
    return other is Channel && other.id == id;
  }

  @override
  int get hashCode => Object.hash(id, "");

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

  @override
  bool operator ==(Object other) {
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => Object.hash(id, "");

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        author: Author.fromJson(json["author"]),
        content: json["content"],
        createdAt: DateTime.parse(json["created_at"] + "Z"),
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
  late String discriminant;
  late String name;
  // String get discriminant => username.split("#")[1];
  // String

  Author({
    required this.avatar,
    required this.id,
    this.nickname,
    required this.username,
  }) {
    discriminant = username.split("#")[1];
    name = username.split("#")[0];
  }

  @override
  bool operator ==(Object other) {
    return other is Author && other.id == id;
  }

  @override
  int get hashCode => Object.hash(id, "");

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

  @override
  bool operator ==(Object other) {
    return other is User && other.id == id;
  }

  @override
  int get hashCode => Object.hash(id, "");

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

EventResponse eventResponseFromJson(String str) =>
    EventResponse.fromJson(json.decode(str));

String eventResponseToJson(EventResponse data) => json.encode(data.toJson());

class EventResponse {
  Event event;
  Topic topic;

  EventResponse({
    required this.event,
    required this.topic,
  });

  factory EventResponse.fromJson(Map<String, dynamic> json) => EventResponse(
        event: Event.fromJson(json["event"]),
        topic: Topic.fromJson(json["topic"]),
      );

  Map<String, dynamic> toJson() => {
        "event": event.toJson(),
        "topic": topic.toJson(),
      };
}

class Event {
  Author author;
  String content;
  DateTime createdAt;
  String id;
  String type;

  Event({
    required this.author,
    required this.content,
    required this.createdAt,
    required this.id,
    required this.type,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        author: Author.fromJson(json["author"]),
        content: json["content"],
        createdAt: DateTime.parse(json["created_at"] + "Z"),
        id: json["id"],
        type: json["type"],
      );

  Map<String, dynamic> toJson() => {
        "author": author.toJson(),
        "content": content,
        "created_at": createdAt.toIso8601String(),
        "id": id,
        "type": type,
      };
}

class Topic {
  String id;
  String type;

  Topic({
    required this.id,
    required this.type,
  });

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
        id: json["id"],
        type: json["type"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "type": type,
      };
}
