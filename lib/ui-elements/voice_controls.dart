import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:logging/logging.dart";
import "package:zling/global_state.dart";
import "package:provider/provider.dart";
import "package:zling/lib/voice.dart";
import "package:zling/ui-elements/voice_channel_members.dart";

final _logger = Logger("voiceControls");

class VoiceControls extends StatefulWidget {
  const VoiceControls({super.key});

  @override
  State<VoiceControls> createState() => _VoiceControlsState();
}

class _VoiceControlsState extends State<VoiceControls> {
  int latency = 0;
  Timer? latencyTimer;

  Future<void> updateLatency(Timer t) async {
    if (producer == null || producer!.closed) return;
    List<StatsReport> stats;
    try {
      stats = await producer!.getStats();
    } catch (e) {
      _logger.warning("Stats get failed - $e");
      return;
    }
    for (StatsReport r in stats) {
      if (r.type == "remote-inbound-rtp") {
        if (r.values.containsKey("roundTripTime")) {
          setState(() {
            latency = (r.values["roundTripTime"] * 1000).round();
          });
        }
      }
    }
  }

  @override
  void initState() {
    latencyTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      updateLatency(timer);
    });
    super.initState();
  }

  @override
  void dispose() {
    latencyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    GlobalState appstate = context.watch<GlobalState>();
    final theme = Theme.of(context);
    Widget text;
    Color? latencyColor;
    IconData? icon;
    if (latency < 75) {
      latencyColor = Colors.green;
      icon = Icons.signal_cellular_alt;
    }
    if (75 <= latency && latency < 125) {
      latencyColor = Colors.orange;
      icon = Icons.signal_cellular_alt_2_bar;
    }
    if (125 <= latency) {
      latencyColor = Colors.red;
      icon = Icons.signal_cellular_alt_1_bar;
    }
    var textStyle = theme.textTheme.bodyMedium!
        .copyWith(color: theme.colorScheme.onSurfaceVariant);
    var progressStyle =
        theme.textTheme.bodyMedium!.copyWith(color: Colors.orange);
    var redStyle = theme.textTheme.bodyMedium!.copyWith(color: Colors.red);
    switch (appstate.voiceState) {
      case VoiceState.permissionRequest:
        text = Text("Requesting audio permission", style: progressStyle);
        break;
      case VoiceState.gettingIdentity:
        text = Text("Getting RTC identity", style: progressStyle);
        break;
      case VoiceState.connecting:
        text = Text("Connecting to ${appstate.voiceChannelCurrent!.name}...",
            style: textStyle);
        break;
      case VoiceState.connected:
        text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isPeerDuplicate(
                        appstate.voicePeers.values.firstWhere((e) => e.isMe),
                        appstate.voicePeers) &&
                    identity != null
                ? Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Text("Connected",
                            style: textStyle.copyWith(
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Container(
                          decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              borderRadius: BorderRadius.circular(6)),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Text(identity!.substring(0, 3),
                                style: textStyle.copyWith(
                                    color: theme.colorScheme.onSecondary)),
                          ))
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Text("Connected",
                        style: textStyle.copyWith(fontWeight: FontWeight.bold)),
                  ),
            Text(
                "${appstate.voiceChannelCurrent!.name} - ${appstate.voiceChannelCurrent!.guildName}",
                style: textStyle.copyWith(color: Colors.grey))
          ],
        );
        break;
      case VoiceState.disconnecting:
        text = Text("Disconnecting...", style: redStyle);
        break;
      case VoiceState.disconected:
        text = Text("...", style: redStyle);
        break;
    }
    return Container(
      decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          border: const Border(top: BorderSide(color: Colors.grey))),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Column(
            children: [
              Icon(icon ?? Icons.signal_wifi_0_bar,
                  color: latencyColor ?? Colors.green),
              Text("${latency.toString()}ms",
                  style: theme.textTheme.labelMedium!
                      .copyWith(color: latencyColor))
            ],
          ),
          const SizedBox(width: 3),
          text,
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.call_end_rounded),
            onPressed: () {
              disconnect(appstate);
            },
          )
        ]),
      ),
    );
  }
}
