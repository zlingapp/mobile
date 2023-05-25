import 'package:flutter/material.dart';
import 'package:mediasoup_client_flutter/mediasoup_client_flutter.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'api.dart';
import 'package:logging/logging.dart';

final _logger = Logger("voicemanager");

enum VoiceState {
  permission_request,
  getting_identity,
  connecting,
  connected,
  disconnecting,
  disconected
}

class Peer {
  String identity;
  Map<String, Consumer> consumers;
  bool isMe;
  Producer producer;

  Peer(
      {required this.identity,
      required this.consumers,
      required this.isMe,
      required this.producer});
}

class VoiceChannelInfo {
  String guildName;
  String name;
  String id;

  VoiceChannelInfo(
      {required this.guildName, required this.name, required this.id});
}

class VoiceChannelTarget {
  final VoiceChannelInfo? value;
  bool get hasValue => true;
  VoiceChannelTarget(this.value);
  factory VoiceChannelTarget.none() => const _VoiceChannelTargetNone();
}

class _VoiceChannelTargetNone implements VoiceChannelTarget {
  const _VoiceChannelTargetNone();

  @override
  bool get hasValue => false;

  @override
  VoiceChannelInfo? get value => throw UnsupportedError("Target has no value");
}

var voiceChannnelTarget =
    ValueNotifier<VoiceChannelTarget>(VoiceChannelTarget.none());

void disconnectFromVoice() {
  voiceChannnelTarget.value = VoiceChannelTarget(null);
}
