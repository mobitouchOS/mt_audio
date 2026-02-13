import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mt_audio/src/models/mt_queue_state.dart';
import 'package:mt_audio/src/player/mt_audio_player.dart';

/// Direction for track skip button.
enum MtTrackSkipDirection {
  /// Skip to previous track.
  previous,

  /// Skip to next track.
  next,
}

/// A button for skipping to the previous or next track in the queue.
///
/// Automatically disables itself when there is no previous/next track
/// available. Listens to queue state changes to update its enabled state.
class MtTrackSkipButton extends StatelessWidget {
  /// Creates an [MtTrackSkipButton].
  const MtTrackSkipButton({
    required this.player,
    required this.direction,
    this.size = 48.0,
    this.iconSize,
    this.color,
    this.disabledColor,
    super.key,
  });

  /// The audio player instance.
  final MtAudioPlayer player;

  /// Direction to skip (previous or next).
  final MtTrackSkipDirection direction;

  /// Size of the button.
  final double size;

  /// Size of the icon. Defaults to size * 0.6.
  final double? iconSize;

  /// Color of the icon when enabled.
  final Color? color;

  /// Color of the icon when disabled.
  final Color? disabledColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.iconTheme.color;
    final effectiveDisabledColor = disabledColor ?? theme.disabledColor;
    final effectiveIconSize = iconSize ?? size * 0.6;

    final isNext = direction == MtTrackSkipDirection.next;
    final icon = isNext ? Icons.skip_next : Icons.skip_previous;

    return StreamBuilder<MtQueueState>(
      stream: player.queueStateStream,
      builder: (context, snapshot) {
        final queueState = snapshot.data ?? player.currentQueueState;
        final canSkip = isNext ? queueState.hasNext : queueState.hasPrevious;

        return IconButton(
          iconSize: effectiveIconSize,
          color: canSkip ? iconColor : effectiveDisabledColor,
          disabledColor: effectiveDisabledColor,
          icon: Icon(icon),
          onPressed: canSkip
              ? () {
                  if (isNext) {
                    unawaited(player.skipToNext());
                  } else {
                    unawaited(player.skipToPrevious());
                  }
                }
              : null,
        );
      },
    );
  }
}
