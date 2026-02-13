import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mt_audio/src/player/mt_audio_player.dart';

/// Direction for skip button.
enum MtSkipDirection {
  /// Skip forward.
  forward,

  /// Skip backward.
  backward,
}

/// A button for skipping forward or backward by a configured interval.
///
/// Displays a 'skip 10' icon by default.
class MtSkipButton extends StatelessWidget {
  /// Creates an [MtSkipButton].
  const MtSkipButton({
    required this.player,
    required this.direction,
    this.size = 40.0,
    this.iconSize,
    this.color,
    this.icon,
    super.key,
  });

  /// The audio player instance.
  final MtAudioPlayer player;

  /// Direction to skip (forward or backward).
  final MtSkipDirection direction;

  /// Size of the button.
  final double size;

  /// Size of the icon. Defaults to size * 0.6.
  final double? iconSize;

  /// Color of the icon and text.
  final Color? color;

  /// Overrides the icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.iconTheme.color;
    final effectiveIconSize = iconSize ?? size * 0.6;

    final isForward = direction == MtSkipDirection.forward;
    final effectiveIcon =
        icon ?? (isForward ? Icons.forward_10 : Icons.replay_10);

    return IconButton(
      iconSize: effectiveIconSize,
      color: iconColor,
      icon: Icon(effectiveIcon),
      onPressed: () {
        if (isForward) {
          unawaited(player.seekForward());
        } else {
          unawaited(player.seekBackward());
        }
      },
    );
  }
}
