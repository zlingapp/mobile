import 'dart:async';
import 'dart:convert';

import 'package:mediasoup_client_flutter/mediasoup_client_flutter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:zling/globals.dart';
import 'api.dart';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../global_state.dart';
import 'dart:io';
import 'package:zling/lib/models.dart';

final _logger = Logger("voicemanager");

enum VoiceState {
  permissionRequest,
  gettingIdentity,
  connecting,
  connected,
  disconnecting,
  disconected
}

class Peer {
  String identity;
  User user;
  Map<String, Consumer> consumers;
  bool isMe;
  Producer? producer;

  Peer(
      {required this.identity,
      required this.consumers,
      required this.user,
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

void disconnectFromVoice(GlobalState state) {
  state.voiceChannelTarget.value = VoiceChannelTarget(null);
}

void onTargetChange(GlobalState state) async {
  VoiceChannelTarget target = state.voiceChannelTarget.value;
  if (target.hasValue == false) return;
  if (state.voiceState != VoiceState.disconected) {
    await disconnect(state);
  }

  if (target.value == null) {
    currentChannel = null;
    return;
  }

  currentChannel = target.value!;
  state.set(() {
    state.voiceChannelTarget.value = VoiceChannelTarget.none();
    state.voiceChannelCurrent = target.value!;
  });
  await join(target.value!.id, state);
}

Device? device;
String? identity;
String? token;
WebSocketChannel? socket;
Timer? heartbeat;
Transport? sendTransport;
Producer? producer;
Transport? recvTransport;
VoiceChannelInfo? currentChannel;
StreamSubscription? onClose;

Completer mrConsumeComplete = Completer();
Consumer? mrConsumer;

Future<dynamic> voiceAuthFetch(
    String? identity, String? token, String endpoint, GlobalState state,
    {HttpMethod method = HttpMethod.get, String body = ""}) async {
  if (identity == null || token == null) return null;
  final response = await ApiService().authFetch(method, endpoint, state,
      headers: {"RTC-Identity": identity, "RTC-Token": token}, body: body);
  if (response == null) return null;
  try {
    return jsonDecode(response.body);
  } catch (e) {
    return response.body;
  }
}

Future<void> reset(GlobalState state) async {
  identity = null;
  token = null;
  state.set(() => state.voiceState = VoiceState.disconnecting);
  if (heartbeat != null) {
    heartbeat?.cancel();
    heartbeat = null;
  }
  if (socket != null) {
    onClose?.cancel();
    socket!.sink.close();
    socket = null;
  }
  if (sendTransport != null && !sendTransport!.closed) {
    await sendTransport!.close();
    sendTransport = null;
  }
  if (producer != null && !producer!.closed) {
    producer!.close();
    producer = null;
  }
  if (recvTransport != null && !recvTransport!.closed) {
    await recvTransport!.close();
    recvTransport = null;
  }
  state.voicePeers.keys.map(
    (e) => removePeer(e, state),
  );
  // for (String identity in state.voicePeers.keys) {
  //   removePeer(identity, state);
  // }
  state.voicePeers = {};
  state.set(() => state.voiceState = VoiceState.disconected);
  state.set(() => state.voiceChannelCurrent = null);
  device = null;
}

Future<bool> removePeer(String identity, GlobalState state) async {
  var peer = state.voicePeers.containsKey(identity)
      ? state.voicePeers[identity]
      : null;
  if (peer == null) return false;
  for (Consumer c in peer.consumers.values) {
    await c.close();
  }
  state.set(() => state.voicePeers.remove(identity));
  return true;
}

Future<bool> addPeer(String identity, User user, GlobalState state,
    {bool? isMe, Producer? producer}) async {
  if (state.voicePeers.containsKey(identity)) return false;
  state.set(() => state.voicePeers[identity] = Peer(
      user: user,
      identity: identity,
      isMe: isMe == true,
      consumers: {},
      producer: producer));
  return true;
}

Future<void> startConnection(
    RtpCapabilities capabilities, GlobalState state) async {
  state.set(() => state.voiceState = VoiceState.permissionRequest);
  MediaStream localStream;
  try {
    localStream = await navigator.mediaDevices
        .getUserMedia({"audio": true, "video": false});
  } catch (e) {
    _logger.warning("Permission to access audio device denied, disconnecting");
    await reset(state);
    return;
  }
  final audioTrack = localStream.getAudioTracks().first;
  state.set(() => state.voiceState = VoiceState.connecting);
  device = Device();
  await device!.load(routerRtpCapabilities: capabilities);

  await initialiseSendTransport(state);
  await initialiseRecvTransport(state);

  sendTransport!
      .produce(stream: localStream, track: audioTrack, source: "webcam");
  await addPeer(identity!, Globals.localUser!, state,
      producer: producer, isMe: true);

  List<dynamic> alreadyInVc =
      await voiceAuthFetch(identity, token, voicePeersEndpoint, state);
  for (dynamic peer in alreadyInVc) {
    await addPeer(peer["identity"], User.fromVoiceJson(peer["user"]), state);
    for (dynamic producerId in peer["producers"]) {
      await consume(peer["identity"], producerId, state);
    }
  }
}

Future<void> join(String cid, GlobalState state) async {
  if (state.voiceState != VoiceState.disconected) return;
  try {
    state.set(() => state.voiceState = VoiceState.gettingIdentity);
    final resp = await ApiService()
        .authFetch(HttpMethod.get, joinVoiceEndpoint(cid), state);
    final data = jsonDecode(resp!.body);
    identity = data["identity"];
    token = data["token"];

    socket = WebSocketChannel.connect(
        Uri.parse(voiceSocketEndpoint(identity, token)));
    socket!.stream.listen((event) async {
      var data = jsonDecode(event);
      onServerEvent(data, state);
    }, onDone: () async {
      if (state.voiceState != VoiceState.disconected &&
          state.voiceState != VoiceState.disconnecting) {
        await disconnect(state);
      }
    });
    await startConnection(RtpCapabilities.fromMap(data["rtp"]), state);
    heartbeat = Timer.periodic(const Duration(seconds: 4), (timer) {
      socket?.sink.add("heartbeat");
    });
  } catch (e) {
    _logger.warning("Error getting voice identity - $e");
    await reset(state);
  }
}

Future<void> disconnect(GlobalState state) async {
  if (identity == null || token == null) return;
  state.set(() => state.voiceState = VoiceState.disconnecting);
  try {
    await voiceAuthFetch(identity, token, voiceLeaveEndpoint, state);
  } catch (e) {
    _logger.warning("Graceful voice disconnect failed");
  }
  await reset(state);
}

Future<void> initialiseSendTransport(GlobalState state) async {
  if (device == null) return;
  sendTransport = device!.createSendTransportFromMap(
      (await voiceAuthFetch(
          identity, token, voiceSendTransportCreateEndpoint, state,
          method: HttpMethod.post))!, producerCallback: (Producer p) {
    state.set(() => state.voiceState = VoiceState.connected);
    producer = p;
  });
  _logger.info("Send transport id: ${sendTransport?.id}");

  sendTransport!.on("connect", (Map data) async {
    try {
      voiceAuthFetch(identity, token, voiceSendTransportConnectEndpoint, state,
              method: HttpMethod.post,
              body: json
                  .encode({"dtlsParameters": data["dtlsParameters"].toMap()}))
          .then(data["callback"]);
    } catch (e) {
      _logger.warning("Send transport connection failed - ${e.toString()}");
      data["errback"]();
    }
  });
  sendTransport!.on("connectionstatechange", (Map data) async {
    _logger.info("SEND TRANSPORT Connection state change to ${data['state']}");
    switch (data["state"]) {
      case "connecting":
        break;
      case "connected":
        state.set(() => state.voiceState = VoiceState.connected);
        break;
      case "failed":
        await reset(state);
        break;
      case "disconnected":
        break;
      case "closed":
        _logger.info("Send transport closed");
        await reset(state);
        break;
    }
  });
  sendTransport!.on("produce", (Map data) async {
    try {
      _logger.info("Requesting producer...");
      final resp = await voiceAuthFetch(
          identity, token, voiceProduceEndpoint, state,
          method: HttpMethod.post,
          body: jsonEncode({
            "kind": data["kind"],
            "rtpParameters": data["rtpParameters"].toMap()
          }));
      if (resp == null) {
        throw const HttpException("Produde endpoint returned null");
      }
      _logger.info("Producer id: ${resp['id']}");
      data["callback"](resp["id"]);
    } catch (e) {
      _logger.warning(e.toString());
      data["errback"](e);
    }
  });
}

Future<void> initialiseRecvTransport(GlobalState state) async {
  try {
    recvTransport = device!.createRecvTransportFromMap(
        (await voiceAuthFetch(
            identity, token, voiceRecvTransportCreateEndpoint, state,
            method: HttpMethod.post))!,
        consumerCallback: (Consumer c, [dynamic accept]) {
      mrConsumer = c;
      mrConsumeComplete.complete();
    });
    if (recvTransport == null) {
      throw const HttpException("Endpoint returned null");
    }
  } catch (e) {
    _logger.shout("Critical error creating recv transport: $e");
    return;
  }
  _logger.info("Recv transport: ${recvTransport?.id}");
  recvTransport!.on("connect", (Map data) async {
    try {
      await voiceAuthFetch(
          identity, token, voiceRecvTransportConnectEndpoint, state,
          method: HttpMethod.post,
          body: jsonEncode({"dtlsParameters": data["dtlsParameters"].toMap()}));
      data["callback"]();
    } catch (e) {
      _logger.warning(e);
      data["errback"](e);
    }
  });
  recvTransport!.on("connectionstatechange", (Map data) async {
    _logger.info("RECV TRANSPORT Connection state change to ${data['state']}");
    switch (data["state"]) {
      case "connecting":
        break;
      case "connected":
        state.set(() => state.voiceState = VoiceState.connected);
        break;
      case "failed":
        await reset(state);
        break;
      case "disconnected":
        break;
      case "closed":
        _logger.info("Recv transport closed");
        await reset(state);
        break;
    }
  });
}

Future<void> consume(
    String peerIdentity, String producerId, GlobalState state) async {
  if (!state.voicePeers.containsKey(peerIdentity)) {
    _logger.info("Not in peers");
    return;
  }
  if (identity == null || recvTransport == null || device == null) {
    _logger.info("something is null");
    return;
  }
  var peer = state.voicePeers[peerIdentity];
  var caps = device!.rtpCapabilities;
  var data = await voiceAuthFetch(
      identity,
      token,
      voiceConsumeEndpoint,
      method: HttpMethod.post,
      body: jsonEncode({
        "producerId": producerId,
        "rtpCapabilities": {...caps.toMap(), "headerExtensions": []}
      }),
      state);

  if (data == null) return;
  recvTransport!.consume(
    id: data["id"],
    producerId: data["producerId"],
    peerId: peerIdentity,
    kind: RTCRtpMediaTypeExtension.fromString(data["kind"]),
    rtpParameters: RtpParameters.fromMap(data["rtpParameters"]),
  );
  if (peer!.consumers.containsKey(peerIdentity)) {
    _logger.warning("Already have consumer for $peerIdentity");
  }
  await mrConsumeComplete.future;
  if (mrConsumer == null) return;

  peer.consumers[mrConsumer!.id] = mrConsumer!;

  mrConsumeComplete = Completer();
}

Future<void> onServerEvent(
    Map<dynamic, dynamic> data, GlobalState state) async {
  switch (data["type"]) {
    case "client_connected":
      if (data["identity"] == identity) {
        _logger.warning("Received client_connecting for self, ignoring...");
        return;
      }
      await addPeer(data["identity"], User.fromVoiceJson(data["user"]), state);
      break;
    case "client_disconnected":
      if (data["identity"] == identity) {
        _logger.info("Received client_disconnect for self, ignoring...");
        return;
      }
      await removePeer(data["identity"], state);
      break;
    case "new_producer":
      _logger.info("New producer, starting consume...");
      await consume(data["identity"], data["producer_id"], state);
      break;
  }
}
