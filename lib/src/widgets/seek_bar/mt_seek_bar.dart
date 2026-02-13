import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mt_audio/src/player/mt_audio_player.dart';

/// A seek bar widget with buffered progress indicator.
///
/// Displays a slider showing the current playback position, buffered position,
/// and total duration. Includes optional position/duration labels.
class MtSeekBar extends StatefulWidget {
  /// Creates an [MtSeekBar].
  const MtSeekBar({
    required this.player,
    this.showLabels = true,
    super.key,
  });

  /// The audio player instance.
  final MtAudioPlayer player;

  /// Show labels for position and duration.
  final bool showLabels;

  @override
  State<MtSeekBar> createState() => _MtSeekBarState();
}

class _MtSeekBarState extends State<MtSeekBar> {
  bool _isDragging = false;
  double _dragValue = 0;

  MtAudioPlayer get player => widget.player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: player.positionStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data ?? player.currentPositionState;
        final duration = state.duration ?? Duration.zero;
        final position = state.position;
        final bufferedPosition = state.bufferedPosition;

        final positionPercent = duration == Duration.zero
            ? 0.0
            : (position.inMilliseconds / duration.inMilliseconds).clamp(
                0.0,
                1.0,
              );
        final bufferingPercent = duration == Duration.zero
            ? 0.0
            : (bufferedPosition.inMilliseconds / duration.inMilliseconds).clamp(
                0.0,
                1.0,
              );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: _isDragging ? _dragValue : positionPercent,
              secondaryTrackValue: bufferingPercent,
              onChangeStart: duration == Duration.zero
                  ? null
                  : (value) {
                      setState(() {
                        _isDragging = true;
                        _dragValue = value;
                      });
                    },
              onChanged: duration == Duration.zero
                  ? null
                  : (value) {
                      setState(() {
                        _dragValue = value;
                      });
                    },
              onChangeEnd: duration == Duration.zero
                  ? null
                  : (value) {
                      final newPosition = Duration(
                        milliseconds: (value * duration.inMilliseconds).round(),
                      );
                      unawaited(player.seekTo(newPosition));
                      setState(() {
                        _isDragging = false;
                      });
                    },
            ),

            if (widget.showLabels)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(
                        _isDragging
                            ? Duration(
                                milliseconds:
                                    (_dragValue * duration.inMilliseconds)
                                        .round(),
                              )
                            : position,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      _formatDuration(duration),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
