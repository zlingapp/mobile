import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:zling/global_state.dart';
import 'package:mediasoup_client_flutter/mediasoup_client_flutter.dart';
import 'package:zling/lib/voice.dart';
import 'dart:async';

final _logger = Logger("VoiceChannelMembers");

bool isPeerDuplicate(Peer entry, Map<String, Peer> map) {
  return map.values.where((e) => e.user.id == entry.user.id).length > 1;
}

List<Widget> voiceChannelMembers(GlobalState state) {
  return state.voicePeers.entries
      .map((e) => VoiceChannelMember(
          e.key, e.value, isPeerDuplicate(e.value, state.voicePeers)))
      .toList();
}

Future<bool> isTalking(Peer peer) async {
  try {
    if (recvTransport == null) return false;
    if (peer.isMe) return false;
    for (Consumer consumer in peer.consumers.values) {
      final res =
          await recvTransport!.handler.getReceiverStats(consumer.localId);
      String category = "track";
      if (res.where((e) => e.type == "track").isEmpty) category = "inbound-rtp";
      final stats = (res.where((e) => e.type == category));
      if (stats.isNotEmpty) {
        if (stats.last.values["audioLevel"] > 0.05) return true;
      }
    }
    return false;
  } catch (e) {
    _logger.warning("Error in voice activity - $e");
    return false;
  }
}

const double talkingBorderRadius = 2;

class VoiceChannelMember extends StatefulWidget {
  final String identifier;
  final Peer peer;
  final bool isDuplicate;
  const VoiceChannelMember(this.identifier, this.peer, this.isDuplicate,
      {super.key});

  @override
  State<VoiceChannelMember> createState() => _VoiceChannelMemberState();
}

class _VoiceChannelMemberState extends State<VoiceChannelMember> {
  Timer? timer;
  bool talking = false;
  @override
  void initState() {
    timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      bool res = await isTalking(widget.peer);
      if (res != talking) {
        setState(() {
          talking = res;
        });
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double talkingBorderRadius = talking ? 2 : 0;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
          left: 24 - talkingBorderRadius,
          top: 6 - talkingBorderRadius,
          bottom: 6 - talkingBorderRadius,
          right: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(48),
                border:
                    Border.all(color: Colors.green, width: talkingBorderRadius),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(48), // Image border
                child: SizedBox.fromSize(
                  size: const Size.fromRadius(12), // Image radius
                  child: Image.network(
                      // Change this

                      "https://upload.wikimedia.org/wikipedia/commons/7/7c/Profile_avatar_placeholder_large.png",
                      fit: BoxFit.cover),
                ),
              )),
          SizedBox(width: 8 - talkingBorderRadius),
          Text(widget.peer.user.name),
          const Spacer(),
          if (widget.isDuplicate && identity != null)
            Container(
                decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    borderRadius: BorderRadius.circular(6)),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Text(widget.peer.identity.substring(0, 3),
                      style: theme.textTheme.bodyMedium!
                          .copyWith(color: theme.colorScheme.onSecondary)),
                ))
        ],
      ),
    );
  }
}
