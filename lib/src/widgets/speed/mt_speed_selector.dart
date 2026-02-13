import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mt_audio/src/player/mt_audio_player.dart';

/// A widget for selecting playback speed.
///
/// Displays preset speed options (0.5x, 1x, 1.5x, 2x) that the user can select.
class MtSpeedSelector extends StatelessWidget {
  /// Creates an [MtSpeedSelector].
  const MtSpeedSelector({
    required this.player,
    this.speeds = const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
    super.key,
  }) : assert(speeds.length > 0, 'speeds must not be empty');

  /// The audio player instance.
  final MtAudioPlayer player;

  /// Available speed options.
  final List<double> speeds;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.playbackStateStream.map((state) => state.speed),
      builder: (context, snapshot) {
        final currentSpeed = snapshot.data ?? player.currentPlaybackState.speed;
        final selectedSpeed = speeds.contains(currentSpeed)
            ? currentSpeed
            : speeds.first;

        return SegmentedButton<double>(
          segments: speeds.map((speed) {
            return ButtonSegment<double>(
              value: speed,
              label: Text('$speed'),
            );
          }).toList(),
          selected: {selectedSpeed},
          showSelectedIcon: false,
          onSelectionChanged: (selected) {
            if (selected.isNotEmpty) {
              unawaited(player.setSpeed(selected.first));
            }
          },
        );
      },
    );
  }
}
