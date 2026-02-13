import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mt_audio/src/models/mt_playback_state.dart';
import 'package:mt_audio/src/player/mt_audio_player.dart';

/// An animated play/pause button with loading state support.
///
/// Automatically updates based on playback state and shows a loading
/// indicator when buffering.
class MtPlayPauseButton extends StatelessWidget {
  /// Creates an [MtPlayPauseButton].
  const MtPlayPauseButton({
    required this.player,
    this.size = 48.0,
    this.iconSize,
    this.color,
    this.playIcon = Icons.play_arrow,
    this.pauseIcon = Icons.pause,
    super.key,
  });

  /// The audio player instance.
  final MtAudioPlayer player;

  /// Size of the button (box side).
  final double size;

  /// Size of the icon. Defaults to size * 0.6.
  final double? iconSize;

  /// Color of the icon and loading indicator.
  final Color? color;

  /// Icon to show when paused.
  final IconData playIcon;

  /// Icon to show when playing.
  final IconData pauseIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.colorScheme.primary;
    final effectiveIconSize = iconSize ?? size * 0.6;

    return StreamBuilder<MtPlaybackState>(
      stream: player.playbackStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data ?? player.currentPlaybackState;
        final isLoading = state.isLoading;
        final isPlaying = state.isPlaying;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Loading indicator
              if (isLoading)
                SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                  ),
                ),
              // Play/pause icon button
              IconButton(
                iconSize: effectiveIconSize,
                color: iconColor,
                icon: Icon(isPlaying ? pauseIcon : playIcon),
                onPressed: isLoading
                    ? null
                    : () {
                        if (isPlaying) {
                          unawaited(player.pause());
                        } else {
                          unawaited(player.play());
                        }
                      },
              ),
            ],
          ),
        );
      },
    );
  }
}
