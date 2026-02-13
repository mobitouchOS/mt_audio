import 'package:flutter/material.dart';
import 'package:mt_audio/mt_audio.dart';
import 'package:mt_audio_example/providers/player_provider.dart';

/// Persistent mini player shown above bottom navigation.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerProvider.of(context);
    final theme = Theme.of(context);

    return MtPlayerBuilder(
      player: player,
      builder: (context, state) {
        final item = state.currentItem;
        if (item == null) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: state.progress,
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
              // Mini player content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    // Artwork
                    MtArtwork(
                      artworkUri: item.artworkUri,
                      size: 48,
                      borderRadius: 4,
                    ),
                    const SizedBox(width: 12),
                    // Title and artist
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.artist != null)
                            Text(
                              item.artist!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Controls
                    // Previous track button
                    MtTrackSkipButton(
                      player: player,
                      direction: MtTrackSkipDirection.previous,
                      size: 40,
                      iconSize: 24,
                    ),
                    if (!item.isLive) ...[
                      IconButton(
                        icon: const Icon(Icons.replay_10),
                        iconSize: 24,
                        onPressed: player.seekBackward,
                      ),
                    ],
                    // Play/Pause button
                    _MiniPlayPauseButton(
                      isPlaying: state.isPlaying,
                      isLoading: state.isLoading,
                      onPressed: state.isPlaying ? player.pause : player.play,
                    ),
                    if (!item.isLive) ...[
                      IconButton(
                        icon: const Icon(Icons.forward_10),
                        iconSize: 24,
                        onPressed: player.seekForward,
                      ),
                    ],
                    // Next track button
                    MtTrackSkipButton(
                      player: player,
                      direction: MtTrackSkipDirection.next,
                      size: 40,
                      iconSize: 24,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniPlayPauseButton extends StatelessWidget {
  const _MiniPlayPauseButton({
    required this.isPlaying,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
        ),
      );
    }

    return IconButton(
      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
      iconSize: 32,
      onPressed: onPressed,
    );
  }
}
